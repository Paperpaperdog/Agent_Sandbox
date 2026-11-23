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

# Build the *current* source, not a possibly stale binary left by a prior
# reservation or git checkout. Preserve the exact (possibly patched) source
# state for reproducibility; the Grid'5000 adaptations make git dirty by design.
source_commit=$(git rev-parse HEAD)
if [[ -n "${SUBSTRATE_EXPECTED_COMMIT:-}" && "$source_commit" != "$SUBSTRATE_EXPECTED_COMMIT" ]]; then
  die "Substrate commit mismatch: expected $SUBSTRATE_EXPECTED_COMMIT, got $source_commit"
fi

printf '%s\n' "$source_commit" >"$STATE_DIR/substrate-commit.txt"
git status --porcelain=v1 >"$STATE_DIR/substrate-status.txt"
git diff --binary >"$STATE_DIR/substrate-source.patch"
sha256sum "$STATE_DIR/substrate-source.patch" >"$STATE_DIR/substrate-source-patch.sha256"
go version >"$STATE_DIR/go-version.txt"

mkdir -p "$REPO_ROOT/bin"
run_filtered build-ate-setup go build -o "$REPO_ROOT/bin/ate-setup" ./cmd/ate-setup
sha256sum "$REPO_ROOT/bin/ate-setup" >"$STATE_DIR/ate-setup.sha256"
go version -m "$REPO_ROOT/bin/ate-setup" >"$STATE_DIR/ate-setup-build-info.txt"
log "built ate-setup from $source_commit (source diff and binary SHA-256 recorded in $STATE_DIR)"

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
sha256sum "$REPO_ROOT/bin/kubectl-ate" >"$STATE_DIR/kubectl-ate.sha256"

if [[ "$INSTALL_COUNTER_DEMO" == true ]]; then
  run_filtered deploy-counter-demo \
    "$REPO_ROOT/bin/ate-setup" deploy demo counter \
    --kind \
    --context "$KUBE_CONTEXT" \
    --rollout-timeout "$ROLLOUT_TIMEOUT" \
    --no-report-defaults
fi

log "Agent Substrate deployment completed"
