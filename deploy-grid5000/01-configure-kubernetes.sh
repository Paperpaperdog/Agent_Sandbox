#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

manifest=/etc/kubernetes/manifests/kube-apiserver.yaml

api_ready() {
  local resources
  kubectl get --raw=/readyz >/dev/null 2>&1 || return 1
  resources=$(kubectl api-resources --api-group=certificates.k8s.io -o name 2>/dev/null) || return 1
  grep -qx 'clustertrustbundles.certificates.k8s.io' <<<"$resources" &&
    grep -qx 'podcertificaterequests.certificates.k8s.io' <<<"$resources"
}

if api_ready; then
  log "both ClusterTrustBundle and PodCertificateRequest APIs are served"
  exit 0
fi

# The Grid'5000 kubeadm playbook currently targets Kubernetes v1.36.2.
# Fail closed for older versions instead of injecting incompatible alpha flags.
minor=$(kubectl version -o json | jq -r '.serverVersion.minor | sub("[^0-9].*$"; "")')
[[ "$minor" =~ ^[0-9]+$ ]] || die "could not determine Kubernetes server minor version"
(( 10#$minor >= 35 )) ||
  die "Kubernetes v1.$minor needs version-specific certificate API settings (this script supports v1.35+)"

[[ -f "$manifest" ]] || die "missing static Pod manifest: $manifest"
require_command python3
backup="$STATE_DIR/kube-apiserver.yaml.$(date -u +%Y%m%dT%H%M%SZ)"
cp -a "$manifest" "$backup"

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
python3 "$DEPLOY_DIR/tools/render-apiserver.py" "$manifest" "$tmp" ||
  die "could not safely merge kube-apiserver flags; original manifest unchanged"

if cmp -s "$manifest" "$tmp"; then
  die "certificate APIs are unavailable despite already configured flags; check kube-apiserver and kubelet logs"
fi

# Atomic replacement triggers the static-Pod restart; original remains backed up.
install -m 0600 "$tmp" "$manifest"
log "waiting for certificate APIs after kube-apiserver restart"
for _ in $(seq 1 60); do
  if api_ready; then
    log "both certificate APIs are ready; backup: $backup"
    exit 0
  fi
  sleep 2
done

log "certificate APIs did not become ready; restoring $backup"
cp -a "$backup" "$manifest"
for _ in $(seq 1 60); do
  if kubectl get --raw=/readyz >/dev/null 2>&1; then
    die "certificate API enablement failed; kube-apiserver manifest rolled back to $backup"
  fi
  sleep 2
done

die "certificate API enablement failed; kube-apiserver did not recover after rollback ($backup)"
