#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

apply_patch_once "$DEPLOY_DIR/patches/grid5000-kind-profile.patch"

expected_endpoint=172.16.101.40:5000
if [[ "$REGISTRY_ENDPOINT" != "$expected_endpoint" ]]; then
  sed -i "s|--localhost-registry-replacement=$expected_endpoint|--localhost-registry-replacement=$REGISTRY_ENDPOINT|" \
    "$REPO_ROOT/manifests/ate-install/kind/atelet/kustomization.yaml"
fi

log "Grid'5000 source adaptations are present"
