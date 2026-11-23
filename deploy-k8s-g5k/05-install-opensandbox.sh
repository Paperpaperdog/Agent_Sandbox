#!/bin/bash
# Install OpenSandbox (umbrella chart + ingress gateway) on the current cluster.
# Run on the control-plane VM. Requires: git, helm, kubectl, openssl.
set -euo pipefail

WORKDIR="${OPENSANDBOX_WORKDIR:-$HOME/sandbox-platforms/OpenSandbox}"
REPO_URL="${OPENSANDBOX_REPO_URL:-https://github.com/opensandbox-group/OpenSandbox.git}"
SYSTEM_NS="${OPENSANDBOX_SYSTEM_NS:-opensandbox-system}"
APP_NS="${OPENSANDBOX_APP_NS:-opensandbox}"

if ! command -v kubectl >/dev/null 2>&1; then
  echo "kubectl not found. Run this script on the Kubernetes control plane." >&2
  exit 1
fi
if ! command -v helm >/dev/null 2>&1; then
  echo "helm not found. Install Helm 3, then re-run." >&2
  exit 1
fi
if ! command -v git >/dev/null 2>&1; then
  echo "git not found. Install git, then re-run." >&2
  exit 1
fi

mkdir -p "$(dirname "$WORKDIR")"
if [[ ! -d "$WORKDIR/.git" ]]; then
  echo "Cloning OpenSandbox into $WORKDIR ..."
  git clone "$REPO_URL" "$WORKDIR"
else
  echo "Using existing clone at $WORKDIR"
fi
cd "$WORKDIR"

kubectl get ns "$SYSTEM_NS" >/dev/null 2>&1 || kubectl create namespace "$SYSTEM_NS"
kubectl get ns "$APP_NS" >/dev/null 2>&1 || kubectl create namespace "$APP_NS"

echo "Building umbrella chart dependencies..."
helm dependency build manifests/charts/opensandbox

echo "Applying OpenSandbox umbrella chart..."
helm template ./manifests/charts/opensandbox | kubectl apply -f -

echo "Installing ingress gateway..."
helm upgrade --install opensandbox-gateway \
  manifests/charts/ingress-gateway \
  -n "$SYSTEM_NS"

API_KEY="${OPEN_SANDBOX_API_KEY:-$(openssl rand -hex 32)}"
echo
echo "Generated/using API key (save it):"
echo "$API_KEY"
echo

TMP_CM="$(mktemp)"
kubectl get configmap opensandbox-server-config -n "$SYSTEM_NS" -o yaml >"$TMP_CM"

# Replace empty api_key = "" (or existing value) inside the ConfigMap data.
python3 - "$TMP_CM" "$API_KEY" <<'PY'
import re, sys
path, key = sys.argv[1], sys.argv[2]
text = open(path, encoding="utf-8").read()
# Match api_key = "..." inside the embedded config blob.
new, n = re.subn(
    r'(api_key\s*=\s*")[^"]*(")',
    rf'\1{key}\2',
    text,
    count=1,
)
if n == 0:
    sys.stderr.write("Could not find api_key = \"...\" in ConfigMap YAML.\n")
    sys.exit(1)
open(path, "w", encoding="utf-8").write(new)
print(f"Updated api_key in {path}")
PY

kubectl apply -f "$TMP_CM"
rm -f "$TMP_CM"

kubectl rollout restart "deployment/opensandbox-server" -n "$SYSTEM_NS" || true
kubectl rollout status "deployment/opensandbox-server" -n "$SYSTEM_NS" --timeout=180s || true

echo
echo "Pods in $SYSTEM_NS:"
kubectl get pods -n "$SYSTEM_NS"
echo
echo "CRDs:"
kubectl get crd | grep -i sandbox || true
echo
echo "Next:"
echo "  kubectl port-forward svc/opensandbox-server -n $SYSTEM_NS 8080:80 &"
echo "  curl http://localhost:8080/health"
echo "  export OPEN_SANDBOX_API_KEY=$API_KEY"
echo "  python3 examples/first_sandbox.py"
