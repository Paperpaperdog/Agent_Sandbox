#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

export PATH="$DEPLOY_DIR/tools:/usr/local/go/bin:/root/go/bin:$PATH"
export KO_DOCKER_REPO=$KO_REPOSITORY
export KO_INSECURE_REGISTRY=true

cd "$REPO_ROOT"

require_command go
require_command kubectl

mkdir -p "$REPO_ROOT/bin"
if [[ ! -x "$REPO_ROOT/bin/ate-setup" ]]; then
  run_filtered build-ate-setup go build -o "$REPO_ROOT/bin/ate-setup" ./cmd/ate-setup
fi

run_filtered deploy-podcertificate-controller \
  "$REPO_ROOT/bin/ate-setup" deploy podcertificate-controller \
  --context "$KUBE_CONTEXT" \
  --rollout-timeout "$ROLLOUT_TIMEOUT" \
  --no-report-defaults

run_filtered deploy-ate-system \
  "$REPO_ROOT/bin/ate-setup" deploy ate-system \
  --kind \
  --context "$KUBE_CONTEXT" \
  --sandbox-classes "$SANDBOX_CLASSES" \
  --credential-provider='{"enabled":false}' \
  --atenet-dataplane "$ATENET_DATAPLANE" \
  --rollout-timeout "$ROLLOUT_TIMEOUT" \
  --no-report-defaults

run_filtered deploy-atenet-policy \
  "$REPO_ROOT/bin/ate-setup" deploy atenet \
  --context "$KUBE_CONTEXT" \
  --credential-provider='{"enabled":false}' \
  --atenet-dataplane "$ATENET_DATAPLANE" \
  --ingress-allowed-spiffe-ids=spiffe://cluster.local/ns/ate-system/sa/atenet-client \
  --rollout-timeout "$ROLLOUT_TIMEOUT" \
  --no-report-defaults

go build -o "$REPO_ROOT/bin/kubectl-ate" ./cmd/kubectl-ate
install -m 0755 "$REPO_ROOT/bin/kubectl-ate" /usr/local/bin/kubectl-ate

if [[ "$INSTALL_COUNTER_DEMO" == true ]]; then
  run_filtered deploy-counter-demo \
    "$REPO_ROOT/bin/ate-setup" deploy demo counter \
    --kind \
    --context "$KUBE_CONTEXT" \
    --rollout-timeout "$ROLLOUT_TIMEOUT" \
    --no-report-defaults
fi

log "Agent Substrate deployment completed"
