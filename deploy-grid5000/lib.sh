#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

DEPLOY_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
CONFIG_FILE=${CONFIG_FILE:-$DEPLOY_DIR/config.env}

if [[ -f "$CONFIG_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$CONFIG_FILE"
else
  # shellcheck disable=SC1091
  source "$DEPLOY_DIR/config.env.example"
fi

# Prefer an explicit substrate checkout. When these scripts are copied into the
# substrate tree as deploy-grid5000/, the parent directory is used by default.
if [[ -n "${SUBSTRATE_REPO_ROOT:-}" ]]; then
  REPO_ROOT=$(cd -- "$SUBSTRATE_REPO_ROOT" && pwd)
else
  REPO_ROOT=$(cd -- "$DEPLOY_DIR/.." && pwd)
fi

export KUBECONFIG
export PATH="/usr/local/go/bin:/root/go/bin:$PATH"

STATE_DIR=${STATE_DIR:-$DEPLOY_DIR/.state}
LOG_DIR=${LOG_DIR:-$DEPLOY_DIR/.logs}
mkdir -p "$STATE_DIR" "$LOG_DIR"

log() {
  printf '[grid5000] %s\n' "$*"
}

die() {
  printf '[grid5000] ERROR: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "missing command: $1"
}

# Build tools can print immutable image identifiers. Keep those identifiers out
# of terminal output and deployment logs while preserving the command status.
run_filtered() {
  local name=$1
  shift
  local log_file="$LOG_DIR/$name.log"
  log "running $name (log: $log_file)"
  set +o errexit
  "$@" 2>&1 | awk 'BEGIN { IGNORECASE=1 } !/sha256|digest/' | tee "$log_file"
  local status=${PIPESTATUS[0]}
  set -o errexit
  return "$status"
}

kubectl_wait_rollout() {
  local resource=$1
  local namespace=$2
  kubectl rollout status "$resource" -n "$namespace" --timeout="$ROLLOUT_TIMEOUT"
}

run_on_node() {
  local node=$1
  shift
  if [[ "$node" == "$CONTROL_PLANE_HOST" ]] || [[ "$node" == "$(hostname -f)" ]]; then
    "$@"
  else
    ssh \
      -o BatchMode=yes \
      -o ConnectTimeout=15 \
      -o StrictHostKeyChecking=no \
      -o UserKnownHostsFile=/dev/null \
      -o LogLevel=ERROR \
      "root@$node" "$@"
  fi
}

apply_patch_once() {
  local patch_file=$1
  if git -C "$REPO_ROOT" apply --reverse --check "$patch_file" >/dev/null 2>&1; then
    log "patch already applied: $(basename "$patch_file")"
    return
  fi
  git -C "$REPO_ROOT" apply --check "$patch_file"
  git -C "$REPO_ROOT" apply "$patch_file"
  log "applied patch: $(basename "$patch_file")"
}
