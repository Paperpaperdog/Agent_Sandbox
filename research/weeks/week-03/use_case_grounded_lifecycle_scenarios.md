# Week 3 — Real-World-Grounded Lifecycle Scenarios

**Project:** Agent Sandbox Lifecycle Churn (unchanged)  
**Update:** 15 November 2026  
**Scope:** Kubernetes-based sandbox systems only; scenario design, not experimental results.

## 1. Purpose

Our research still asks **how different Kubernetes-based sandbox architectures handle lifecycle churn and where control-plane/runtime bottlenecks arise under sustained and bursty workloads** ([original RQs](https://github.com/Paperpaperdog/Agent_Sandbox_Proposal/blob/0669cd459a7e5d38d582df73300b563dd1d74529/sections/research_questions.tex)).

The supervisor's feedback concerns **scenario realism**, not a change of topic. Instead of prescribing arbitrary create/suspend/resume loops, we derive **when a sandbox is needed, reused, inactive, reactivated or released** from real agent applications:

**Real application event → sandbox lifecycle demand → measurable control-plane/runtime work.**

The experimental systems remain **Native Kubernetes Pod, SIGs Agent Sandbox, OpenSandbox BatchSandbox, OpenSandbox + Fast Sandbox, and Agent Substrate**. The last two manage sandbox execution inside Kubernetes-managed workers rather than requiring one Pod per logical sandbox. E2B is excluded.

## 2. Proposed scenarios

| Scenario | Real application pattern | Lifecycle behavior of interest | Priority |
| --- | --- | --- | --- |
| **A. Coding-agent continuation** | Fix an issue, run tools, wait for developer review, continue the same task | Create/acquire, repeated exec, idle, reuse/reactivation, cleanup | **Primary** |
| **B. Parallel agent evaluation** | Run isolated trials, verify results, release environments, start the next batch | Concurrent create/exec/delete, refill, sustained churn | **Primary** |
| **C. Persistent personal agent** | Users become inactive, return, or trigger scheduled jobs | Long-lived logical sessions, reclaim, wake, simultaneous activations | **Optional** |

### A. Coding-agent continuation

**Real use case.** A developer asks an agent to fix a bug. The agent edits a repository and runs tests; the developer reviews the result and requests a follow-up **within the same task**. This behavior is documented for [Codex Cloud](https://help.openai.com/en/articles/20001545-using-codex-cloud) and is compatible with open coding-agent workflows such as [SWE-agent](https://github.com/SWE-agent/SWE-agent).

**Application event sequence:**

Task submitted → environment acquired → repeated code/test commands → human-review gap → follow-up request → execute in the retained workspace → verify → release.

**What this tests.** Sandbox acquisition; repeated execution without unnecessary re-creation; how idle resources are managed; the cost of making a previously inactive session usable; and whether edited files survive the declared continuity policy.

**Reproducible proxy.** Use one pinned public repository/issue, deterministic patch and test commands, a second follow-up patch, and independent file/test assertions. Obtain tool-count/gap timings from a measured trajectory where possible; otherwise mark them synthetic. The follow-up must use the **same logical task identity**.

**Lifecycle focus:** per-phase latency, reactivation and state correctness, API/controller/worker operations, and idle-resource cost. Idle does **not** automatically mean suspend.

### B. Parallel agent evaluation

**Real use case.** A coordinator executes many independent terminal/coding trials. Each trial needs an isolated environment, several tool calls, a verifier and cleanup. [Sandman](https://arxiv.org/abs/2610.39711) documents production-scale sandbox demand, while the official [Harbor/Terminal-Bench integration](https://agent-sandbox.sigs.k8s.io/docs/use-cases/examples/harbor-terminal-bench/) gives an executable application reference.

**Application event sequence:**

Batch assigned → trial environments acquired → repeated commands → verified results → release trial environments → next batch (possibly overlapping cleanup).

**What this tests.** Repeated provisioning and reclamation; concurrent admission; warm-pool/worker refill; Kubernetes versus specialized control-plane pressure; and where sustained lifecycle requests create queues or failures.

**Reproducible proxy.** Select a small pinned Harbor/Terminal-Bench task set with fixed images, oracle commands or deterministic tool scripts, and independent verifiers. Vary batch overlap and arrival rate only after a feasible Grid'5000 pilot. Report cold image/template preparation separately from warm reuse.

**Lifecycle focus:** successful trials/s, latency tails, queueing/failures, API/controller and specialized-control activity, resources per completed trial, and cleanup. A successful API response is not necessarily a successful trial.

### C. Persistent personal agent (optional)

**Real use case.** Each user has a logically persistent assistant but may be inactive for long periods. A user message or scheduled job makes the agent active again. The official [Hermes Agents-as-a-Service example](https://agent-sandbox.sigs.k8s.io/docs/use-cases/examples/hermes-agents-as-a-service/) documents warm claims, inactivity handling and PVC-backed wake-on-request.

**Application event sequence:**

Signup → user tool requests → inactivity → return/scheduled activation → state-checked execution → later deletion.

**What this tests.** Persistent logical identities sharing verified active capacity, native idle/re-entry cost, state correctness, and user return latency under **staggered arrivals (primary)**. A separately labeled **synchronized return burst (optional)** probes admission contention; it is a synthetic stress case, not a production arrival model. N=20, target M=5 and a 300 s idle gap are experimental parameters, not values inferred from traces. The ratio N/M alone does not guarantee queueing.

**Reproducible proxy.** Give each simulated user an independent file/SQLite state and a scripted request calendar. The user population and activity distribution are **synthetic until supported by a suitable trace**. PVC-backed Pod recreation preserves files, **not** live process memory.

### Minimal cross-platform smoke test

A short **code-interpreter-style task** (upload CSV → run computation → save file → execute another dependent command → delete) can validate basic acquire/exec/reuse/cleanup capability before running the primary scenarios. It is **not** an additional full benchmark scenario.

## 3. How these scenarios support the original research

| Real-world trigger | Lifecycle phenomenon | Main Week 2 metric groups |
| --- | --- | --- |
| Coding task starts or continues after review | Acquire, exec reuse, idle handling, reactivate | Per-phase latency; Kubernetes/specialized CP; state fidelity |
| Evaluation coordinator assigns and retires trials | Repeated create/exec/delete, concurrent admission, refill | Successful throughput; queue/error rates; API/etcd/controller work |
| Persistent user returns or cron job fires | Logical-session wake, concurrent reactivation | Wake latency; worker occupancy; resource and state correctness |

**Comparison rule:** the same application event must satisfy the same observable correctness contract on each platform, but may be implemented by different native operations. Compare **filesystem persistence** separately from **process/memory checkpoint restoration**. Do not force unsupported APIs or equate a Pod recreated from a PVC with a VM snapshot.

**Proposed scope:** implement **A + B** first; add **C** only if storage, gateway and runtime feasibility permit. The [measurement protocol](use_case_grounded_scenario_protocol.md) reuses the established Week 2 metrics instead of introducing another measurement framework.
