# Tutorial: Deploy Agent Substrate on Grid'5000

This tutorial walks you through deploying **Agent Substrate** from source on a
two-node Kubernetes cluster at Grid'5000 (Rennes). By the end you will have:

- a Ready Kubernetes cluster
- Agent Substrate control plane (`ate-system`) running
- local Postgres, RustFS, and an OCI registry
- a Counter Actor that survives suspend / resume with preserved state

Estimated time after account setup: **30–90 minutes**, depending on image
builds and node availability.

---

## What you will use

| Component | Role |
|-----------|------|
| [`deploy-k8s-g5k`](../deploy-k8s-g5k) | Reserve nodes, create VMs, install Kubernetes + Cilium |
| [`deploy-grid5000`](./) (this directory) | Enable cert APIs, local storage/registry, build & deploy Substrate, verify |

> **Not the same as Agent Sandbox / OpenSandbox.** Those installers live under
> `deploy-k8s-g5k` (`04-install-agent-sandbox.sh`, `05-install-opensandbox.sh`).
> This tutorial targets **Agent Substrate** only.

---

## Before you start

You need:

1. A Grid'5000 account with access to the **Rennes** site  
2. This repository on the Rennes frontend (`frennes`), typically at
   `~/Agent_Sandbox`  
3. One-time K8s bootstrap setup already done (venv, QCOW2 image, SSH keys) —
   see [`../deploy-k8s-g5k/DEPLOYMENT.md`](../deploy-k8s-g5k/DEPLOYMENT.md)  
4. The **Agent Substrate** git repository URL you are allowed to clone  

Connect to the frontend:

```bash
ssh -J <login>@access.grid5000.fr <login>@rennes
```

You should land on something like `bjin@frennes:~$`.

---

## Part 1 — Create the Kubernetes cluster

All commands in this part run on the **frontend** (`frennes`), not on the VMs.

### 1.1 Activate the environment

```bash
cd ~/Agent_Sandbox/deploy-k8s-g5k
source ~/venvs/g5k/bin/activate
```

### 1.2 Check the reservation config

Edit `00-config.toml` if you need a different walltime, cluster, or image path.
Do **not** mix an interactive `oarsub -I` with `01-deploy.sh`; EnOSlib creates
its own OAR job.

### 1.3 Deploy Kubernetes

```bash
bash 01-deploy.sh
bash 02-prepare.sh
```

`01-deploy.sh` reserves nodes, boots VMs, and runs kubeadm + Cilium.
`02-prepare.sh` copies SSH keys / kubeconfigs for easy access.

When it finishes, note the **control-plane IP** printed by the scripts (also in
`cp_node_list` / `all_node_list` after deploy).

### 1.4 Verify the cluster

```bash
ssh root@<CONTROL_PLANE_IP>
kubectl get nodes -o wide
```

Expected: both nodes show `Ready`. Example:

```text
NAME                         STATUS   ROLES           AGE   VERSION
virtual-158-4-1              Ready    control-plane   ...   v1.xx.x
virtual-158-4-2              Ready    <none>          ...   v1.xx.x
```

Keep this SSH session (or open a new one). The rest of the tutorial runs as
**root on the control-plane node**.

Also record values for later configuration:

| From | Use in `config.env` |
|------|---------------------|
| Node names (`kubectl get nodes`) | `CONTROL_PLANE_HOST`, `WORKER_HOSTS` |
| Control-plane IP | `CONTROL_PLANE_IP`, `REGISTRY_ENDPOINT`, `KO_REPOSITORY` |

---

## Part 2 — Prepare Agent Substrate on the control plane

### 2.1 Install Go (if needed)

Agent Substrate builds with Go. Check:

```bash
go version
```

If missing, install a Go version that satisfies substrate’s `go.mod`, then ensure
`/usr/local/go/bin` is on `PATH`.

### 2.2 Clone the Substrate repository

```bash
mkdir -p /root/sandbox-platforms
git clone <SUBSTRATE_GIT_URL> /root/sandbox-platforms/substrate
cd /root/sandbox-platforms/substrate
ls go.mod cmd/ate-setup
```

### 2.3 Install the automation scripts

From the frontend (or after copying `Agent_Sandbox` onto the node), sync
`deploy-grid5000` into the Substrate tree:

