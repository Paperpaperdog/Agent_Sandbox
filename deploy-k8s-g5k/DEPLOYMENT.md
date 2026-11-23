# Kubernetes + Agent Sandbox on Grid'5000

## Using EnOSlib Automation

### Updated Deployment Guide (adapted for `bjin` / this repo)

## Overview

Complete deployment workflow for running Kubernetes and Agent Sandbox on
Grid'5000 using the PRIM `deploy-k8s-g5k` scripts in this repository.

The guide distinguishes between:

1. One-time setup steps
2. Repeated deployment steps

It also covers OpenSandbox (batch runtime) as a separate platform.

Paths in this document match the current account:

| Item | Path |
|------|------|
| Repo | `~/Agent_Sandbox/deploy-k8s-g5k` |
| Python venv | `~/venvs/g5k` |
| QCOW2 image | `~/images/debian13-k8s-large.qcow2` |
| Grid'5000 login | `bjin` |
| Site frontend | `rennes` → `frennes` |

---

# Introduction

Deploy a Kubernetes cluster on Grid'5000 and run Agent Sandbox / OpenSandbox
workloads for experimental evaluation.

Stack:

- Grid'5000
- EnOSlib
- OAR reservations
- Kadeploy / VMs on G5K
- Kubernetes
- Agent Sandbox (`kubernetes-sigs/agent-sandbox`)
- OpenSandbox (`opensandbox-group/OpenSandbox`) — optional, separate platform

---

# Important Distinction

## Phase 1: One-Time Setup

Performed only once when preparing your account.

## Phase 2: Normal Experiment Execution

After the initial setup, most experiments only require:

```bash
ssh -J bjin@access.grid5000.fr bjin@rennes
cd ~/Agent_Sandbox/deploy-k8s-g5k
source ~/venvs/g5k/bin/activate
bash 01-deploy.sh
```

> **Do not mix** a manual interactive `oarsub -I` with `01-deploy.sh`.
> EnOSlib creates its own OAR reservation. An interactive job and an EnOSlib
> job compete for the same nodes.

---

# Part I – One-Time Setup

## Step 1 – Connect to Grid'5000

Grid'5000 no longer allows direct interactive SSH on `access.grid5000.fr`.
Use ProxyJump:

```bash
ssh -J bjin@access.grid5000.fr bjin@rennes
```

Expected:

```text
------ Welcome to SLICES-FR - Rennes ------
bjin@frennes:~$
```

---

## Step 2 – Upload / sync the deployment code

From your laptop (example with ProxyJump):

```bash
scp -r \
  -o ProxyJump=bjin@access.grid5000.fr \
  ./deploy-k8s-g5k \
  bjin@rennes:~/Agent_Sandbox/
```

On the frontend:

```bash
cd ~/Agent_Sandbox/deploy-k8s-g5k
ls
```

Expected files:

```text
00-config.toml
01-deploy.sh
02-prepare.sh
03-delete.sh
04-install-agent-sandbox.sh
05-install-opensandbox.sh
create-cluster.py
delete-cluster.py
k8s.yml
README.md
DEPLOYMENT.md
examples/
```

---

## Step 3 – Create the Python virtual environment

This account already uses:

```bash
# already present
source ~/venvs/g5k/bin/activate
python -c "import enoslib; print(enoslib.__version__)"
```

If you need to recreate it:

```bash
python3 -m venv ~/venvs/g5k
source ~/venvs/g5k/bin/activate
pip install -U pip enoslib
python -c "import enoslib; print('OK')"
```

---

## Step 4 – Configure Grid'5000 credentials

On a **frontend** (`frennes`), username/password is often optional; API access
usually works without a password file. Creating a small config silences the
`No such file or directory: ~/.python-grid5000.yaml` warning:

```bash
cat > ~/.python-grid5000.yaml <<'EOF'
verify_ssl: /etc/ssl/certs/ca-certificates.crt
EOF
chmod 600 ~/.python-grid5000.yaml
```

