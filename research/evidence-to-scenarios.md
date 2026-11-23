# Week 4 — From Five Real-World Agent Use Cases to Three Benchmark Scenarios

**Status:** evidence assessment and experimental design, not measured Grid'5000 benchmark results.  
**Provenance:** complements the [full research proposal](natalia.tex) mirrored from [Agent_Sandbox_Proposal@0669cd4](https://github.com/Paperpaperdog/Agent_Sandbox_Proposal/commit/0669cd459a7e5d38d582df73300b563dd1d74529) on 23 November 2026.

## 1. Central argument and evaluation method

**Question:** How do real applications create sandbox lifecycle demand, and which of these demands should a controlled Kubernetes benchmark reproduce?

We screened five candidate use cases against four criteria:

1. **Existence:** Is the application/workflow real rather than hypothetical?
2. **Evidence of use:** What source demonstrates actual operation, usage, deployment or only technical feasibility?
3. **Distinct lifecycle demand:** Does it create meaningful acquire, multi-command execution, idle, wake, resource admission, state persistence or cleanup behavior?
4. **Reproducibility:** Can we represent those requirements with deterministic tasks and independently verified results?

This is a **selection method**, not an assertion that five use cases have equally strong adoption evidence.

### Evidence categories must remain separate

| Category | What it supports | What it does **not** establish |
| --- | --- | --- |
| **Independently analyzed production telemetry** | Observed events, turn sequences, gaps and usage in a specified population and period | Adoption elsewhere; native sandbox-specific pause without runtime instrumentation |
| **Reported production deployment/operations** | A real operator deployed and ran the described infrastructure at reported workload scale | Identical behavior or performance on our Grid'5000 cluster |
| **Deployed engineering example / implementation** | A concrete integration and its state/lifecycle mechanism | Independent market-wide adoption or universal production frequency |
| **Industry survey** | Self-reported adoption among the survey's respondents | Direct production trace, requests per second or infrastructure-level lifecycle semantics |
| **Academic experiment or prototype** | A feasible mechanism or measured behavior under the paper's conditions | Standard operational use across agents/services |
| **Vendor or product documentation** | A capability is advertised/supported and sometimes how to invoke it | That customers actively use it, with what frequency or observed costs |

A reported number is useful only with its **unit, denominator/population, time window and evidence category**. An experimental N, idle gap or success threshold is a new design choice, not a number sampled from these sources.

## 2. UC1 — Interactive coding sessions

**Application pattern:** A coding agent edits a pinned repository, installs dependencies, runs tests, waits for human review or follow-up input, then continues the **same task and workspace**.

**Evidence:** [Liu et al., *Agentic Coding in the Wild* (2026)](https://arxiv.org/abs/2608.00101) analyzes real GitHub Copilot interaction traces and reports multi-turn behavior and gaps. The cited **243-second value** is a **median cross-turn container resource-idle interval** in the specified study, **not** a Kubernetes eviction or auto-suspend threshold. [Using Codex Cloud](https://help.openai.com/en/articles/20001545-using-codex-cloud) documents an application workflow with isolated coding workspaces; [SWE-agent](https://github.com/SWE-agent/SWE-agent) provides an open engineering workflow.

**Extracted lifecycle demand:** Maintain/recover files, dependency environment and task identity across an externally determined idle period, and measure the latency until the **next verified command**, not merely sandbox creation.

**Selection:** **Scenario A, primary.** We emulate the event sequence with two deterministic patch-and-test turns. The **120 s** initial review gap is synthetic for a short, repeatable pilot; it is **not** claimed to be the study's production median.

## 3. UC2 — Agentic reinforcement learning and parallel evaluation

**Application pattern:** A coordinator allocates isolated task environments, submits multiple commands, evaluates outcomes and releases many independent environments; task arrivals can be synchronized or sustained.

**Evidence:** [Yan et al., *Sandman* (2026)](https://arxiv.org/abs/2610.39711) reports actual operational sandbox demand from agentic RL, including approximately **3.1 million sandbox creations** across **four reported production SWE-bench Verified training campaigns in October 2026**. This is a **production creation-event count**, not a measured peak concurrency on Grid'5000. Controlled stress-test capacities in the paper must be labeled **experimental** rather than recast as production observations. [Terminal-Bench](https://arxiv.org/abs/2601.11868) and the [Harbor integration example](https://agent-sandbox.sigs.k8s.io/docs/use-cases/examples/harbor-terminal-bench/) support realistic isolated multi-command task and evaluation workflows.

**Extracted lifecycle demand:** Concurrent admission/provisioning, independent verified execution, cleanup, sustained churn and management overhead as offered load rises.

**Selection:** **Scenario B, primary.** A deterministic driver submits batches of independent trials, validates task oracles and records cleanup. N=10/25 are pilots; N=50 and above are capacity-gated *experimental* load points, not production replay.

## 4. UC3 — Persistent personal agents

**Application pattern:** A hosted agent maintains a per-user logical identity and private files/data even if the user temporarily leaves; a returning request must recover the correct application state.

**Evidence:** [Hermes Agents as a Service](https://agent-sandbox.sigs.k8s.io/docs/use-cases/examples/hermes-agents-as-a-service/) is an **official concrete engineering example** with idle-sweeper and wake-on-request design, including **PVC-backed file continuity** across native sandbox recreation. [Agent Substrate](https://github.com/agent-substrate/substrate) documents actor/worker lifecycle capabilities; research into serving intermittent agents motivates broader resource-sharing questions. These support mechanism feasibility and a real implementation pattern, **not measured market-wide adoption**.

**Extracted lifecycle demand:** Retain separate logical identities and state while sharing a verified finite number of active execution slots; evaluate user-return latency and resource cost under native idle handling and returning-user pressure.

**Selection:** **Scenario C, optional Phase 2.** Primary C1 observes the platform's **native idle/return policy**; the driver **does not explicitly suspend or resume**. An optional C2 probe explicitly invokes those operations only on eligible systems. PVC persistence **does not** prove live process-memory restoration.

## 5. UC4 — On-demand code execution (not a separate scenario)

**Pattern:** An application provisions a temporary environment for one submitted script, collects the output and destroys it.

**Available evidence:** [AWS Bedrock AgentCore Code Interpreter](https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/code-interpreter-resource-session-management.html), [Azure Container Apps Dynamic Sessions](https://learn.microsoft.com/en-us/azure/container-apps/sessions), [Vercel Sandbox](https://vercel.com/docs/sandbox), and [Modal's infrastructure documentation](https://modal.com/blog/scaling-to-1-million-concurrent-sandboxes-in-seconds) illustrate supported products/engineering claims. Product support itself does not establish independent customer adoption, workload rates or real utilization distributions.

**Decision:** **Absorb into Scenario B**: short-lived execution, result verification and cleanup are already represented by evaluation trials. A separate UC4 experiment would largely repeat the same lifecycle path.

## 6. UC5 — Stateful execution, checkpoint and recovery (cross-cutting)

**Pattern:** Snapshot, restore, clone, roll back or persist an environment so that later work can continue after resources are reclaimed or execution diverges.

**Available evidence:** [DeltaBox](https://arxiv.org/abs/2605.22781), [ARIES](https://arxiv.org/abs/2607.29069) and other systems work investigate state mechanisms and resource implications. Research prototypes or advertised snapshot operations are **not** proof that checkpoint/rollback has become the default practice across deployed agent infrastructure.

**Decision:** **Do not make UC5 an independent application scenario.** Treat state persistence and mechanism-level restoration as capabilities and correctness contracts relevant to A/C:
- **Tier 0:** independently verified command/result;
- **Tier 1:** independently verified file/SQLite continuity;
- **Tier 2:** separately verified live process or memory restoration.

An unsupported Tier 2 guarantee is **N/A**, not a Tier 0 task failure. Optional mechanism probes must not be silently mixed with primary native-policy observations.

## 7. Five-to-three decision table

| Use case | Strongest relevant evidence | Distinct infrastructure requirement | Benchmark treatment |
| --- | --- | --- | --- |
| **UC1 — Interactive coding** | Independently analyzed production interaction telemetry plus documented workflows | Idle gap, same-task continuation, state fidelity | **A — selected** |
| **UC2 — Agentic RL/evaluation** | Reported production sandbox operations plus evaluation engineering | Bursty/sustained provisioning, verified parallel tasks, cleanup | **B — selected** |
| **UC3 — Persistent personal agents** | Concrete documented engineering pattern; broader prevalence not demonstrated | Persistent identities, native idle handling, limited active slots | **C — selected conditionally** |
| **UC4 — On-demand execution** | Product capability documentation, independent frequency not established here | Short task create/execute/destroy | **Covered by B** |
| **UC5 — Checkpoint/rollback** | Academic/prototype and systems evidence, production-default status unconfirmed | State persistence, snapshot I/O and restore fidelity | **Cross-cutting A/C mechanism** |

**Answer to the supervisor's challenge — “Vendors claim suspend/resume, but is it really used?”**

- For UC1, the real multi-turn/idle behavior is independently observed; this **does not establish** any particular vendor's suspend implementation was invoked.
- For UC2, the operational infrastructure demand is documented at scale; controlled load-test numbers remain distinct from production counts.
- For UC3, Hermes demonstrates a concrete idle-sweep/wake integration and PVC continuity; we cannot infer its prevalence across users/services from the implementation example alone.
- For UC4/UC5, capability documentation and research may prove feasibility but are not sufficient production-usage evidence.
- Therefore the benchmark records **actual observed native lifecycle transitions** and state outcomes rather than assuming a claimed suspension feature is active.

## 8. From application events to testable infrastructure

| Real application event | Deterministic benchmark proxy | What is timed and verified |
| --- | --- | --- |
| Developer requests revision after review | Two pinned patch/test turns separated by an idle gap | Request-to-verified command; persisted workspace/tests; idle resource cost |
| Coordinator submits evaluation trials | Independent oracle-checked trial batch and bulk release | Offered vs successful throughput; first command; cleanup and API/controller cost |
| Personal-agent user returns | User-specific SQLite/files and staggered or stressed return requests | Native reactivation latency; cross-user isolation; occupancy and state correctness |

The **benchmark is about infrastructure**, not agent intelligence. Keep LLM inference, human decisions and model sampling **outside** timed infrastructure intervals. The [parameter definitions](parameter-rationale.md) and [canonical methodology](natalia.tex) govern the final experiments.

## References and scope

Core evidence is linked inline. The [technical appendix](docs/proposal-technical-appendix.md) retains additional reading with provenance; it does not turn unverified reports into observations. The source document is [Agent_Sandbox_Proposal](https://github.com/Paperpaperdog/Agent_Sandbox_Proposal). No new production trace analysis or Grid'5000 performance measurement is claimed in this Week 4 synthesis.
