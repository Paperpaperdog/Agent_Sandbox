# Week 4 — Benchmark Parameter Definitions, Units and Rationale

**Companion to:** [full master proposal](natalia.tex), [technical appendix](docs/proposal-technical-appendix.md), [evidence-to-scenario selection](evidence-to-scenarios.md).  
**Status:** proposed design, not an executed comparative benchmark. All parameter values are **synthetic or provisional** unless explicitly identified as a cited observation.

## 1. Unit conventions and parameter roles

| Notation / unit | Exact meaning | Important distinction |
| --- | --- | --- |
| `s`, `ms` | Seconds and milliseconds of elapsed wall time (1 s = 1,000 ms) | Time between client-observed, monotonic-clock events; not CPU time |
| `N` in B | Number of **offered independent trial requests** in a batch (trials) | Concurrent submission does **not** mean concurrent readiness/admission |
| `N` in C | Number of **persistent logical user identities** (users) | Not a physical machine count |
| `M` in C | Maximum **verified usable active execution slots** (slots) | Not automatically physical Kubernetes nodes, WarmPool spare Pods or active Pod replicas |
| `B` in C | Returning identities whose requests are submitted within a specified time window (requests) | A synchronized burst does not imply simultaneous completion |
| `R=N/M` | Logical identities per active slot; **dimensionless** ratio | Does not alone imply admission queueing |
| `vCPU` / `m` | One requested virtual CPU core (1 vCPU = Kubernetes `1000m`) | Resource request/limit, not measured CPU utilization |
| `GiB` | Binary memory/storage: 1 GiB = 1,073,741,824 bytes | Do not label 4 GiB as exactly 4 decimal GB |
| `GB`, `MB` | Decimal sizes: 1 GB = 10^9 bytes; 1 MB = 10^6 bytes | Freeze MB versus MiB in the workload generator |
| `tasks/s`, `trials/s` | Correctly completed verified outcomes per second | Different from attempted request arrival rate or Pod Ready count |
| `core-s` | CPU use integrated over time (CPU core-seconds) | 2 fully utilized cores for 10 s = 20 core-s |
| `GiB-s` | Memory occupied over time | 2 GiB for 120 s = 240 GiB-s |
| `P50 / P95 / P99` | 50th/95th/99th percentile of **completed** latency samples | Report sample count; timeouts remain separate failures |

Every run must log the concrete Kubernetes **requests and limits**, image digests, preparation/caching, topology, namespace, load driver location, actual idle policy/TTL, cleanup settings and available hardware. A resource budget is a **controlled input**; CPU or memory cost is a **measurement**.

## 2. Scenario A — Coding-agent continuation (primary)

**Deterministic task contract:** Acquire a pinned workspace → first patch/virtual environment/test → no driver commands during a review gap → second patch/test on the same logical task → validate files/dependencies/tests → release and verify reclamation.

| Parameter | Proposed setting and unit | Why it was chosen / required validation |
| --- | --- | --- |
| Turns per task | **2 application execution turns** | Minimum nontrivial same-task follow-up: state exists before the gap and is required afterward |
| Review gap | **120 s** without new driver commands | Short synthetic gap permits repeatable Pilot testing; does **not** represent a measured developer return distribution |
| Gap sensitivity | **600 s** optional | Probe whether longer inactivity crosses a native timeout; do not assume that it triggers any eviction |
| Primary concurrency | **10 independent logical sessions** | A functional/multisession Pilot target, not a verified hardware-supported admission level |
| Additional concurrency | **50 / 200 sessions**, capacity-gated | Explore different contention levels only if admission and allocatable resources support them |
| Per-sandbox CPU | **2 vCPU** requested | Provisional coding/test compute budget; calibrate under the fixed command script |
| Per-sandbox memory | **4 GiB** requested | Provisional bound for dependencies, tests and workspace; verify peak memory and OOM rates |
| Per-sandbox disk | **10 GiB** planned | Space for source, packages and test outputs; define if this is PVC, ephemeral storage or backend quota |
| Workspace state | **~50–200 MB** tentative | Before task/image freezing, only an indicative size; log actual compressed/uncompressed bytes and cache conditions |
| Repetitions | **5 independent runs** when feasible (at least **3** if constrained) | Detect variability and unstable failures, without claiming that 3–5 runs alone establish tail-latency confidence |

**Measured boundaries (time in ms or s):**
- Initial access: `L_first = time(first verified command) - time(application acquisition request)`.
- Follow-up: `L_return = time(verified command after return) - time(return request)`.
- The **120 s idle period is excluded from `L_return`**. Record its actual start/end separately.
- Preserve test exit codes, SHA-256 of expected files, dependency state and correct combined patch after the second turn. State loss is an application correctness failure.

