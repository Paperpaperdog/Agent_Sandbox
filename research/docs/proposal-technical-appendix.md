# Technical Appendix — Agent Sandbox Lifecycle Churn

**Status:** implementation and reproducibility notes, not completed benchmark results.
**Companion master proposal:** [natalia.tex](../natalia.tex).
**Source preserved:** [complete pre-consolidation proposal at commit 924501e](https://github.com/Paperpaperdog/Agent_Sandbox_Proposal/blob/924501eca5448bc4dca263364cbdb7f9e6718d04/natalia.tex).

The concise proposal presents the motivation, architecture taxonomy, common methodology, primary scenarios, testbed gates and intended analysis. This technical document retains the detailed operational decisions and examples from its former Sections 4–14 and 16. Specific ports, APIs, resource sizes, and version-sensitive capabilities below are **candidate settings to verify**, not confirmed Grid'5000 observations.

## A. Scenario A: pinned coding continuation

**Application contract.** Two turns in one logical coding task, one artificial 120-second human-review gap, and no forced suspend/resume. The adapter may map the logical identity to a different physical worker after native reclamation, provided that the expected workspace and dependencies remain intact.

| Turn | Step | Planned command | Verification/purpose |
| --- | --- | --- | --- |
| 1 | 1 | python -m venv .venv | Python environment exists |
| 1 | 2 | .venv/bin/pip install -r requirements.txt | Exact pinned dependencies; log cache/mirror and external egress |
| 1 | 3 | git apply patch1.diff | First bug-fix edit, applied to a fresh repository state |
| 1 | 4 | .venv/bin/pytest -q tests/ | First patch verified |
| — | — | Idle for 120 s | Driver sends no command and does not suspend |
| 2 | 5 | git apply patch2.diff | Follow-up edit to the same logical identity |
| 2 | 6 | .venv/bin/pytest -q tests/ | Final task verification |
| 2 | 7 | git diff HEAD | Compare against expected combined patch |

The public repository, revision, patch1/patch2, requirements and image are **not yet pinned in the proposal as a completed benchmark artifact**; freeze these before execution. Commands are deterministic when started from a known state, but applying a patch is not generally idempotent. Every retry must reset or record its task state.

**Verification:** pinned package versions; expected patch digest; test-suite exit status; SHA-256 digests of selected files; unchanged logical identity; no unrelated files or cross-user state. Unexpected output/test failure maps to F5; lost state across idle maps to F6. Planned active walltime target 30–60 s and workspace size approximately 50–200 MB are preliminary and must be measured before comparisons.

**Scale:** 10 simultaneous sessions as the small cell; 50 and 200 conditional. The suggested 2 vCPU/4 GiB request means 200 sessions would reserve about 400 vCPUs and 800 GiB memory, before system overhead, if all ran concurrently. Do not force these levels on insufficient Grid'5000 hardware. An optional 600 s gap may probe a different native idle threshold but guarantees no pause/eviction outcome. A short 120 s gap is not a production trace replay.

## B. Scenario B: independent evaluation trials

**Application contract.** A coordinator issues isolated tasks. Each task acquires an environment, performs several independently checked commands, records a verified outcome, then releases the environment. Trial state does not carry over into the next trial.

**Proxies:** pin a small Harbor/Terminal-Bench task subset, image digests and oracle scripts; where agent behavior is unstable, use deterministic scripts to measure sandbox infrastructure rather than LLM variability. Provisional task size: 3–5 commands, 30–60 s work, 1 vCPU/2 GiB resources, 5-minute hard deadline only when agreed as the experimental task timeout.

**Optional synthetic workload mix:**

| Fraction | Component | Examples |
| --- | --- | --- |
| 40% | I/O / network | package installation or fixed HTTP fetch |
| 30% | network / filesystem | pinned repository checkout and search |
| 20% | CPU-intensive | unit tests or compilation |
| 10% | minimal | short commands and health checks |

The 40/30/20/10 distribution is a controlled design choice, not a measured evaluation-platform arrival distribution. Report cache or mirror conditions separately and record whether each task depends on external egress.

**Primary burst exploration:**
1. Pilot at N=10/25. Establish an interpretable low-load reference and task correctness.
2. If admitted, explore N=50, 100, 200, 400, 800 and up to 1,000, stopping when hardware or task correctness makes the next level infeasible. The ceiling is not a required target.
3. During the **exploratory sweep**, provisionally pass a level if at least 95% of offered trials finish correctly before their deadline and **median** first-verified-command latency is no more than 2× that platform's low-load median. This is a small-sample screening rule, not a validated P95 result or a production SLO.
4. Repeat the last passing and first failing levels five times where feasible. Validate a **separate tail-degradation criterion** (p95 at most 2× the baseline p95) only once **both the baseline and compared level contain at least 100 verified first-command observations across the predeclared repeated runs**. Otherwise report a success/median-based interval and mark the P95 boundary **undetermined**. Always retain per-run samples and failures. If N=50 fails, test smaller loads; if all levels pass, do not invent a knee.
5. Report a common feasible batch size across systems separately from each platform's transition interval. Require instrumentation before naming the bottleneck.

**Secondary sustained churn:** Choose one feasible common offered rate R0 after the pilot, then three equal-duration tests at R0/2, R0 and 2R0. Retain an unchanged task mix, fixed preparation budget and all failed requests. A short sweep reveals possible trends but cannot establish an exact sustained saturation point.

**Sample-size policy:** With fewer than 100 verified completions for a declared analysis cell, publish raw/sorted completion latencies, median, range, attempt outcomes, and run-to-run variation. P95 is a descriptive metric only when the measurement count supports it; 100 is a pragmatic minimum, not proof of confidence. P99 is optional only with much larger samples (e.g. at least 1,000 verified completions). Timeouts are never converted into successful-completion latencies.

## C. Scenario C: stateful multi-tenant agent users (optional Phase 2)

**Independent value:** A measures task continuation; B measures ephemeral trials; C measures N persistent user identities sharing M verified active-execution slots. The pattern is motivated by intermittent agent use, but the exact values are synthetic.

| Parameter | Initial design | Eligibility and interpretation |
| --- | --- | --- |
| N | 20 persistent logical users | Optional 50/100 only with hardware and state readiness |
| M | Target 5 active execution slots | Must be a measured, platform-enforced budget; do not confuse it with five warm-pool spare Pods |
| N/M | Nominal ratio 4 | Does not imply that four users contend at any instant or that a queue exists |
| Requests | 3 per identity | Initial command plus two independently checked returns |
| Per-user gap | 300 s twice | Intermediate exploratory gap; optional 60/600 s policy sensitivity |
| Stagger | Nominal initial offsets of 10 s | Actual return arrival and idle times are logged; not a production trace |
| Stress burst | B=5/10/20 within 1 s | Optional separate test, B must not exceed initialized N |
| State | About 1 MB SQLite and two text files | Independent private-state and cross-user isolation checks |
| Resources | Provisional 2 vCPU/4 GiB active environment | Depends on real host allocatable capacity |

The source proposal's cited 243 s figure is a **median observed cross-turn container-idle interval**, not an eviction policy threshold. Neither it nor the 25.2-minute median user gap requires a particular runtime state after 300 s.

**C1 primary staggered mode:** Initialize users at nominal 10-second offsets, verify each one's data, and schedule the next request exactly 300 s after that user's previous verified command; repeat once. Record actual time offsets, native keep-alive/auto-pause/recreate behavior, user-return latency and file/DB checks. Do not send an explicit suspend/resume operation from the driver. A zero measured queue is a valid observation.

**C1 secondary stress mode:** In a separate cell with already initialized, idle and verified identities, submit B user-return requests within a one-second target window. Compare success/timeout fractions, drain time, state correctness and observed admission signals. Do not claim the burst reproduces normal production arrivals or is a mathematically proven worst case. In 5/10-user cells, report individual latencies rather than presenting unstable p99 statistics.

**C2 (mechanism-only):** Only on platforms with demonstrably comparable mechanisms, explicitly request suspend, verify a durability barrier, resume, and independently verify required file or process state. C2 is distinct from the C1 user-experience benchmark.

**State strata:** Tier 0 = verified command; Tier 1 = file/DB continuity; Tier 2 = live memory/process restoration. Kubernetes Pod recreation with PVC is not Tier 2. Native Pod, SIGs, OpenSandbox Batch, OpenSandbox + Fast and Agent Substrate require version-pinned state probes; unsupported state contracts are N/A, not zero performance.

## D. Common adapter interface and system mapping

The external driver speaks an application-level contract. The adapter must preserve the logical identity even if the native platform rebinds its underlying Pod/VM/actor. Record the deployed **idle policy and effective values** (default versus tuned mode, idle timeout/TTL, automatic pause/reclaim, cleanup grace, retention and warm-pool settings) for each run; changed policies define distinct experimental cells, never pooled results.

| Operation | Planned signature | Result or observation |
| --- | --- | --- |
| acquire | acquire(session_id, image, resources, egress, state_policy) | execution_id, ready_ts, native path |
| execute | execute(execution_id, command, timeout_s) | exit_code, stdout/stderr, completed_ts |
| release | release(execution_id, retain_state) | logical_release_ts, reclaimed_ts if observable, retained data |
| state (passive) | state(execution_id) | native phase and available resource/pool state |
| suspend/resume | optional C2 only | durability barrier, restore path and verified first command |

For A and C1, a follow-up is an **execute on the original logical handle**. The adapter may transparently wake/rebind the execution backend. A newly empty environment that loses required state is a correctness failure. Logical release, pool reuse and physical reclamation are distinct events. The driver does not decide native warm versus cold allocation, scheduling node or automatic idle policy.

The following are **historical design notes for the pinned source snapshot**, not immutable live API guarantees:

| Candidate | Example acquisition / execution path | Important constraints to revalidate |
| --- | --- | --- |
| Native Pod | Kubernetes Pod create; kubectl exec via Kubernetes/CRI; delete Pod | Warm Pod allocator is optional custom baseline; retention via a configured volume is a separate state contract |
| SIGs Agent Sandbox | SandboxClaim to Sandbox/Pod; SDK to sandboxd ProcessService.Execute over gRPC (historical :9090) | Correct CRD group/version, warmPoolRef naming, claims/refill, documented idle/PVC policy |
| OpenSandbox Batch | OpenSandbox HTTP API; execd (historical :44772) | Token/header behavior varies with secureAccess and release; validate provider SDK and Pod backend |
| OpenSandbox + Fast | OpenSandbox API to FastPath/Fastlet and guest microVM; execd route | Firecracker/KVM, TUN/cgroups, snapshot/template setup, FastPath credentials; volume-backed per-user state may be unsupported |
| Agent Substrate | CreateActor/ResumeActor; command server within actor reached through an atenet router (historical :8444 to :8080) | Command endpoint must exist in image; mTLS and actor routing; SuspendActor modes and process-state fidelity |

**Breaking-change cautions from the pre-consolidation document:** SIGs claim spec field spelling and CRD versions; OpenSandbox Batch execd access-token behavior; Fast Sandbox ingress credentials and pause support; OpenSandbox timeout exception names; Agent Substrate removal of PauseActor, explicit durability mode for SuspendActor, and actor-target routing header. Recheck the exact release/commit before writing adapters or issuing requests. See the [full prior §10 mapping](https://github.com/Paperpaperdog/Agent_Sandbox_Proposal/blob/924501eca5448bc4dca263364cbdb7f9e6718d04/natalia.tex) for source-level examples, port and header details.

## E. Failure taxonomy and accounting

Each failed attempt records raw error, logical task/user ID, timestamps, environment version and any native lifecycle events. Do not invent successful-completion latencies for requests that timed out.

| Code | Category | Meaning |
| --- | --- | --- |
| F1 | Permission / host precondition | Missing host KVM/TUN/cgroup/storage capability or access |
| F2 | Installation / configuration | CRD/controller/image or Kubernetes-version mismatch |
| F3 | Create failure | Acquire never yields a usable execution identity by deadline |
| F4 | First-command timeout | Execution identity exists but first command cannot complete |
| F5 | Incorrect task output | Exit, stdout, tests or files fail the task oracle |
| F6 | State loss | Required file/DB state missing or corrupt after idle/re-entry |
| F7 | Checkpoint incomplete | Optional native C2 durability/restore probe fails; zero snapshot bytes alone is not proof |
| F8 | Restore failure | Restored process is nonfunctional or its required memory state is lost |
| F9 | Cleanup leak | Released identity retains unexpected resources beyond its documented retention policy and grace period |
| F10 | Unknown | Needs triage; retain underlying evidence |

F1/F2 are environment/feasibility outcomes, reported but not folded into task-performance rates when they prevent deployment. F3–F10 are workload failures counted in the offered-work success denominator as applicable. Valid prewarming and policy-retained PVCs are not automatically leaks.

## F. Grid'5000 and candidate feasibility

The provisional topology is one Kubernetes control plane and two homogeneous workers at Rennes/paradoxe, subject to a real OAR allocation. Do not claim the entire advertised cluster or any specific machine inventory was reserved. Hardware, walltime, network, storage class and node IDs are **per-run facts** to log.

**Pilot sequence:** verify authorized frontend access and reservation; check kernel, CPU, RAM, cgroup v2, disk and networking; ensure KVM/TUN only when the candidate needs them; provision Kubernetes with CNI and a working persistent-volume path; install monitoring and no-load baselines; first run Native Pod smoke test, then SIGs; attempt specialized architectures only after the relevant gates; retain manifests, logs and errors.

**Safety:** Kadeploy reimages reserved machines; never execute sample reimaging commands on a machine with unbacked-up work, without the correct deployment reservation or without verifying the site's supported image. The presence of /dev/kvm alone is not proof a guest microVM can start; test an actual create/execute/teardown operation.

See [Grid'5000 deployment guide](https://github.com/Paperpaperdog/Agent_Sandbox_Proposal/blob/0669cd459a7e5d38d582df73300b563dd1d74529/docs/grid5000-deployment-guide.md) and [Grid'5000 PoC design](../weeks/week-03/grid5000_candidate_poc.md). Existing historical deployment script examples may change SSH host keys or handle private keys, so inspect and adapt them before running.

**PoC record template:**

| Field | Record at run time |
| --- | --- |
| Date/operator/site, reservation ID and node IDs | Not yet measured |
| Node hardware, allocatable CPU/RAM, kernel, storage, KVM/TUN checks | Not yet measured |
| Git revision, Kubernetes/platform/image versions | Not yet measured |
| Native idle policy and any overrides (auto-pause/reclaim, inactivity TTL, retention, cleanup grace, warm-pool spares) | Not yet measured |
| Enforced execution-capacity limit and observed native lifecycle transitions | Not yet measured |
| Task commands, first verified execution, repeated execution | Not yet measured |
| File/DB and optional process-state verification | Not yet measured |
| Release, observed residual resource state, cleanup policy | Not yet measured |
| Raw driver logs, metric queries, CPU and memory series | Not yet measured |
| Failures, timeouts, workarounds and next action | Not yet measured |

**Instrumentation readiness:** At least one successful and one intentionally failed client probe; correlated API count/latency and CPU/memory series under no load versus a small known load; actual available platform metrics/OTLP or exporter endpoints; scrape resolution; raw logs and UTC or clock-corrected event timestamps. Preserve the effective policy configuration next to each run (config map, flag, CRD spec or manifest) and the observed transition events so a default-policy comparison is not mistaken for controlled identical idle settings. Kubernetes API counters are not per-session labeled; use isolated windows for background-adjusted estimates. A slow Prometheus scrape cannot recover an unobserved sub-second queue peak.

## G. Optional FreeInference trace calibration (not a prerequisite)

The [FreeInference Agentic Trace](https://github.com/HarvardMadSys/freeinference_agentic_trace) may inform observed session/tool gap distributions for optional sensitivity tests. The former appendix describes a 16-week 2026 dataset (12,002 sessions, approximately 1.19 million LLM requests, 1.21 million tool calls and 267 accounts) with sanitized timing/metadata. These are **source-document figures**, not data newly downloaded or verified in this rewrite.

**Can investigate:** observable session durations, tool calls per session, harness-specific tool latencies, inter-tool-call gaps and overlapping activity where timestamps permit.

**Cannot directly infer:** real Pod creates/deletes, Kubernetes API counts, native suspend/eviction events, microVM CPU/memory, hidden prompts or exact tool code. A long timing gap may combine model inference, harness scheduling and human activity; do not label every gap as human think time.

The original extraction plan is: inspect schema/licensing/partitions; select independent session versus nested-agent unit; rebuild clocks and observable gaps; characterize distributions and missingness; map source-backed values to optional Scenario A/C sampling; publish derived event definitions and limits. Scenario B's synchronized evaluation arrival distribution cannot be derived from this trace.

This is a **separate exploratory calibration task**. Neither Scenario A/B implementation nor this version of the master proposal depends on completing it.

## H. Source continuity and follow-up reading

- [Current concise master proposal](../natalia.tex)
- [Complete pre-consolidation proposal](https://github.com/Paperpaperdog/Agent_Sandbox_Proposal/blob/924501eca5448bc4dca263364cbdb7f9e6718d04/natalia.tex)
- [Week 3 scenario protocol](../weeks/week-03/use_case_grounded_scenario_protocol.md)
- [Week 3 application use cases](../weeks/week-03/use_case_grounded_lifecycle_scenarios.md)
- [Grid'5000 deployment guide](https://github.com/Paperpaperdog/Agent_Sandbox_Proposal/blob/0669cd459a7e5d38d582df73300b563dd1d74529/docs/grid5000-deployment-guide.md)
- [Related-work reading matrix](../weeks/week-03/benchmark_reading.md)

Keep architecture conclusions and benchmark results conditional on the actually reproduced versions and available Grid'5000 resources. This appendix documents plans and source hypotheses; it must not be cited as an empirical measurement.

## I. Additional reading archived from the former master

The concise master bibliography contains only the sources **directly cited** in its main narrative. The following 20 additional sources appeared in the pre-consolidation survey but are not currently cited by the master. They are retained here for literature review and future experimental justification; including a source in this reading list does **not** imply it was independently verified or establishes any benchmark result.

| Original citation key | Reference |
| --- | --- |
| `dsec` | [DeepSeek Elastic Compute (DSec): A Sandbox Infrastructure for Effective Agentic Training at Scale](https://arxiv.org/abs/2609.22978) |
| `tenonAgent` | [TenonAgent: Virtualizing Execution Residency for Memory-Oversubscribed LLM Agents](https://arxiv.org/abs/2611.00051) |
| `agentcgroup` | [AgentCgroup: Understanding and Controlling OS Resources of AI Agents](https://arxiv.org/abs/2602.09345) |
| `jetbrains2026` | [AI Coding Agents: Adoption Trends](https://blog.jetbrains.com/research/2026/08/ai-coding-agent-adoption-2026/) |
| `sumatosoft2026` | [Agentic AI in Production: Where Agents Run Unattended and Where They Get Pulled Back](https://sumatosoft.com/research/ai-agents-in-production) |
| `gkeSizing` | [Agents Are Sessions, Not Requests: Size GKE Node Pools for AI Agent Sessions](https://developers.googleblog.com/agents-are-sessions-not-requests-size-gke-node-pools-for-ai-agent-sessions/) |
| `shivanathd` | [Agent Substrate: A Field Test](https://github.com/shivanathd/agent-substrate-field-test) |
| `nirvanaLabs` | [Agent Sandbox Benchmark: Nirvana vs GKE vs E2B](https://nirvanalabs.io/benchmark-results/agent-sandbox) |
| `crossSandboxBlog` | [Testing Kubernetes Sandboxing Technologies](https://blog.csanchez.org/2026/06/23/testing-kubernetes-sandboxing-technologies/) |
| `cubeBenchmark` | [CubeSandbox Core Operations Performance Benchmark Report](https://docs.cubesandbox.com/blog/posts/2026-06-01-cubesandbox-perf-benchmark.html) |
| `sigBench` | [Agent Sandbox Benchmark Scenarios](https://github.com/kubernetes-sigs/agent-sandbox/tree/main/test/benchmarks) |
| `alibabaCloud` | [Alibaba Cloud Agent Sandbox: General Availability](https://www.alibabacloud.com/en/news/product/general-availability-ga-o7e) |
| `google3Layer` | [Sandboxing Untrusted AI Agents at Scale: Google Donates Agent Substrate and gVisor to the CNCF](https://opensource.googleblog.com/2026/11/sandboxing-untrusted-ai-agents-at-scale.html) |
| `northflank` | [Daytona vs E2B: AI Code Execution Sandboxes](https://northflank.com/blog/daytona-vs-e2b-ai-code-execution-sandboxes) |
| `gartner2025` | [Gartner Predicts Over 40% of Agentic AI Projects Will Be Canceled by End of 2027](https://www.gartner.com/en/newsroom/press-releases/2025-06-25-gartner-predicts-over-40-percent-of-agentic-ai-projects-will-be-canceled-by-end-of-2027) |
| `awsInterpreter` | [Resource and Session Management: Amazon Bedrock AgentCore](https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/code-interpreter-resource-session-management.html) |
| `modalArchitecture` | [Scaling to 1 Million Concurrent Sandboxes in Seconds](https://modal.com/blog/scaling-to-1-million-concurrent-sandboxes-in-seconds) |
| `azureDynamic` | [Dynamic Sessions in Azure Container Apps](https://learn.microsoft.com/en-us/azure/container-apps/sessions) |
| `vercelDocs` | [Vercel Sandbox](https://vercel.com/docs/sandbox) |
| `daytonaArchitecture` | [Daytona2: Agent Infrastructure Requires More Than Kubernetes](https://www.daytona.io/dotfiles/daytona2-agent-infrastructure-requires-more-than-kubernetes) |

For authors, access dates, full original citation formatting and historical context, consult [the pre-consolidation bibliography](https://github.com/Paperpaperdog/Agent_Sandbox_Proposal/blob/924501eca5448bc4dca263364cbdb7f9e6718d04/natalia.tex).
