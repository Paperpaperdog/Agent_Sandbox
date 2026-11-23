# Agent_Sandbox

Grid'5000 tooling for sandbox / substrate experiments.

| Directory | Purpose |
|-----------|---------|
| [`deploy-k8s-g5k`](./deploy-k8s-g5k) | Reserve nodes, create VMs, install Kubernetes (+ optional Agent Sandbox / OpenSandbox) |
| [`deploy-grid5000`](./deploy-grid5000) | Deploy **Agent Substrate** from source on an existing cluster and run Counter Actor acceptance |
| [**`research`**](./research) | **Complete research proposal**, technical appendix, Week 4 evidence-to-scenario rationale, units/parameter justification and 13-slide speaking guide |

Typical order: create the cluster with `deploy-k8s-g5k`, then run `deploy-grid5000` on the control plane.

**Tutorial:** [deploy-grid5000/TUTORIAL.md](./deploy-grid5000/TUTORIAL.md) — English walkthrough from Kubernetes to verified Agent Substrate.

## Research proposal and Week 4 materials

The full **Agent Sandbox Lifecycle Churn** plan is available in [research/README.md](./research/README.md):

- [**Six-section master proposal (LuaLaTeX)**](./research/natalia.tex) — research question, five Kubernetes architectures, benchmark methodology, Scenarios A/B/C, experimental feasibility, expected analysis and references.
- [**Technical and reproducibility appendix**](./research/docs/proposal-technical-appendix.md) — deterministic workloads, API/adapters, controls, failure taxonomy and Grid'5000 pilot gates.
- [**Five real-world use cases → three scenarios**](./research/evidence-to-scenarios.md) — strength and limitations of production telemetry, engineering deployments, research and vendor evidence.
- [**Experimental parameters and units**](./research/parameter-rationale.md) — detailed reasoning for idle gaps, resource budgets, concurrency, active slots, load criteria, metrics and sample sizes.
- [**Week 4 slide-by-slide English speaker guide**](./research/week4-presentation-companion.md) — 13-slide narrative and notes companion.

The research documents are a **dated snapshot** of the separate [canonical Agent_Sandbox_Proposal repository](https://github.com/Paperpaperdog/Agent_Sandbox_Proposal) at commit `0669cd4`, and are **not automatically synchronized**. Existing deployment code and CI are not the same as completed comparative benchmark results.