```bash
# Example from frennes, with root SSH to the CP:
scp -r ~/Agent_Sandbox/deploy-grid5000 root@<CONTROL_PLANE_IP>:/tmp/deploy-grid5000

# On the control plane:
/tmp/deploy-grid5000/sync-to-substrate.sh /root/sandbox-platforms/substrate/deploy-grid5000
```

Or, if `~/Agent_Sandbox` is already available on the node:

```bash
~/Agent_Sandbox/deploy-grid5000/sync-to-substrate.sh \
  /root/sandbox-platforms/substrate/deploy-grid5000
```

You should now have:

```text
/root/sandbox-platforms/substrate/deploy-grid5000/deploy-all.sh
/root/sandbox-platforms/substrate/deploy-grid5000/config.env.example
...
```

---

## Part 3 — Configure the deployment

```bash
cd /root/sandbox-platforms/substrate
cp deploy-grid5000/config.env.example deploy-grid5000/config.env
$EDITOR deploy-grid5000/config.env
```

### 3.1 Settings you must update each reservation

```bash
SUBSTRATE_REPO_ROOT=/root/sandbox-platforms/substrate

CONTROL_PLANE_HOST=<name from kubectl get nodes>
CONTROL_PLANE_IP=<control-plane IP>
WORKER_HOSTS="<worker node name>"
KUBECONFIG=/etc/kubernetes/admin.conf

REGISTRY_ENDPOINT=<CONTROL_PLANE_IP>:5000
KO_REPOSITORY=<CONTROL_PLANE_IP>:5000/substrate
```

Example (illustrative only — **do not copy blindly**):

```bash
CONTROL_PLANE_HOST=paradoxe-40.rennes.grid5000.fr
CONTROL_PLANE_IP=172.16.101.40
WORKER_HOSTS="paradoxe-41.rennes.grid5000.fr"
REGISTRY_ENDPOINT=172.16.101.40:5000
KO_REPOSITORY=172.16.101.40:5000/substrate
```

### 3.2 Settings you can usually leave as-is

| Variable | Default | Notes |
|----------|---------|-------|
| `DATA_ROOT` | `/tmp/agent-substrate-data` | Ephemeral; fine for short jobs |
| `POSTGRES_SIZE` / `RUSTFS_SIZE` | `20Gi` / `50Gi` | Local PV capacity |
| `CONFIGURE_WORKERS_OVER_SSH` | `false` | Set `true` only if CP can SSH to workers as root |
| `SANDBOX_CLASSES` | `gvisor` | Passed to `ate-setup` |
| `INSTALL_COUNTER_DEMO` | `true` | Deploys Counter demo |
| `VERIFY_ACTOR_LIFECYCLE` | `true` | Runs suspend/resume acceptance |
| `SUBSTRATE_EXPECTED_COMMIT` | empty | Set full tested upstream Git SHA to reject unexpected revisions |
| `VERIFY_WORKER_PULL` | `false` | Enable only if CP→worker root SSH and `crictl` work |
| `VERIFY_CLEANUP_ACTOR` | `false` | Keep accepted Counter Actor suspended for inspection |
| `ROLLOUT_TIMEOUT` | `5m` | Increase on slow builds |

---

## Part 4 — Run the automated deploy

Still as **root** on the control plane:

```bash
cd /root/sandbox-platforms/substrate
sudo deploy-grid5000/deploy-all.sh
```

### 4.1 What happens in each phase

| Phase | Script | What it does |
|-------|--------|--------------|
| 0 | `00-preflight.sh` | Checks root, tools, kubeconfig, Ready nodes |
| 1 | `01-configure-kubernetes.sh` | Enables `PodCertificateRequest` + `ClusterTrustBundle` on the apiserver; rolls back the static Pod manifest on failure |
| 2 | `02-deploy-infrastructure.sh` | Creates local StorageClass/PVs, starts the registry (`hostNetwork` + `Recreate`), configures containerd for the insecure local registry |
| 3 | `03-apply-source-patches.sh` | Applies Grid'5000 adaptations to the upstream kind install profile |
| 4 | `04-deploy-substrate.sh` | Builds `ate-setup` / `kubectl-ate`, deploys podcertificate-controller, ate-system, atenet, and the Counter demo |
| 5 | `05-verify.sh` | Waits for healthy pods; creates a Counter Actor; request → suspend → resume → request; asserts the counter advanced by 1 |

