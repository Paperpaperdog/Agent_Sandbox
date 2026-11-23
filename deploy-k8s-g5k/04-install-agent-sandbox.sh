#!/bin/bash
# Install Agent Sandbox on the current Kubernetes cluster.
# Run on the control-plane VM (where kubectl talks to the local apiserver).
set -euo pipefail

MANIFEST_URL="${AGENT_SANDBOX_MANIFEST_URL:-https://github.com/kubernetes-sigs/agent-sandbox/releases/latest/download/sandbox-with-extensions.yaml}"
NAMESPACE="${AGENT_SANDBOX_NAMESPACE:-agent-sandbox-system}"
TIMEOUT="${AGENT_SANDBOX_TIMEOUT:-180s}"

if ! command -v kubectl >/dev/null 2>&1; then
  echo "kubectl not found. Run this script on the Kubernetes control plane." >&2
  exit 1
fi

echo "Applying Agent Sandbox manifest..."
kubectl apply -f "$MANIFEST_URL"

echo "Waiting for controller rollout..."
kubectl rollout status \
  "deployment/agent-sandbox-controller" \
  -n "$NAMESPACE" \
  --timeout="$TIMEOUT"

echo
echo "CRDs:"
kubectl get crd | grep sandbox || true
echo
echo "Deployments:"
kubectl get deploy -n "$NAMESPACE"
echo
echo "Pods:"
kubectl get pods -n "$NAMESPACE"
echo
echo "Demo namespace (optional):"
kubectl get ns agent-sandbox-demo >/dev/null 2>&1 || kubectl create namespace agent-sandbox-demo
echo "Done. Apply examples/hello-sandbox.yaml next."