**Why not set the gap to 243 s?** [Liu et al. (2026)](https://arxiv.org/abs/2608.00101) report a **243 s median cross-turn *container resource-idle interval*** for their study. That observed quantity is neither a universal human review duration nor a platform eviction threshold. We choose 120 s for feasibility, then can derive sensitivity gaps from an analyzed trace distribution.

**Capacity warning:** 10 simultaneous sandboxes with 2 vCPU / 4 GiB each request **20 vCPU and 40 GiB** before platform overhead. The current example Worker VM reserves only 8 vCPU / 16 GiB; a 10-sandbox A cell at those limits is **not provisionable without changing capacity/settings**. A 200-sandbox cell at that budget would request **400 vCPU and 800 GiB** before infrastructure overhead. Never report hardware-unschedulable cells as architectural throughput results.

## 3. Scenario B — Parallel agent evaluation (primary)

**Task contract:** Submit N independent trials → acquire isolated environments → run **3–5 pinned commands per trial** → oracle-check outputs/files/exit codes → release independently → verify logical and physical cleanup. Each trial has no cross-trial state requirement.

| Parameter | Proposed setting and unit | Rationale / limitation |
| --- | --- | --- |
| Pilot batches | **N=10 / 25 trials** | First validate request/verification timestamps, error accounting and per-trial cleanup |
| First comparative burst | **N=50 simultaneous request submissions** if pilot passes | Initial controlled burst; not 50 guaranteed ready/active environments |
| Subsequent levels | **N=100 / 200**, then higher if feasible | Bracket a degradation *interval* while respecting admission and hardware constraints |
| Exploratory ceiling | **N=1,000** optional | A maximum design exploration target, not required and not a promise of one-reservation feasibility |
| Task sequence | **3–5 commands per trial** | Include actual multi-step execution instead of a single empty/startup command |
| Active task target | **~30–60 s per trial**, provisional | Freeze deterministic task/image first; actual CPU/network/IO times must be measured |
| Resources per trial | **1 vCPU / 2 GiB** | Starting request budget for relatively short tasks; adjust if pilot shows systematic task failures |
| Task deadline | **300 s (5 min)** optional, only if fixed in protocol | Bound unsuccessful trials and prevent endless waiting; timeout is a failure, not a completed latency |
| Replication | **5 independent batches per relevant level** when feasible | Check boundary stability; record all offered, failed, timed-out and successful trials |

**Optional task heterogeneity (shares of total trials, not CPU percentages):**

| Trial category | Planned share | Example bounded operation |
| --- | --- | --- |
| I/O + network | **40% of trials** | Fetch or install pinned dependencies from a controlled mirror |
| Network + filesystem | **30% of trials** | Clone/read/search a pinned local repository |
| CPU-intensive | **20% of trials** | Compile or run deterministic tests |
| Minimal | **10% of trials** | Small health-check or fixed shell command |

For N=50, these shares amount to **20/15/10/5 trials**, respectively. These proportions are **synthetic**, not a measured production workload distribution. If a batch is not divisible by ten, fix a deterministic rounding rule and report exact counts.

### Screening versus validated tail degradation

For a declared burst N, first use **two exploratory screening conditions**:
- **Correct completion fraction:** `verified_successes / all_offered_trials >= 0.95`. Unit: dimensionless fraction (95%).
- **Median first-verified-command latency:** `median(L_first at N) / median(L_first at low load) <= 2.0`. Unit: dimensionless slowdown.

The **95%** and **2×** levels are **research-chosen thresholds**, **not** industry SLOs. Report the last passing and first failing levels and repeat them; if no valid boundary is seen, report a one-sided/unresolved range.

Only with **at least 100 verified first-command observations** in **both** low-load and tested-load cells across predeclared repetitions should the experiment present a **separate descriptive P95 tail-degradation criterion** (P95 at N no more than 2× reference P95). The 100 count is a pragmatic reporting gate, not guaranteed precision. A P95 boundary with inadequate samples is **undetermined**, not success. P99 is optional with a much larger sample (e.g. about 1,000 verified completions).

**Secondary sustained offered rate:** First find a feasible `R0` in **offered trials/s**, then hold the same task mix and preparation fixed for equally timed tests at `R0/2`, `R0` and `2*R0`. This tests sustained churn separately from synchronized bursts; a short rate sweep does not reveal an exact global saturation point.

**Capacity warning:** N=50 trials at 1 vCPU / 2 GiB each *simultaneously reserved* require **50 vCPU / 100 GiB**, excluding system and controller overhead. The actual comparison must be limited by a verified common cluster topology and report rejected/pending requests.

## 4. Scenario C — Persistent multi-user agents (optional Phase 2)

**Main contract (C1, native idle policy):** Give each user a private logical identity, a distinct SQLite DB and files; issue a first request; stop sending commands during the idle gap; let **the platform's native policy** retain/pause/reclaim/wake/recreate; issue the next request and verify the same user's persisted state. Do this again for a third request.

| Parameter | Proposed setting and unit | Meaning / justification |
| --- | --- | --- |
| Persistent users, `N` | **20 logical identities (users)** | Small independent state/identity workload; not necessarily 20 concurrently runnable workers |
| Target execution capacity, `M` | **5 *verified usable active execution slots*** | Deliberate resource-sharing constraint; must be enforced/observed, not inferred from WarmPool size |
| Oversubscription ratio, `R=N/M` | **4:1, dimensionless** | Compare persistent identities with active execution capacity; does **not** imply 15 requests are queued |
| Requests per identity | **3 separate application interactions** | Two returns after prior state has been written |
| Idle gaps per identity | **2 × 300 s** | Synthetic 5-minute gaps between verified commands and the next requests |
| Initial stagger | **nominal 10 s between initial requests** | Avoid artificially synchronizing every user's first execution; record actual arrivals |
| Secondary wake batch `B` | **5 / 10 / 20 returning requests** | Deliberate burst stress, with `B <= N` |
| Wake submission window | **approximately 1 s** | A controlled stress input; report actual per-request submission timestamps |
| Private state | **~1 MB SQLite DB + 2 text files per identity** | Independently verify state continuity and cross-user isolation; freeze exact bytes/unit in generator |
| Optional sensitivity | Gap **60 / 600 s**; user/slot N/M **50/10** or **100/20** | Only after verified capacity and successful Tier 1 behavior |
| Mechanism test `C2` | Explicit suspend/resume, **optional** | Separate from C1; do not silently compare C2 costs to platforms that never suspended |

For staggered **C1** the next user request is scheduled **300 s after that user's preceding verified command**. Native transitions and actual measured gaps are logged. The alternate burst mode submits B returning requests within the declared window. The ratio `20 / 5 = 4` **does not guarantee queue depth 15**: 15 users may simply be idle; only measured overlapping demand and observed admission support a queueing statement.

**M is not a Kubernetes physical-node count** and not equivalent to five WarmPool spare Pods. Measure usable admission slots for each architecture before claiming equal constraint. A provisional active environment budget of 2 vCPU / 4 GiB would make five active slots request 10 vCPU / 20 GiB, already larger than the example single Worker VM; choose a feasible verified resource cell.

**Return latency** is measured from a returning user's request to the **first independently verified command** with the correct private state. The 300 s idle period itself is not part of this latency. A SQLite file surviving a restart is **Tier 1 state continuity**; it does **not** verify Tier 2 live process/memory restoration.

## 5. Shared metrics — equations and reporting units

| Metric group | Definition / unit | Counting rule |
| --- | --- | --- |
| **Lifecycle latency** | Initial, follow-up, command and logical cleanup durations (ms or s) | Client monotonic request timestamp to independently verified event; do not end at Pod Ready |
| **Verified throughput** | Number of correct outcomes / observation duration (verified trials/s or tasks/s) | Use fixed offered-work window; exclude failed outcomes from numerator, preserve them in the denominator of success rate |
| **Reliability/correctness** | `success / offered` (%), counts of failures, timeouts, incomplete attempts | State continuity and isolation checked by independent oracles |
| **Kubernetes/control-plane cost** | API CREATE/UPDATE/PATCH/DELETE writes (count), management CPU core-s; optionally each **per verified success** | Publish raw totals and denominator; if zero successes, per-success ratio is undefined |
| **Runtime/resource efficiency** | CPU core-s; memory GiB-s; occupancy; active/idle split | Integrate actual usage; report reserved/claimed capacity separately, never add CPU core-s to memory GiB-s |

**Timing boundaries:** Record application request, identity assignment, readiness, first verified command, each follow-up request, final oracle, logical release and physical reclamation as distinct timestamps. Internal queue depth is a diagnostic only when directly instrumented; counting outstanding client requests is **not** a measure of internal queue length.

**Sample-size discipline:** With **fewer than 100 verified completions**, give raw or sorted per-run values, median, range, counts, failures and timeouts, not a purportedly stable P95/P99. With 100+ verified completions P95 may be reported descriptively with count and between-run variation. P99 is optional only at much larger samples (e.g. 1,000+). These cutoffs are **pragmatic reporting rules**, not statistical confidence guarantees.

**Default and tuned platform policy:** Log the actual TTL, idle sweeper, warm budget, cleanup grace and native state transition; default and explicitly tuned policy runs are **separate experimental cells**. Unsupported mechanisms are N/A; installer failures are feasibility outcomes, not performance observations.

## 6. Grid'5000 feasibility and next actions

The current deployment script's [`00-config.toml`](../deploy-k8s-g5k/00-config.toml) reserves **one physical server** hosting an **8-vCPU/16-GiB control-plane VM and one 8-vCPU/16-GiB worker VM** for a default three-hour period. That is a **small PoC**, not the proposed final one-control-plane + two homogeneous-worker experimental topology. Actual allocatable worker resources are **less** than the VM totals once Kubernetes and other Pods are accounted for.

Before the first comparable experiment: pin Kubernetes/runtime platform commits; verify all task images and state contracts; choose schedulable resource cells; test no-load and a small known load; verify worker image pulls, persistent data, API counters, CPU/memory series and complete failure logs; repeat comparable conditions; then increase N only subject to observed headroom.

**Scientific rationale:** The external sources justify **which lifecycle behaviors matter**. The concrete values (120 s, 300 s, 50 trials, 20 users/5 slots) are **controlled experimental inputs** and must be calibrated and sensitivity-tested—not passed off as industry defaults.
