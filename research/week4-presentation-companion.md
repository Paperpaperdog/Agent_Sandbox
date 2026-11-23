# Week 4 Presentation Companion — 13-Slide Speaker Guide

**Presentation theme:** *From Real-World Agent Workloads to Benchmark Scenarios*  
**Presenters:** Natalia Naranjo and Bingrui Jin  
**Research source:** [complete master proposal](natalia.tex), [evidence review](evidence-to-scenarios.md), [parameter rationale](parameter-rationale.md).  
**Use:** English speaker cues / academic progress meeting; this document is a **textual companion** and **not the PowerPoint binary**.

The professor already knows the platform context. Emphasize the **quality of evidence**, the **five-to-three scenario decision**, what the **synthetic inputs actually mean**, and what remains **unvalidated on Grid'5000**. The 13 slides correspond to the Week 4 research story, not to 13 separate experimental claims.

## Slide 1 — From Real-World Agent Workloads to Benchmark Scenarios

**Say:** “This week we traced actual agent application behavior to infrastructure lifecycle requirements. We examined five candidate use cases, selected three representative workloads and turned them into a reproducible, correctness-checked experimental plan.”

**Meaning of numbers:** Five is the size of our candidate **use-case taxonomy**; three is the number of **selected benchmark scenarios**. Neither is a production statistic.

## Slide 2 — How Did We Identify Relevant Agent Workloads?

**Say:** “We screened each example for existence, evidence of real usage, distinct sandbox lifecycle requirements, and reproducibility. We distinguish observed production telemetry from an example implementation and from a product feature claim.”

**Methodology:** These are four **research-selection criteria**, not a numerical scored ranking. The outcome is a justified 5-to-3 mapping.

## Slide 3 — UC1: Interactive Coding Sessions

**Say:** “Real coding assistants perform multi-turn edits and tests. After a review gap, a correct follow-up must recover the right workspace and dependencies.”

