#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

deploy_dir=$(cd -- "$(dirname -- "$0")" && pwd)

for phase in \
  00-preflight.sh \
  01-configure-kubernetes.sh \
  02-deploy-infrastructure.sh \
  03-apply-source-patches.sh \
  04-deploy-substrate.sh \
  05-verify.sh; do
  printf '\n==> %s\n' "$phase"
  "$deploy_dir/$phase"
done
