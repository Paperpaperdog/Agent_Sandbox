# Week 3 — Scenario Protocol and Week 2 Measurement Reuse

**Purpose:** implement real-use-case-grounded scenarios without changing the original lifecycle-churn research objective or its measurement framework. This protocol complements [the scenario definitions](use_case_grounded_lifecycle_scenarios.md) and directly inherits the metrics from [Week 2 Methodology](https://github.com/Paperpaperdog/Agent_Sandbox_Proposal/blob/0669cd459a7e5d38d582df73300b563dd1d74529/sections/methodology.tex).

## 1. Workload contract

A **logical session** represents one coding task (including follow-up), one evaluation trial, or one persistent user agent. An external driver replays application events through a system-specific adapter. The platform decides which native Sandbox/Pod/Actor/worker operations are required.

| Application event | Completion boundary |
| --- | --- |
| **Acquire / first use** | Application request issued → **first verified command**; log identity allocation and Pod/platform readiness as separate intermediate events |
| **Execute** | Command submitted → validated output, exit status and relevant files |
| **Idle / follow-up** | Record last-command-to-next-request as **idle gap**; measure **return latency** from the next request to its first verified command with required state |
| **Release** | Release request → logical identity becomes inaccessible; separately record physical reclamation, warm capacity reuse and policy-retained data |

An application idle gap is **not** automatically a suspend operation. Compare common execution and file continuity across eligible systems; test native process/memory checkpoint only where supported and independently verified.

## 2. Three workload specifications

| Scenario | Replayed input | Main varying workload conditions | Correctness checks |
| --- | --- | --- | --- |
| **A. Coding continuation** | Pinned repo/issue; patch–test–review–follow-up–test | Idle/follow-up gap; concurrent tasks; cold vs warm | Original edits retained; tests pass; no leaked environment |
| **B. Evaluation batches** | Pinned Harbor/Terminal-Bench tasks with oracle commands and verifiers | Batch overlap; offered trial rate; task/image mix | Verified trial outcome; infrastructure errors separate; cleanup |
| **C. Persistent agents (optional)** | Per-user private state; message/cron–idle–wake | Logical users; active fraction; overlapping returns | Correct user state; scheduled execution; no cross-user state leakage |

**Scenario C arrival protocol (optional Phase 2).** After verifying persistent per-user state, replay **staggered returns as the primary mode**: initialize 20 users with nominal 10 s offsets and send each user's next request 300 s after its preceding verified command, twice. Log actual inter-arrival and idle times. The **secondary synchronized-burst probe** submits B=5/10/20 pre-initialized users' return requests within one second, solely to stress admission; it is not a production-arrival claim. N=20, target M=5 and gap=300 s are **synthetic design values**. Verify effective execution capacity natively (warm-pool spares are not an execution-capacity limit), and do not infer eviction from a 243 s median observed container idle interval. Report missing state fidelity or unmatched capacity rather than fabricating equivalent results.

Use **real application examples** to justify the sequence. Use measured timestamps only with an identified source; otherwise disclose synthetic values. [FreeInference Agentic Trace](https://github.com/HarvardMadSys/freeinference_agentic_trace) may inform session/tool gaps, but is **not** a Sandbox/Pod lifecycle trace and cannot supply genuine Hermes user-return or evaluation-batch distributions.

Keep live LLM output off the primary timed path so that variable model latency does not mask sandbox behavior. A small real-agent run may validate the relevance of the deterministic proxy.

## 3. Metrics: five core groups (Week 2 framework)

We keep the Week 2 lifecycle, control-plane, resource, and correctness dimensions but report **five core metric groups**. All task completions must pass independent verification; a Pod Ready event or successful API response alone does not count.

| Core metric | Operational definition | Source |
| --- | --- | --- |
| **1. Lifecycle latency** | Request-to-first-verified-command; return-to-first-verified-command (A/C); command and logical cleanup latency. Small cells: median, full samples and range; p95/p99 only with adequate samples | External driver + verifier |
| **2. Successful throughput** | Verified sessions/trials per second compared with offered rate over a declared time window; burst completion time and success fraction | Driver arrival and completion records |
| **3. Reliability & correctness** | Success, failure, timeout, missing results, file/DB continuity, state isolation and unexpected cleanup leaks | Driver assertions + platform resource checks |
| **4. Control-plane overhead** | Kubernetes API write requests and Kubernetes + specialized control-plane CPU-seconds per verified task, alongside raw totals | API-server counters + process/container CPU telemetry |
| **5. Resource efficiency** | Execution CPU-seconds, memory GiB-seconds and idle resource cost (A/C); reserved capacity separately | Worker/guest cgroup or host telemetry |

**Scenario emphasis:** A measures first-use/follow-up latency, state correctness and idle cost; B measures successful trial throughput, failures and control-plane cost as offered load increases; optional C measures return latency, state correctness and idle cost under limited execution capacity. For B, use **at least 95% success and no more than 2× low-load median first-command latency** for the exploratory load bracket; validate a separate **P95 tail-degradation bracket** only with at least **100 verified first-command observations at both the reference and tested load**, across declared independent repetitions. Otherwise call the P95 boundary **undetermined** and keep the success/median result descriptive.

**Measurement rules.** Use one monotonic client clock for each request/verification interval. The first command is a fixed correctness probe; task execution time is reported separately. Compare offered and completed work using the same declared observation window; preserve all failed, timed-out and incomplete attempts. For cells with **fewer than 100 verified completions**, publish raw or sorted latencies, median, range, failure/timeout counts, and per-run variation rather than a purported stable P95/P99. With at least 100, P95 may be reported descriptively alongside counts; P99 is optional only with much larger samples (e.g., 1,000 verified events), never a default requirement. These are practical reporting gates, not statistical precision guarantees. Do not manufacture a completion time for timeouts. In A/C1 the driver never forces suspend: the platform's native idle behavior is observed. An unsupported state contract is **N/A**, not zero or a failed operation.

**Normalization.** API writes cover CREATE, UPDATE, PATCH and DELETE (plus DELETECOLLECTION if exposed); count changes from `apiserver_request_total` in an isolated window. This counter cannot attribute a request to one logical session, so any idle-background subtraction is an **estimate**, not exact attribution. Control-plane CPU-seconds come from verified component CPU counters; worker CPU remains part of resource efficiency. Divide aggregate API write counts and CPU-seconds (including failed-attempt work) by the number of **verified successes**, and publish the raw totals and success count. A zero-success ratio is undefined, not zero. CPU core-seconds and memory GiB-seconds are **different units and are never added**; measured use and reserved capacity are also reported separately.

**Diagnostic metrics (conditional, not mandatory scores).** To explain bottlenecks, use available API duration histograms, Scheduler pending Pods, controller workqueues, etcd WAL fsync latency, platform-specific admission/pool metrics, and snapshot/restore timing or bytes. In-flight client requests are not queue depth. Histograms and queue gauges are not divided by task counts. Snapshot/process-memory metrics only apply to systems with verified native support. Confirm every diagnostic endpoint, counter/gauge/histogram type, labels and scrape interval on the pinned release; mark unavailable metrics **N/A**. Sub-second queue peaks require event-level traces or adequate sampling, not an assumed Prometheus gauge peak.

**Grid'5000 validation gate.** Before scale runs, record one successful and one intentionally failed probe, verify driver timestamps and output/state assertions, then compare no-load with a small known load for API, CPU and memory metrics. Record the actual metric names, component identity, missing samples and export path. Repeat feasible configurations at least three times; keep per-run distributions and failures.

## 4. Controls and comparability

Pin Grid'5000 nodes/topology, Kubernetes and candidate versions, resource limits, image/template preparation, cache/warm-pool condition, client placement, monitoring and identical task verifiers. For every run, record the effective **native idle policy** (auto-pause/reclaim enabled, idle TTL, retention, warm capacity and cleanup grace) and observed transitions. Treat **default** and **tuned** policy settings as separate test configurations; never silently pool them or call all differences architectural. Report intrinsic runtime differences (e.g., OCI versus Firecracker) rather than assigning every end-to-end difference to orchestration.

Five in-scope Kubernetes-based systems: **Native Pod; SIGs Agent Sandbox; OpenSandbox BatchSandbox; OpenSandbox + Fast Sandbox; Agent Substrate**. SIGs cold and warm paths are two configurations of the same system. An unsupported task image or native state operation must be labeled **unsupported**, not silently adapted or assigned zero time.

## 5. Immediate Grid'5000 pilot

1. **Minimal functional test:** Native Pod and SIGs perform two verified commands with file reuse and actual cleanup.
2. **Scenario A:** one pinned coding task with a same-task follow-up; record application events, API/controller metrics and state outcome.
3. **Scenario B:** a small verified trial batch; record offered/completed work, provisioning/release and control-plane activity.
4. **Architecture contrast:** attempt Agent Substrate or Kubernetes-integrated Fast Sandbox after checking prerequisites; log feasibility failures honestly.

The detailed host checks remain in [Grid'5000 Candidate PoC](grid5000_candidate_poc.md). **No deployment or performance result is claimed in this design document.**
