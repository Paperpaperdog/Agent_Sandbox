# Agent Substrate on Grid'5000 — full deployment

This guide covers the complete path from a Grid'5000 reservation to a verified
Agent Substrate control plane with Counter Actor lifecycle checks.

## Stack

| Layer | How |
|-------|-----|
| Nodes + VMs + Kubernetes | [`deploy-k8s-g5k`](../deploy-k8s-g5k) (EnOSlib, kubeadm, Cilium) |
| Certificate APIs, local PV, registry, Substrate | this directory (`deploy-grid5000`) |

Agent Sandbox (`04-install-agent-sandbox.sh`) and OpenSandbox are **separate**
platforms. Agent Substrate is the stack automated here.

## Phase A — Kubernetes cluster

On the Rennes frontend (`frennes`):

```bash
ssh -J bjin@access.grid5000.fr bjin@rennes
cd ~/Agent_Sandbox/deploy-k8s-g5k
source ~/venvs/g5k/bin/activate
bash 01-deploy.sh
bash 02-prepare.sh
```

Confirm:

```bash
ssh root@<CONTROL_PLANE_IP>
kubectl get nodes
# both nodes Ready
```

Record for `config.env`:

- `kubectl get nodes -o wide` → `CONTROL_PLANE_HOST`, `WORKER_HOSTS`
- Control-plane IP → `CONTROL_PLANE_IP`, `REGISTRY_ENDPOINT`, `KO_REPOSITORY`

## Phase B — Agent Substrate source

On the control-plane node:

```bash
mkdir -p /root/sandbox-platforms
git clone <substrate-repo-url> /root/sandbox-platforms/substrate
```

Install Go if missing (version required by substrate `go.mod`).

Sync automation from this repository:

```bash
# Example: Agent_Sandbox already on the node or copied via scp
~/Agent_Sandbox/deploy-grid5000/sync-to-substrate.sh \
  /root/sandbox-platforms/substrate/deploy-grid5000
```

Alternatively keep scripts only in `~/Agent_Sandbox/deploy-grid5000` and set
`SUBSTRATE_REPO_ROOT=/root/sandbox-platforms/substrate` in `config.env`.

## Phase C — Configure

```bash
cd /root/sandbox-platforms/substrate   # or ~/Agent_Sandbox
cp deploy-grid5000/config.env.example deploy-grid5000/config.env
$EDITOR deploy-grid5000/config.env
```

Important keys:

| Variable | Meaning |
|----------|---------|
| `SUBSTRATE_REPO_ROOT` | Substrate git root (required if scripts are not inside it) |
| `CONTROL_PLANE_HOST` / `WORKER_HOSTS` | Kubernetes node names |
| `REGISTRY_ENDPOINT` | `IP:5000` for the local registry |
| `DATA_ROOT` | Host paths for Postgres / RustFS / registry data |
| `CONFIGURE_WORKERS_OVER_SSH` | `true` only if CP→worker root SSH works |
| `INSTALL_COUNTER_DEMO` / `VERIFY_ACTOR_LIFECYCLE` | Demo + acceptance test |
| `SUBSTRATE_EXPECTED_COMMIT` | Optional exact pinned upstream commit; abort if HEAD differs |
| `VERIFY_WORKER_PULL` / `VERIFY_WORKER_PULL_IMAGE` | Optional strict root-SSH/`crictl pull` test of a deployed local-registry image per worker |
| `VERIFY_PROXY_PORT` / `VERIFY_CLEANUP_ACTOR` | Local proxy port, optional explicit Actor deletion after verification |

## Phase D — Automated deploy

```bash
sudo deploy-grid5000/deploy-all.sh
```

What each stage does:

1. **Preflight** — root, `kubectl`/`go`/`git`/…, Ready nodes, readable kubeconfig  
2. **Kubernetes cert APIs** — enable `PodCertificateRequest` and `ClusterTrustBundle` on the static apiserver Pod; restore backup on failure  
3. **Infrastructure** — `ate-local` StorageClass + PVs, registry Deployment (`Recreate` + hostNetwork), containerd `certs.d` for insecure local registry  
4. **Source patches** — adapt upstream kind profile (storage class, tolerations, registry rewrite, worker networking sysctl)  
5. **Substrate deploy** — build `ate-setup` / `kubectl-ate`, deploy podcertificate-controller, ate-system, atenet, optional Counter demo  
6. **Verify** — ate-system Ready; Counter Actor request → suspend → resume → second request; counter must advance by 1  

Rerun a single phase after a failure:

```bash
sudo deploy-grid5000/02-deploy-infrastructure.sh
```

Logs: `deploy-grid5000/.logs/` (image digests filtered). Backups: `deploy-grid5000/.state/`.

**Provenance and validation:** The deploy always rebuilds `ate-setup` from the current checkout. Save `.state/substrate-commit.txt`, `.state/substrate-source.patch`, `.state/go-version.txt`, and the binary SHA-256 files with each experiment record. A non-empty source patch is expected because the Grid'5000 adaptation modifies upstream tracked files. The optional worker-pull check requires root SSH and `crictl` on each Worker; when skipped, the verifier explicitly logs that the registry pull has **not** been tested. The Actor acceptance test uses a unique identity and records it in `.state/last-verify-actor.txt`; by default it leaves the Actor suspended for inspection.

## Acceptance criteria

- All Kubernetes nodes Ready  
- `ate-system` control-plane Pods healthy; Postgres / RustFS / Registry up  
- Counter Actor lifecycle verification prints that the counter advanced (e.g. 1 → 2); this verifies the Counter application's continuity, not universal Tier 2 process-memory restoration
- If `VERIFY_WORKER_PULL=true`, every configured Worker independently pulls a deployed local-registry Substrate image; otherwise this check is visibly marked `SKIPPED`
- Source SHA and patch plus build artifact checksums are recorded for reproducibility  

## Operational notes

- Grid'5000 nodes are ephemeral; `/tmp` data is lost when the job ends.  
- Registry hostNetwork + `Recreate` avoids stuck rolling updates on port 5000.  
- Worker host keys change across redeploys; SSH helpers disable strict host-key checks.  
- Tear down the K8s job with `deploy-k8s-g5k/03-delete.sh` when finished.