If you run EnOSlib from **outside** Grid'5000, store login credentials:

```bash
cat > ~/.python-grid5000.yaml <<'EOF'
username: bjin
password: YOUR_GRID5000_PASSWORD
verify_ssl: /etc/ssl/certs/ca-certificates.crt
EOF
chmod 600 ~/.python-grid5000.yaml
```

Or interactively:

```bash
source ~/venvs/g5k/bin/activate
python -c 'from grid5000.cli import auth; auth("bjin")'
```

---

## Step 5 – Download the Kubernetes QCOW2 image

Already present for this account. To re-download:

```bash
mkdir -p ~/images
cd ~/images
curl -L -O \
  https://api.grid5000.fr/sid/sites/rennes/public/chuang/debian13-k8s-large.qcow2
ls -lh ~/images/debian13-k8s-large.qcow2
```

(~1.2 GB)

---

## Step 6 – Update the configuration file

`00-config.toml` in this repo already points at the local image:

```toml
[vm]
image = "/home/bjin/images/debian13-k8s-large.qcow2"
```

Verify:

```bash
grep image 00-config.toml
```

Also confirm SSH key used by Ansible / prepare scripts:

- Playbook (`k8s.yml`) installs `~/.ssh/id_rsa.pub` on VMs
- `02-prepare.sh` copies `~/.ssh/id_rsa` to control planes

If you prefer ed25519, generate a key and switch both files back to
`id_ed25519` / `id_ed25519.pub`.

---

# Part II – Deploying Kubernetes

## Step 7 – Review the deployment configuration

```bash
cat 00-config.toml
```

Important fields:

- `[g5k]` site / cluster / duration / number_servers
- `[vm]` image and CPU/memory
- `[deployment]` number_k8s, ansible playbook

Example:

```toml
[g5k]
site = "rennes"
cluster = "paradoxe"
duration = "03:00:00"

[deployment]
number_k8s = 1
```

`duration` becomes the OAR walltime for the EnOSlib job.

---

## Step 8 – Start the deployment

```bash
cd ~/Agent_Sandbox/deploy-k8s-g5k
source ~/venvs/g5k/bin/activate
bash 01-deploy.sh
```

Expected start:

```text
Creating Kubernetes clusters......
Starting cluster 00......
Wait for 8 Secs
```

Internally the script:

1. Creates an OAR reservation (via EnOSlib)
2. Waits for resources
3. Boots VMs from the QCOW2 image
4. Runs `k8s.yml` (kubeadm + Cilium)
5. Runs `02-prepare.sh` (SSH key + kubeconfig copy)

No manual `oarsub` is required for this path.

---

## Step 9 – Monitor the reservation

```bash
oarstat -u
```

| State | Meaning |
|-------|---------|
| W | Waiting |
| R | Running |
| E | Error |
| T | Terminated |

```bash
oarstat -fj <jobid>
```

---

## Step 10 – Note the control-plane IP

When deploy finishes:

```text
Your Management Cluster Control Plane is 10.158.x.x
```

Save that IP. Kubernetes commands run **on the CP VM**, not on `frennes`.

---

# Part III – Agent Sandbox

## Step 11 – Connect to the Kubernetes control plane

```bash
ssh root@10.158.x.x
kubectl get nodes
```

Expected: control-plane + worker(s) in `Ready`.

---

## Step 12 – Check whether Agent Sandbox is installed

```bash
kubectl get crd | grep sandbox || true
kubectl get deploy -A | grep -E 'agent-sandbox|sandbox-router' || true
```

Fresh clusters from `01-deploy.sh` do **not** install Agent Sandbox yet.

---

## Step 13 – Install Agent Sandbox

On the control plane (or copy/run the helper from the repo):

