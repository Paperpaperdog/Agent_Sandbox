# Agent_Sandbox

Grid'5000 tooling for sandbox / substrate experiments.

| Directory | Purpose |
|-----------|---------|
| [`deploy-k8s-g5k`](./deploy-k8s-g5k) | Reserve nodes, create VMs, install Kubernetes (+ optional Agent Sandbox / OpenSandbox) |
| [`deploy-grid5000`](./deploy-grid5000) | Deploy **Agent Substrate** from source on an existing cluster and run Counter Actor acceptance |

Typical order: create the cluster with `deploy-k8s-g5k`, then run `deploy-grid5000` on the control plane.
