#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

export PATH="$REPO_ROOT/bin:/usr/local/bin:$PATH"

kubectl get --raw=/readyz >/dev/null
while read -r pod phase; do
  case "$phase" in
    Running)
      kubectl wait --for=condition=Ready "pod/$pod" -n ate-system --timeout="$ROLLOUT_TIMEOUT"
      ;;
    Succeeded)
      ;;
    *)
      die "ate-system pod $pod is in phase $phase"
      ;;
  esac
done < <(kubectl get pods -n ate-system -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.status.phase}{"\n"}{end}')

for daemonset in atelet atenet-egress atenet-router; do
  if kubectl get daemonset "$daemonset" -n ate-system >/dev/null 2>&1; then
    kubectl rollout status "daemonset/$daemonset" -n ate-system --timeout="$ROLLOUT_TIMEOUT"
  fi
done

# An explicit pull test is optional because the existing two-VM deployment
# does not guarantee root SSH from control plane to every worker.
# Do not claim the worker registry is verified when this check is skipped.
worker_status="$STATE_DIR/worker-pull-verification.txt"
if [[ "${VERIFY_WORKER_PULL:-false}" == true ]]; then
  require_command jq
  image="${VERIFY_WORKER_PULL_IMAGE:-}"
  if [[ -z "$image" ]]; then
    image=$(kubectl get pods -n ate-system -o json | jq -r --arg prefix "$REGISTRY_ENDPOINT/" '
      [.items[] | .spec.containers[]? | .image | select(startswith($prefix))] |
      unique | .[0] // empty')
  fi
  [[ "$image" == "$REGISTRY_ENDPOINT/"* && "$image" =~ ^[A-Za-z0-9._:/@-]+$ ]] ||
    die "no valid local-registry Substrate image found; set VERIFY_WORKER_PULL_IMAGE after deployment"
  printf 'IMAGE=%s\n' "$image" > "$worker_status"
  for node in $WORKER_HOSTS; do
    log "verifying local registry pull from worker $node"
    logfile="$LOG_DIR/worker-pull-$(printf '%s' "$node" | tr -c '[:alnum:]' '_').log"
    if ! run_on_node "$node" crictl --runtime-endpoint unix:///run/containerd/containerd.sock pull "$image" >"$logfile" 2>&1; then
      printf 'FAILED=%s\n' "$node" >> "$worker_status"
      die "worker $node cannot pull $image; see $logfile (check worker SSH and containerd registry config)"
    fi
    printf 'PASSED=%s\n' "$node" >> "$worker_status"
  done
else
  printf 'SKIPPED: VERIFY_WORKER_PULL=false; no explicit worker pull was tested\n' > "$worker_status"
  log "worker image-pull test SKIPPED (set VERIFY_WORKER_PULL=true for strict validation)"
fi

if [[ "$INSTALL_COUNTER_DEMO" == true ]]; then
  for _ in $(seq 1 60); do
    replicas=$(kubectl get workerpool counter -n ate-demo-counter -o jsonpath='{.status.replicas}')
    ready=$(kubectl get workerpool counter -n ate-demo-counter -o jsonpath='{.status.readyReplicas}')
    [[ -n "$replicas" && "$replicas" == "$ready" ]] && break
    sleep 2
  done
  [[ -n ${replicas:-} && "$replicas" == "$ready" ]] || die "Counter WorkerPool is not ready"
fi

if [[ "$VERIFY_ACTOR_LIFECYCLE" != true ]]; then
  log "health verification passed"
  exit 0
fi

[[ "$INSTALL_COUNTER_DEMO" == true ]] ||
  die "VERIFY_ACTOR_LIFECYCLE requires INSTALL_COUNTER_DEMO=true"

# A unique actor prevents a resumed/stopped actor from a previous run from
# influencing the next independent acceptance test.
actor="${VERIFY_ACTOR_NAME}-$(date -u +%Y%m%d%H%M%S)-$"
[[ "$actor" =~ ^[a-z0-9][a-z0-9-]*$ && ${#actor} -le 63 ]] ||
  die "invalid generated test actor name: $actor"
printf '%s\n' "$actor" >"$STATE_DIR/last-verify-actor.txt"
kubectl ate create actor "$actor" -a ate-demo-counter --template counter

proxy_log="$LOG_DIR/actor-proxy-$actor.log"
proxy_port="${VERIFY_PROXY_PORT:-18080}"
[[ "$proxy_port" =~ ^[0-9]+$ ]] || die "VERIFY_PROXY_PORT must be numeric"
python3 - "$proxy_port" <<'PY'
import socket, sys
with socket.socket() as sock:
    sock.bind(("127.0.0.1", int(sys.argv[1])))
PY
kubectl ate proxy actor "$actor" "${proxy_port}:80" -a ate-demo-counter >"$proxy_log" 2>&1 &
proxy_pid=$!
trap 'kill "$proxy_pid" >/dev/null 2>&1 || true' EXIT

for _ in $(seq 1 60); do
  first=$(curl --fail --silent "http://127.0.0.1:$proxy_port" 2>/dev/null || true)
  [[ -n "$first" ]] && break
  sleep 2
done
[[ -n ${first:-} ]] || die "actor proxy did not become ready"

kubectl ate suspend actor "$actor" -a ate-demo-counter
kubectl ate resume actor "$actor" -a ate-demo-counter

for _ in $(seq 1 60); do
  second=$(curl --fail --silent "http://127.0.0.1:$proxy_port" 2>/dev/null || true)
  [[ -n "$second" ]] && break
  sleep 2
done
[[ -n ${second:-} ]] || die "actor did not answer after resume"

first_number=$(printf '%s' "$first" | grep -Eo '[0-9]+' | tail -1)
second_number=$(printf '%s' "$second" | grep -Eo '[0-9]+' | tail -1)
[[ "$second_number" -eq $((first_number + 1)) ]] || die "actor state was not preserved across suspend/resume"

log "lifecycle verification passed: counter advanced from $first_number to $second_number (actor=$actor)"
if [[ "${VERIFY_CLEANUP_ACTOR:-false}" == true ]]; then
  kubectl ate delete actor "$actor" -a ate-demo-counter ||
    die "counter state passed, but cleanup of $actor failed; inspect the actor and retry manually"
  log "test actor deleted: $actor"
else
  kubectl ate suspend actor "$actor" -a ate-demo-counter
  log "test actor left suspended for inspection: $actor (name in $STATE_DIR/last-verify-actor.txt)"
fi