```bash
# helper (from repo, after copying scripts onto the CP, or paste commands)
kubectl apply -f \
  https://github.com/kubernetes-sigs/agent-sandbox/releases/latest/download/sandbox-with-extensions.yaml

kubectl rollout status \
  deployment/agent-sandbox-controller \
  -n agent-sandbox-system \
  --timeout=180s
```

From this repo on the frontend you can also:

```bash
scp 04-install-agent-sandbox.sh root@<CP_IP>:
ssh root@<CP_IP> bash 04-install-agent-sandbox.sh
```

---

## Step 14 – Verify the installation

```bash
kubectl get crd | grep sandbox
kubectl get deploy -n agent-sandbox-system
kubectl get pods -n agent-sandbox-system
```

Expected CRDs:

```text
sandboxes.agents.x-k8s.io
sandboxclaims.extensions.agents.x-k8s.io
sandboxwarmpools.extensions.agents.x-k8s.io
sandboxtemplates.extensions.agents.x-k8s.io
```

Expected deployments: `agent-sandbox-controller`, `sandbox-router`.

---

## Step 15 – Create a namespace

```bash
kubectl create namespace agent-sandbox-demo
kubectl get ns
```

---

## Step 16 – Create a minimal Sandbox

Use the example in the repo:

```bash
kubectl apply -f examples/hello-sandbox.yaml
```

Or inline:

```bash
kubectl apply -f - <<'EOF'
apiVersion: agents.x-k8s.io/v1beta1
kind: Sandbox
metadata:
  name: hello
  namespace: agent-sandbox-demo
spec:
  podTemplate:
    spec:
      containers:
      - name: agent
        image: busybox
        command: ["sleep", "3600"]
EOF
```

---

## Step 17 – Verify Sandbox creation

```bash
kubectl get sandboxes -n agent-sandbox-demo
kubectl get pods -n agent-sandbox-demo
```

---

## Step 18 – Exec into the Sandbox

```bash
POD=$(kubectl get pods -n agent-sandbox-demo -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it "$POD" -n agent-sandbox-demo -- sh
```

```sh
echo "hello world"
exit
```

---

## Step 19 – Inspect

```bash
kubectl describe sandbox hello -n agent-sandbox-demo
kubectl get events -n agent-sandbox-demo
```

---

## Step 20 – Suspend a Sandbox

```bash
kubectl get sandbox hello -n agent-sandbox-demo -o yaml | grep operatingMode

kubectl patch sandbox hello -n agent-sandbox-demo \
  --type merge \
  -p '{"spec":{"operatingMode":"Suspended"}}'

kubectl get sandbox hello -n agent-sandbox-demo
kubectl get pods -n agent-sandbox-demo
```

Expected: `READY=False`, reason `SandboxSuspended`, no pods.

---

## Step 21 – Resume a Sandbox

```bash
kubectl patch sandbox hello -n agent-sandbox-demo \
  --type merge \
  -p '{"spec":{"operatingMode":"Running"}}'

kubectl get sandbox hello -n agent-sandbox-demo -w
# elsewhere:
kubectl get pods -n agent-sandbox-demo -w
```

Lifecycle:

```text
Running → Suspended → Running
```

---

## Step 22 – Optional state check

```bash
kubectl exec -it hello -n agent-sandbox-demo -- sh
```

```sh
echo "Agent Sandbox works" > test.txt
cat test.txt
exit
```

Use this to see what survives suspend/resume for a given storage config.

---

## Step 23 – Delete the Sandbox and namespace

```bash
kubectl delete sandbox hello -n agent-sandbox-demo
kubectl delete namespace agent-sandbox-demo
```

---

## Step 24 – Remove Agent Sandbox (optional)

```bash
kubectl delete -f \
  https://github.com/kubernetes-sigs/agent-sandbox/releases/latest/download/sandbox-with-extensions.yaml
kubectl get crd | grep sandbox || true
```

---

## Step 25 – Exit the control plane and destroy the cluster

```bash
exit   # back to frennes
cd ~/Agent_Sandbox/deploy-k8s-g5k
source ~/venvs/g5k/bin/activate
bash 03-delete.sh
oarstat -u
```