**Evidence:** [Liu et al., GitHub Copilot traces](https://arxiv.org/abs/2608.00101) provide real interaction/gap observations; [Codex Cloud](https://help.openai.com/en/articles/20001545-using-codex-cloud) supplies a documented task workflow. A **243 s cross-turn container resource-idle median** reported in the study is **not** an eviction-policy threshold. Our **120 s** gap on Slide 10 is synthetic.

**Takeaway:** Need same-task state continuity and verified return latency, not just a “Pod Ready” timestamp.

## Slide 4 — UC2: Agentic RL and Evaluation

**Say:** “Independent evaluation trials require large numbers of short-lived isolated environments, multi-command execution, oracle checking and cleanup. This is directly relevant to control-plane bursts.”

**Evidence:** [Sandman](https://arxiv.org/abs/2610.39711) reports approximately **3.1 million sandbox creation events** in **four October 2026 production training campaigns**; its controlled stress tests are distinct evidence, not a claim about production peak concurrency. [Harbor/Terminal-Bench](https://agent-sandbox.sigs.k8s.io/docs/use-cases/examples/harbor-terminal-bench/) provides a concrete evaluation integration.

**Takeaway:** Our proposed N=50 trial batch is a **local experimental load**, not an attempt to replicate Amazon production scale.

## Slide 5 — UC3: Persistent Personal Agents

**Say:** “The key demand is to preserve a user's logical identity and private data while the service can reuse physical execution capacity during inactivity.”

**Evidence quality:** The [Hermes agents-as-a-service example](https://agent-sandbox.sigs.k8s.io/docs/use-cases/examples/hermes-agents-as-a-service/) demonstrates an engineering idle/wake workflow with **PVC-backed file continuity**. It is not evidence of widespread adoption, nor proof of restored process memory. Agent Substrate documentation establishes candidate platform capabilities, not measured real-world user volume.

## Slide 6 — Why UC4 and UC5 Are Not Independent Scenarios

**Say:** “UC4, on-demand execution, largely repeats B's create-run-check-delete path. UC5, checkpointing and recovery, is better treated as a mechanism and state-fidelity requirement within A/C.”

**Evidence limits:** A vendor providing a Code Interpreter does not independently prove production request rates; a checkpoint research paper does not prove that all agent platforms use it operationally. These are not rejected as useless—only as **redundant/less directly supported independent application scenarios**.

## Slide 7 — Cross-Cutting Infrastructure Requirements

**Say:** “Four recurring problems emerge: inactivity management, correct state preservation, latency when work resumes, and competition for finite execution capacity.”

**Clarification:** “Suspend/resume” is a *possible native implementation* of the application requirement—not something the driver should forcibly invoke in primary A or C1. This distinction makes platform comparisons more meaningful.

## Slide 8 — From Five Use Cases to Three Scenarios

**Say:** “Our selection is evidence-driven: A has independent multi-turn production telemetry, B has reported production sandbox demand, C has a concrete engineering pattern. UC4 is covered by B, and UC5 becomes a state-correctness/mechanism dimension of A/C.”

**Answer the professor:** “Is suspend/resume really used?” For the Hermes engineering example, idle handling and wake are **implemented**. We do **not** infer industry-wide prevalence. Our experiment logs actual native transitions and verifies correctness rather than equating capability with observed use.

## Slide 9 — From Application Behavior to Reproducible Experiments

**Say:** “We simulate the **infrastructure operations induced by applications**, not the intelligence of the AI agent. An external deterministic driver replays fixed commands and checks their results.”

**Measurement boundary:** Record request, identity assignment, readiness, **first verified command**, execution, idle gap, next request and logical/physical release. LLM inference, human feedback and model planning remain outside the timed infrastructure operation.

## Slide 10 — Scenario A: Coding-Agent Continuation

**Say:** “We execute exactly **two verified coding turns**, with a **120-second no-command gap** in between. Then we test whether the second turn can use the original workspace.”

**Explain the parameters:** **10 concurrent sessions** is the primary proposed pilot; **50/200** are capacity-gated sensitivities. **2 vCPU, 4 GiB memory, 10 GiB disk per session** are provisional requests, not observed utilization. The workspace estimate **50–200 MB** is unpinned until image/repo/patches are frozen. Five independent repetitions are preferred (three if constrained).

**Clarify:** The 120 s **idle input** is not included in **return latency** (return request → first verified follow-up command). Current 8-vCPU/16-GiB worker VM cannot fit 10 simultaneous sandboxes each requesting 2 vCPU/4 GiB; adjust the reservation or workload cell.

## Slide 11 — Scenario B: Parallel Agent Evaluation

**Say:** “Issue N independent trial requests in a burst; each performs **3–5 deterministic commands**, passes an oracle and releases its environment. Measure success, throughput, first-command latency, API overhead and cleanup.”

**Explain N:** Pilot with **10/25 trials**, try a **50-request batch** only if resources allow, then **100/200+** conditionally. N counts offered requests, **not the number simultaneously Running**. Task budget **1 vCPU/2 GiB per trial**, **30–60 s active target**, optional predeclared **300 s task deadline**.

**Heterogeneity:** **40/30/20/10** are synthetic **fractions of trial types**, not CPU utilization shares or production frequencies. **≥95% verified success** and **≤2× low-load median latency** are exploratory design thresholds. Only analyze a separate P95 tail boundary with at least **100 verified observations at both levels**, preserving failures and per-run variation.

## Slide 12 — Scenario C: Persistent Agent Oversubscription

**Say:** “Optional Phase 2 studies many persistent users under a verified limited active execution budget. The native policy decides whether an inactive identity stays running, is reclaimed or needs a wake.”

**Explain N, M, R:** **N=20 logical user identities**, target **M=5 verified execution slots**, so **R=N/M=4 logical users/slot** (dimensionless). This does **not** imply 15 users are waiting: queueing depends on overlapping requests and native admission.

**Schedule:** **Three requests/user**, two **300 s idle gaps**, nominal **10 s initial stagger**. A distinct stress probe returns **B=5/10/20 users** in about **1 s**. Per identity state is approximately **1 MB SQLite + two text files**. All inputs are synthetic and capacity-gated. **Primary C1 does not force suspend/resume; optional C2 is a separate explicit mechanism test.** Persisted SQLite is Tier 1, not automatic Tier 2 memory restoration.

## Slide 13 — Evaluation, Current Progress and Next Steps

**Say:** “We retain five metrics: lifecycle latency (ms/s), verified throughput (tasks/s), reliability/correctness (% and counts), Kubernetes/specialized management overhead (API writes and CPU core-seconds), and runtime efficiency (CPU core-seconds and GiB-seconds). This is a reproducible benchmark plan, not yet measured comparative performance.”

**Reporting:** For small cells (<100 successful observed commands), show raw values/median and failure rates instead of presenting unstable P95/P99. Keep preparation, default/tuned idle policy, topology, worker image, version and cleanup evidence fixed and documented.

**Implementation update:** Kubernetes bootstrap and Agent Sandbox/OpenSandbox installation helpers exist. Agent Substrate has a **six-stage automated deployment path**, pinned build provenance and a Counter Actor lifecycle **acceptance script**, with offline CI checks; a complete current Grid'5000 run and A/B adapter/metrics/replay are still to be validated. Prioritize Native Pod + SIGs common task contract, telemetry, then Substrate command endpoint. C and Fast Sandbox remain capacity/feasibility-gated.

## Source boundary and speaking guidance

All cited application and related-work links are collected in [the evidence review](evidence-to-scenarios.md) and [technical appendix](docs/proposal-technical-appendix.md). Slide values **3.1 million production sandbox creation events** and **243 seconds observed cross-turn idle median** are *source-reported observations of different systems/populations*. By contrast **120 s, 300 s, N=50 and N/M=20/5** are *proposed experiment inputs*. Never use production numbers as promises about our small Grid'5000 cluster.

The project still needs implementation work to turn the proposed task definitions and verification protocol into measured evidence. Refer to the full [master proposal](natalia.tex) for the authoritative scope and the [parameter rationale](parameter-rationale.md) for units and feasibility.
