#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

manifest=/etc/kubernetes/manifests/kube-apiserver.yaml
required_gates=PodCertificateRequest=true,ClusterTrustBundle=true,ClusterTrustBundleProjection=true
required_runtime=certificates.k8s.io/v1beta1=true

api_ready() {
  kubectl api-resources --api-group=certificates.k8s.io 2>/dev/null |
    awk '$1 == "clustertrustbundles" { found=1 } END { exit !found }'
}

if api_ready; then
  log "Kubernetes certificate APIs are already served"
  exit 0
fi

[[ -f "$manifest" ]] || die "missing static Pod manifest: $manifest"
backup="$STATE_DIR/kube-apiserver.yaml.$(date -u +%Y%m%dT%H%M%SZ)"
cp -a "$manifest" "$backup"

tmp=$(mktemp)
awk -v gates="$required_gates" -v runtime="$required_runtime" '
  /^    - --feature-gates=/ {
    print "    - --feature-gates=" gates
    saw_gates=1
    next
  }
  /^    - --runtime-config=/ {
    print "    - --runtime-config=" runtime
    saw_runtime=1
    next
  }
  /^    - --secure-port=/ {
    if (!saw_gates) print "    - --feature-gates=" gates
    if (!saw_runtime) print "    - --runtime-config=" runtime
  }
  { print }
' "$manifest" >"$tmp"
install -m 0600 "$tmp" "$manifest"
rm -f "$tmp"

log "waiting for kube-apiserver to restart"
for _ in $(seq 1 60); do
  if api_ready; then
    log "Kubernetes certificate APIs are ready"
    exit 0
  fi
  sleep 2
done

log "kube-apiserver did not recover; restoring $backup"
cp -a "$backup" "$manifest"
for _ in $(seq 1 60); do
  kubectl get --raw=/readyz >/dev/null 2>&1 && die "certificate API configuration failed; kube-apiserver rollback completed"
  sleep 2
done
die "certificate API configuration failed and kube-apiserver did not recover after rollback"