---

# Part IV – Deploying OpenSandbox (Batch Runtime)

OpenSandbox ≠ Agent Sandbox.

| Feature | OpenSandbox | Agent Sandbox |
|---------|-------------|---------------|
| Org | opensandbox-group | kubernetes-sigs |
| Purpose | Full sandbox platform | K8s-native sandbox operator |
| Install | Helm charts | `kubectl apply` |
| Runtimes | Docker, K8s, Fast Sandbox | Kubernetes only |

They can be combined later; install them independently.

## Step 26 – Clone OpenSandbox

On the **control plane** (needs git + helm):

```bash
mkdir -p ~/sandbox-platforms
cd ~/sandbox-platforms
git clone https://github.com/opensandbox-group/OpenSandbox.git
cd OpenSandbox
```

Charts live under `manifests/charts/` (not `./charts`).

## Step 27 – Install with the helper script

From this repo, after copying `05-install-opensandbox.sh` to the CP:

```bash
bash 05-install-opensandbox.sh
```

Or manually:

```bash
kubectl create namespace opensandbox-system
kubectl create namespace opensandbox

helm dependency build manifests/charts/opensandbox
helm template ./manifests/charts/opensandbox | kubectl apply -f -
helm upgrade --install opensandbox-gateway \
  manifests/charts/ingress-gateway \
  -n opensandbox-system
```

## Step 28 – Configure API key

Server may CrashLoop until `api_key` is set:

```bash
API_KEY=$(openssl rand -hex 32)
echo "$API_KEY"   # save this

kubectl get configmap opensandbox-server-config \
  -n opensandbox-system -o yaml > /tmp/opensandbox-server-config.yaml
# set api_key = "<API_KEY>" inside the embedded toml
kubectl apply -f /tmp/opensandbox-server-config.yaml
kubectl rollout restart deployment/opensandbox-server -n opensandbox-system
kubectl rollout status deployment/opensandbox-server -n opensandbox-system --timeout=180s
```

## Step 29 – Health check

```bash
kubectl port-forward svc/opensandbox-server -n opensandbox-system 8080:80 &
curl http://localhost:8080/health
# {"status":"healthy"}
```

---

# Part V – First OpenSandbox workflow (Python SDK)

On the control plane:

```bash
apt-get update
apt-get install -y python3-pip python3-venv
python3 -m venv ~/venv
source ~/venv/bin/activate
pip install opensandbox
```

Copy `examples/first_sandbox.py`, set `api_key` and `domain="localhost:8080"`, then:

```bash
python3 examples/first_sandbox.py
```

Debug:

| Symptom | Fix |
|---------|-----|
| Connection refused | Restart port-forward |
| 401 | API key mismatch vs ConfigMap |
| ImagePullBackOff | Pre-pull image / local registry |
| timeout | Larger `timeout` or smaller image |
| ModuleNotFoundError | `source ~/venv/bin/activate` |

Cleanup:

```bash
kubectl delete batchsandboxes --all -n opensandbox
helm uninstall opensandbox-gateway -n opensandbox-system || true
kubectl delete namespace opensandbox opensandbox-system
exit
# on frennes:
bash 03-delete.sh
```

---

# Troubleshooting (this repo)

| Issue | Cause | Fix |
|-------|-------|-----|
| `No module named 'enoslib'` | System Python | `source ~/venvs/g5k/bin/activate` |
| Missing `00-config.toml` | Wrong cwd | Scripts now `cd` to their directory; still prefer running from the repo |
| Missing `id_ed25519.pub` | Scripts expect ed25519 | This repo uses `id_rsa` / `id_rsa.pub` |
| Missing `cp_node_list` | Create failed mid-way | Fix root cause; do not ignore create failures |
| Manual `oarsub -I` waiting | Competing reservation | Cancel interactive job or wait; do not also run `01-deploy.sh` |
