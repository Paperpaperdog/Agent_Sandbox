#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

[[ $(id -u) -eq 0 ]] || die "run this script as root on the control-plane node"

for command in awk curl git go jq kubectl python3 sed ssh; do
  require_command "$command"
done

[[ -r "$KUBECONFIG" ]] || die "cannot read KUBECONFIG: $KUBECONFIG"
[[ -f "$REPO_ROOT/go.mod" ]] || die "run from the Agent Substrate checkout"

kubectl cluster-info >/dev/null
kubectl get node "$CONTROL_PLANE_HOST" >/dev/null
for node in $WORKER_HOSTS; do
  kubectl get node "$node" >/dev/null
done

if ! kubectl get nodes --no-headers | awk '$2 != "Ready" { exit 1 }'; then
  die "all Kubernetes nodes must be Ready"
fi

if [[ -n ${OAR_JOB_ID:-} ]]; then
  log "running inside OAR job $OAR_JOB_ID"
else
  log "OAR_JOB_ID is not set; confirm the reservation remains active"
fi

log "preflight checks passed"
