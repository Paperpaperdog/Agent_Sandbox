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

actor=$VERIFY_ACTOR_NAME
if ! kubectl ate get actor "$actor" -a ate-demo-counter >/dev/null 2>&1; then
  kubectl ate create actor "$actor" -a ate-demo-counter --template counter
fi

proxy_log="$LOG_DIR/actor-proxy.log"
proxy_port=18080
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

kubectl ate suspend actor "$actor" -a ate-demo-counter
log "lifecycle verification passed: counter advanced from $first_number to $second_number"
