#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

# Only an IP/DNS host plus port is valid. Reject any shell/sed metacharacters.
[[ "$REGISTRY_ENDPOINT" =~ ^[A-Za-z0-9.-]+:[0-9]{1,5}$ ]] ||
  die "REGISTRY_ENDPOINT must be a host:port, got: $REGISTRY_ENDPOINT"

source_patch="$DEPLOY_DIR/patches/grid5000-kind-profile.patch"
[[ -r "$source_patch" ]] || die "missing Grid'5000 source patch: $source_patch"
grep -Fq '172.16.101.40:5000' "$source_patch" ||
  die "patch template has changed; update its registry placeholder before deploying"

rendered_patch=$(mktemp)
trap 'rm -f "$rendered_patch"' EXIT
sed "s|172\\.16\\.101\\.40:5000|$REGISTRY_ENDPOINT|g" "$source_patch" > "$rendered_patch"

# The reverse check handles reruns with the *same* reservation values.
# A checkout already patched with a different IP must not be silently mutated.
if git -C "$REPO_ROOT" apply --reverse --check "$rendered_patch" >/dev/null 2>&1; then
  log "Grid'5000 patch already applied for $REGISTRY_ENDPOINT"
elif git -C "$REPO_ROOT" apply --check "$rendered_patch"; then
  apply_patch_once "$rendered_patch"
else
  die "cannot apply Grid'5000 patch: upstream changed or this checkout was patched for another registry. Inspect git diff and use a clean/pinned Substrate checkout for each reservation (do not reset unrelated work)."
fi

log "Grid'5000 source adaptations are present (registry=$REGISTRY_ENDPOINT)"
