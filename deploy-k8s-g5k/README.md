# deploy-k8s-g5k

Deploy Kubernetes (and optionally Agent Sandbox / OpenSandbox) on Grid'5000 with EnOSlib.

## Quick start (after one-time setup)

```bash
ssh -J bjin@access.grid5000.fr bjin@rennes
cd ~/Agent_Sandbox/deploy-k8s-g5k
source ~/venvs/g5k/bin/activate
bash 01-deploy.sh
```

When finished, connect to the printed control-plane IP:

```bash
ssh root@<CONTROL_PLANE_IP>
kubectl get nodes
```

Tear down from the frontend:

```bash
bash 03-delete.sh
```

## Documentation

Full workflow (one-time setup, Kubernetes, Agent Sandbox, OpenSandbox):

- [DEPLOYMENT.md](./DEPLOYMENT.md)

## Layout

| File | Role |
|------|------|
| `00-config.toml` | Site, cluster, walltime, VM sizes, image path |
| `01-deploy.sh` | Reserve nodes, create VMs, install Kubernetes |
| `02-prepare.sh` | Copy SSH key / kubeconfigs to the management CP |
| `03-delete.sh` | Delete EnOSlib / OAR jobs |
| `04-install-agent-sandbox.sh` | Install Agent Sandbox on an existing cluster |
| `05-install-opensandbox.sh` | Install OpenSandbox (Helm umbrella + gateway) |
| `create-cluster.py` / `delete-cluster.py` | EnOSlib providers |
| `k8s.yml` | Ansible playbook (kubeadm + Cilium) |
| `examples/` | Sample Sandbox CR and OpenSandbox Python SDK script |

## One-time setup status (this account)

| Step | Status |
|------|--------|
| Code in `~/Agent_Sandbox/deploy-k8s-g5k` | Done |
| Venv `~/venvs/g5k` with enoslib | Done |
| Image `~/images/debian13-k8s-large.qcow2` | Done |
| `00-config.toml` image path → `/home/bjin/...` | Done |
| SSH pubkey used by playbook (`id_rsa.pub`) | Done |
| `~/.python-grid5000.yaml` | See DEPLOYMENT.md Step 4 |
