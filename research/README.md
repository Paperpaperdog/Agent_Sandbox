# Agent Sandbox Lifecycle Churn — Complete Research Plan

**Week 4 working snapshot:** 23 November 2026  
**Researchers:** Bingrui Jin and Natalia Naranjo Rodríguez — Télécom Paris  
**Supervisor:** Chih-Kai Huang  
**Canonical research source:** [Agent_Sandbox_Proposal](https://github.com/Paperpaperdog/Agent_Sandbox_Proposal), commit [`0669cd4`](https://github.com/Paperpaperdog/Agent_Sandbox_Proposal/commit/0669cd459a7e5d38d582df73300b563dd1d74529).

This directory places the **full research plan next to its Grid'5000 deployment implementation**. It is a dated, reviewable copy, **not** a replacement for the canonical proposal repository and **not** automatically synchronized. The current deployment scripts remain in [`deploy-k8s-g5k`](../deploy-k8s-g5k) and [`deploy-grid5000`](../deploy-grid5000).

## 1. Start here

| Document | Purpose |
| --- | --- |
| [**Full master proposal — `natalia.tex`**](natalia.tex) | Complete six-section academic proposal, references, scope, research questions, taxonomy, methodology, experiments, feasibility and limitations; LuaLaTeX |
| [**Technical appendix**](docs/proposal-technical-appendix.md) | Detailed reproducibility protocol: task commands/oracles, adapter mappings, failure categories, capacity, Grid'5000 PoC, trace calibration, additional reading |
| [**Evidence: five use cases to three scenarios**](evidence-to-scenarios.md) | Week 4 narrative, evidence hierarchy, why each case was selected or excluded, and boundaries between independent usage evidence and vendor claims |
| [**Experimental parameter rationale**](parameter-rationale.md) | Units, definitions, scientific reasoning, feasibility gates, metric formulas and statistical reporting |
| [**Week 4 presentation companion**](week4-presentation-companion.md) | 13-slide speaking map with brief English explanations and suggested parameter/evidence talking points |
| [Week 3 scenario definitions](weeks/week-03/use_case_grounded_lifecycle_scenarios.md) | Application-first A/B/C behavior and state semantics |
| [Week 3 scenario protocol](weeks/week-03/use_case_grounded_scenario_protocol.md) | Common driver events, oracle boundaries, five metric groups, default-idle-policy controls |
| [Literature and benchmark reading](weeks/week-03/benchmark_reading.md) | Related-work table and evidence-quality distinctions |
| [Historical candidate feasibility plan](weeks/week-03/grid5000_candidate_poc.md) | Earlier host/prerequisite checks: **historical planning notes**, not a report of the revised deployment |

**Compiling the master:** select `research/natalia.tex` as the main LaTeX document with **LuaLaTeX**, or run `latexmk -lualatex -interaction=nonstopmode -halt-on-error natalia.tex` from this directory. No external `\\input` files are required by this master. Links embedded in the source may intentionally point back to the canonical proposal.

## 2. Research question

> How do Kubernetes-based sandbox architectures handle lifecycle churn, and where do control-plane and runtime bottlenecks emerge under sustained, bursty, and intermittent agent workloads?

- **RQ1 — Cost placement:** Which operations and costs occur in Kubernetes, specialized controllers/worker pools, runtimes and storage?
- **RQ2 — Load response:** When do verified throughput, latency and reliability degrade under bursts or sustained churn?
- **RQ3 — Idle and state:** How does a platform's **native idle policy** trade idle resource cost against correct follow-up latency?

Our study is **not** a product ranking based on startup time alone. Each successful task must finish an **independently verified command or application oracle**.

## 3. Candidates and feasibility order

| Configuration | Architectural contrast | Current study priority |
| --- | --- | --- |
| Native Kubernetes Pod | One direct Pod lifecycle per sandbox; cold baseline, with optional warm pool reported separately | **P0** |
| Kubernetes SIGs Agent Sandbox | Sandbox/Claim controller and optional WarmPool; measure reconciliation/refill work | **P0** |
| Agent Substrate | Persistent Actor identities, WorkerPools and checkpoint/restore mechanisms; application command adapter still to be verified | **P1 conditional** |
| OpenSandbox + Fast Sandbox | Fastlet-managed Firecracker guests under Kubernetes; needs host virtualization prerequisite check | **P1 conditional** |
| OpenSandbox BatchSandbox | OpenSandbox API backed by Kubernetes Pods; measure its actual control path only if sufficiently distinct | **P2 conditional** |

E2B and hosted remote services are **not** part of the controlled Kubernetes comparison. The presence of an installer does **not** mean its target has passed functional or benchmark validation.

## 4. Application-grounded experiment scope

Five investigated use cases are mapped into **three** distinct experimental workloads (see [evidence review](evidence-to-scenarios.md)):

| Selected workload | Meaning | Priority |
| --- | --- | --- |
| **A — Coding-agent continuation** | Two deterministic coding turns with an idle/review gap; subsequent command checks reuse and correct state | **Primary** |
| **B — Parallel agent evaluation** | Independent short trials in synchronized bursts and sustained arrivals, each verified and cleaned up | **Primary** |
| **C — Persistent multi-user agents** | Independent identities and limited verified active execution capacity under staggered returns and secondary wake bursts | **Optional Phase 2** |

UC4 (on-demand one-off execution) is included in B's short-lived trial behavior. UC5 (checkpointing/rollback) is a **mechanism and state-fidelity dimension**, not a required fourth or fifth application scenario.

For A and primary C1, the benchmark driver **does not force suspend/resume**. It observes native policy. Explicit C2 suspend/resume is optional and evaluated only where supported.

## 5. Shared measurement contract

Common operations are `acquire -> execute/verify -> optional idle/follow-up -> release`, adapted to each platform's native API. Capture two separate cleanup events: logical identity becomes inaccessible and physical resources are eventually reclaimed. A/Kubernetes Pod Ready is not a substitute for successful first command.

1. **Lifecycle latency** — request-to-first-verified-command, follow-up, active execution and logical/physical cleanup (ms or s).
2. **Successful throughput** — correctly verified outcomes per unit time (tasks/s or trials/s).
3. **Reliability and correctness** — successful/failed/timed-out attempts, file or SQLite continuity and isolation (% plus counts).
4. **Management/control-plane overhead** — API writes, controller/management CPU-seconds per verified completion, with raw totals.
5. **Runtime/resource efficiency** — runtime CPU core-seconds, memory GiB-seconds, separate active/idle and reserved capacity.

Record actual cache/warm-pool preparation, CNI/runtime, image and resource settings, cluster size, client location, **native idle thresholds**, default-versus-tuned mode and all failures. Compare Tier 0 verified commands first, Tier 1 persisted files/SQLite only where supported, and Tier 2 process/memory restoration as a distinct optional mechanism.

## 6. Implementation status versus proposed experiments

**Repository source status (23 November 2026):** EnOSlib/VM Kubernetes bootstrap exists; the Agent Sandbox and OpenSandbox install helpers exist; Agent Substrate has automated multi-phase installation and Counter Actor suspend/resume smoke-test **code**, with source/version capture and CI for Bash, ShellCheck and Python unit tests. See [deployment guide](../deploy-grid5000/README.md) and [GitHub Actions workflow](../.github/workflows/substrate-deployment-checks.yml).

**Not established by the repository:** a clean current Grid'5000 reservation independently rerunning the revised scripts; a cross-platform `acquire/execute/release` task adapter; frozen A/B input images and task subsets; full monitoring and reproducible repeated A/B/C performance results. Existing Counter continuity is **not** proof of arbitrary process-memory restoration.

The default `deploy-k8s-g5k/00-config.toml` is a **small VM PoC** (one physical server, one 8-vCPU/16-GiB control-plane VM and one 8-vCPU/16-GiB worker VM), not the preferred final one-control-plane/two-worker research topology. See [parameter and capacity gates](parameter-rationale.md) before declaring N=10/50/200 feasible.

## 7. Next experimental gates

1. Pin the Grid'5000 reservation, Kubernetes/platform commits, task images and actual allocatable CPU/RAM; verify network, storage, registry and telemetry.
2. Implement the same deterministic command/verification contract on **Native Pod** and **SIGs Agent Sandbox**; capture a baseline under low load.
3. Deploy Prometheus-compatible API/controller, node and worker metrics plus driver event logs; explicitly log unsupported metrics.
4. Verify Agent Substrate on the revised scripts and expose a real command endpoint in an Actor image (Counter alone is insufficient).
5. Run a small, fully logged **Scenario A** followed by **Scenario B** before any concurrency increase; preserve failed attempts and independent runs.
6. Add C1 only with verified Tier 1 state and effective execution-capacity controls. Explore Fast Sandbox/BatchSandbox only after feasibility and architectural-distinction checks.

No performance result or universal platform ranking is claimed here.

## Source and synchronization policy

This document set is a **snapshot** from `Paperpaperdog/Agent_Sandbox_Proposal@0669cd4`. The mirrored master `natalia.tex` is byte-identical to that version; a few companion Markdown files have only cross-repository relative links rewritten so links continue to work here. New evidence and parameter explanation docs contextualize, but do not supersede, the master. Future research edits should be made in the canonical proposal first and mirrored deliberately with a new pinned source commit; do not silently edit two divergent masters.
