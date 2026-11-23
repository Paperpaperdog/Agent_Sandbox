# deploy-grid5000 — Agent Substrate on Grid'5000

Automate Agent Substrate source build and deploy on an **existing** two-node
Kubernetes cluster (after [`../deploy-k8s-g5k`](../deploy-k8s-g5k)).

## Prerequisites

- Active Grid'5000 reservation
- Kubernetes cluster Ready (kubeadm + Cilium), with root SSH to the control plane
- Go toolchain on the control-plane node
- Agent Substrate source checkout (default `/root/sandbox-platforms/substrate`)

## End-to-end flow

1. **Create the cluster** with `deploy-k8s-g5k` (frontend):

   ```bash
   cd ~/Agent_Sandbox/deploy-k8s-g5k
   source ~/venvs/g5k/bin/activate
   bash 01-deploy.sh
   bash 02-prepare.sh
   ```

2. **On the control-plane node**, clone Substrate and sync these scripts:

   ```bash
   ssh root@<CONTROL_PLANE_IP>
   mkdir -p /root/sandbox-platforms
   git clone <substrate-repo-url> /root/sandbox-platforms/substrate

   # From frennes, or after copying Agent_Sandbox onto the node:
   ~/Agent_Sandbox/deploy-grid5000/sync-to-substrate.sh \
     /root/sandbox-platforms/substrate/deploy-grid5000
   ```

3. **Configure and deploy**:

   ```bash
   cd /root/sandbox-platforms/substrate
   cp deploy-grid5000/config.env.example deploy-grid5000/config.env
   # Set CONTROL_PLANE_HOST, WORKER_HOSTS, CONTROL_PLANE_IP,
   # REGISTRY_ENDPOINT, KO_REPOSITORY, and node hostnames from kubectl get nodes
   sudo deploy-grid5000/deploy-all.sh
   ```

Full narrative (cert APIs, storage, registry, verification): [DEPLOYMENT.md](./DEPLOYMENT.md).

## Phases

| Script | Role |
|--------|------|
| `00-preflight.sh` | Root, tools, kubeconfig, Ready nodes |
| `01-configure-kubernetes.sh` | Enable PodCertificate / ClusterTrustBundle APIs with rollback |
| `02-deploy-infrastructure.sh` | Local PVs, registry (Recreate), containerd registry config |
| `03-apply-source-patches.sh` | Grid'5000 kind-profile adaptations |
| `04-deploy-substrate.sh` | Build `ate-setup`, deploy control plane + optional Counter demo |
| `05-verify.sh` | Health checks + Actor request / suspend / resume / state check |

Phases are safe to rerun. Logs: `deploy-grid5000/.logs/`. Local state: `.state/`.

## Notes

- Default storage is under `/tmp` (ephemeral G5K nodes). Change `DATA_ROOT` for longer runs.
- Registry uses hostNetwork; Deployment strategy is `Recreate` to avoid rolling-update stalls.
- Set `CONFIGURE_WORKERS_OVER_SSH=true` only when the control plane can SSH as root to every worker.
- The Docker shim in `tools/docker` only satisfies installer preflight (`docker info`); images are built with `ko`.
