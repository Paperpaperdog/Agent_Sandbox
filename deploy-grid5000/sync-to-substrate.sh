#!/usr/bin/env bash
# Copy these automation scripts into an Agent Substrate checkout.
# Run from the frontend or control-plane host after cloning substrate.

set -o errexit
set -o nounset
set -o pipefail

deploy_dir=$(cd -- "$(dirname -- "$0")" && pwd)
dest=${1:-${SUBSTRATE_REPO_ROOT:-/root/sandbox-platforms/substrate/deploy-grid5000}}

mkdir -p "$(dirname -- "$dest")"
rsync -a --delete \
  --exclude '.logs/' \
  --exclude '.state/' \
  --exclude 'config.env' \
  "$deploy_dir/" "$dest/"

printf 'Synced deploy-grid5000 -> %s\n' "$dest"
printf 'Next:\n'
printf '  cp %s/config.env.example %s/config.env\n' "$dest" "$dest"
printf '  # edit hosts / REGISTRY_ENDPOINT / SUBSTRATE_REPO_ROOT\n'
printf '  sudo %s/deploy-all.sh\n' "$dest"
