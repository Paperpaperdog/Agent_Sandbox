#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

configure_containerd() {
  local node=$1
  local endpoint=$2
  local hosts_file
  hosts_file=$(mktemp)
  printf '%s\n' \
    "server = \"http://$endpoint\"" \
    '' \
    "[host.\"http://$endpoint\"]" \
    '  capabilities = ["pull", "resolve", "push"]' \
    '  skip_verify = true' >"$hosts_file"
  log "configuring containerd registry access on $node"
  run_on_node "$node" mkdir -p "/etc/containerd/certs.d/$endpoint"
  if [[ "$node" == "$CONTROL_PLANE_HOST" ]] || [[ "$node" == "$(hostname -f)" ]]; then
    install -m 0644 "$hosts_file" "/etc/containerd/certs.d/$endpoint/hosts.toml"
  else
    ssh \
      -o BatchMode=yes \
      -o ConnectTimeout=15 \
      -o StrictHostKeyChecking=no \
      -o UserKnownHostsFile=/dev/null \
      -o LogLevel=ERROR \
      "root@$node" \
      "cat > '/etc/containerd/certs.d/$endpoint/hosts.toml'" <"$hosts_file"
  fi
  rm -f "$hosts_file"

  if ! run_on_node "$node" grep -q 'config_path = "/etc/containerd/certs.d"' /etc/containerd/config.toml; then
    if run_on_node "$node" grep -q '\[plugins\."io.containerd.grpc.v1.cri"\.registry\]' /etc/containerd/config.toml; then
      run_on_node "$node" sed -i '/\[plugins\."io.containerd.grpc.v1.cri"\.registry\]/a\  config_path = "/etc/containerd/certs.d"' /etc/containerd/config.toml
    else
      die "containerd registry section is missing on $node"
    fi
  fi
  run_on_node "$node" systemctl restart containerd
  run_on_node "$node" systemctl is-active --quiet containerd
}

install -d -m 0770 "$DATA_ROOT/postgres" "$DATA_ROOT/rustfs"
install -d -m 0755 "$DATA_ROOT/registry"
chown root:70 "$DATA_ROOT/postgres"
chown 10001:10001 "$DATA_ROOT/rustfs"

rendered=$(mktemp -d)
trap 'rm -rf "$rendered"' EXIT
sed \
  -e "s|@@CONTROL_PLANE_HOST@@|$CONTROL_PLANE_HOST|g" \
  -e "s|@@DATA_ROOT@@|$DATA_ROOT|g" \
  -e "s|@@POSTGRES_SIZE@@|$POSTGRES_SIZE|g" \
  -e "s|@@RUSTFS_SIZE@@|$RUSTFS_SIZE|g" \
  "$DEPLOY_DIR/manifests/storage.yaml" >"$rendered/storage.yaml"
sed \
  -e "s|@@CONTROL_PLANE_HOST@@|$CONTROL_PLANE_HOST|g" \
  -e "s|@@DATA_ROOT@@|$DATA_ROOT|g" \
  "$DEPLOY_DIR/manifests/registry.yaml" >"$rendered/registry.yaml"

kubectl apply -f "$rendered/storage.yaml"
kubectl apply -f "$rendered/registry.yaml"
kubectl_wait_rollout deployment/registry ate-registry

configure_containerd "$CONTROL_PLANE_HOST" "$REGISTRY_ENDPOINT"
if [[ "$CONFIGURE_WORKERS_OVER_SSH" == true ]]; then
  for node in $WORKER_HOSTS; do
    configure_containerd "$node" "$REGISTRY_ENDPOINT"
  done
else
  log "worker containerd configuration is pre-provisioned; skipping node SSH"
fi

curl --fail --silent --show-error "http://$REGISTRY_ENDPOINT/v2/" >/dev/null
kubectl wait --for=condition=Ready node --all --timeout="$ROLLOUT_TIMEOUT"
log "local storage and registry are ready"