Logs are written under `deploy-grid5000/.logs/`. Image digests are filtered from
log output. Apiserver backups and reproducibility artifacts (upstream commit,
local patch, Go version and binary SHA-256 hashes) live under
`deploy-grid5000/.state/`. The installer **rebuilds** `ate-setup` on each run.
The strict worker image-pull check is optional; if it is disabled, its
status file records **SKIPPED**, not a successful pull.

### 4.2 Resume after a failure

Phases are safe to rerun. Example: infrastructure failed, then continue:

```bash
sudo deploy-grid5000/02-deploy-infrastructure.sh
sudo deploy-grid5000/03-apply-source-patches.sh
sudo deploy-grid5000/04-deploy-substrate.sh
sudo deploy-grid5000/05-verify.sh
```

Or simply re-run `deploy-all.sh` after fixing the underlying issue.

---

## Part 5 — Confirm success

### 5.1 Cluster and control plane

```bash
kubectl get nodes
kubectl get pods -n ate-system
kubectl get pods -n ate-registry
kubectl get pvc -A | head
```

You should see Ready nodes, healthy `ate-system` pods, a running registry, and
bound Postgres / RustFS volumes.

### 5.2 Acceptance test output

A successful `05-verify.sh` ends with a line similar to:

```text
[grid5000] lifecycle verification passed: counter advanced from 1 to 2
```

That means a **freshly named** Counter Actor handled a request, was suspended,
resumed, answered again and preserved its application counter state. This is
not by itself proof of full Tier 2 live process-memory restoration. The test
Actor is left suspended by default, and its name is saved in
`deploy-grid5000/.state/last-verify-actor.txt`. To automatically delete it,
set `VERIFY_CLEANUP_ACTOR=true` only after confirming the pinned
`kubectl ate delete actor` command works. A separate opt-in test can verify
worker image pulling using root SSH and `crictl`.

### 5.3 Manual smoke check (optional)

```bash
export PATH="/root/sandbox-platforms/substrate/bin:/usr/local/bin:$PATH"
kubectl ate get actor -a ate-demo-counter
```

---

## Part 6 — Tear down

When the experiment is finished, delete the Grid'5000 job from the **frontend**:

```bash
cd ~/Agent_Sandbox/deploy-k8s-g5k
source ~/venvs/g5k/bin/activate
bash 03-delete.sh
```

Remember: data under `/tmp/agent-substrate-data` disappears with the nodes.

---

## Troubleshooting

| Symptom | Likely cause | What to try |
|---------|--------------|-------------|
| Preflight: missing `go.mod` | Wrong `SUBSTRATE_REPO_ROOT` or scripts not synced into substrate | Fix `config.env`; re-run `sync-to-substrate.sh` |
| Certificate APIs never become ready | Apiserver feature gates / runtime-config not applied | Check `.state/` backup; inspect `/etc/kubernetes/manifests/kube-apiserver.yaml`; re-run `01-configure-kubernetes.sh` |
| Registry rollout stuck | Rolling update with `hostNetwork` port 5000 | Ensure `manifests/registry.yaml` uses `strategy: Recreate` |
| Workers cannot pull images | containerd not configured for `REGISTRY_ENDPOINT` | Set `CONFIGURE_WORKERS_OVER_SSH=true` if SSH works, or pre-configure workers; re-run `02-deploy-infrastructure.sh` |
| Counter verify fails (state not preserved) | Demo not ready or Actor not resumed | `kubectl get workerpool -n ate-demo-counter`; re-run `05-verify.sh`; check `.logs/actor-proxy.log` |
| `docker` errors during install | Unexpected Docker use | Only `docker info` is stubbed via `tools/docker`; ensure `PATH` puts `deploy-grid5000/tools` first during deploy |

For deeper operational notes, see [DEPLOYMENT.md](./DEPLOYMENT.md) and
[README.md](./README.md).

---

## Quick reference

```bash
# Frontend: create K8s
cd ~/Agent_Sandbox/deploy-k8s-g5k && source ~/venvs/g5k/bin/activate
bash 01-deploy.sh && bash 02-prepare.sh

# Control plane: Substrate
git clone <SUBSTRATE_GIT_URL> /root/sandbox-platforms/substrate
sync-to-substrate.sh /root/sandbox-platforms/substrate/deploy-grid5000
cd /root/sandbox-platforms/substrate
cp deploy-grid5000/config.env.example deploy-grid5000/config.env
# edit hosts / IPs
sudo deploy-grid5000/deploy-all.sh
```
