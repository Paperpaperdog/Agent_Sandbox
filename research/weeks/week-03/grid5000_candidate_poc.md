# Grid'5000 deployment and candidate PoC plan

**Study scope updated 15 November 2026:** only Kubernetes-managed sandbox architectures. Five systems remain; Firecracker in Kubernetes-managed Fastlet workers remains eligible.

**Status as of 12 November 2026:** planning document. No successful Grid'5000 deployment, microVM readiness, or candidate performance result is established by the artifacts currently recorded in this repository.

## 1. Purpose and deployment sequence

The immediate objective is not a peak-throughput graph. It is to establish a **repeatable, observable execution environment** and confirm the **actual lifecycle semantics** of candidate systems.

**Stages:**
1. Verify access to a Grid'5000 site frontend and permissions for a reservation.
2. Reserve a small number of suitable bare-metal nodes and record exact node identifiers, site/cluster, CPU, RAM, disk and network.
3. Validate OS/kernel, cgroup v2, networking, storage, and **KVM/TUN only where needed**.
4. Deploy a simple Kubernetes cluster; verify CNI and persistent-volume provisioning before stateful experiments.
5. Install Prometheus/exporters and capture control-plane telemetry with a no-load baseline.
6. Run the native Pod smoke test. Only then try SIGs Agent Sandbox.
7. Attempt other architectures **only after** feature prerequisites and expected isolation/runtime mode are understood.
8. Save logs/manifests, fill the PoC record, then shortlist eligible Kubernetes-based architectures for the use-case-grounded lifecycle study.

**Proposed pilot topology:** one control-plane node plus two homogeneous worker nodes. Start with one node for OS capability checks. Use fixed node placement and a fixed workload budget for matched experiments; dedicated monitoring/client placement should be documented. The final topology depends on Grid'5000 node availability.

## 2. Grid'5000 operational notes (do not execute outside an authorized job)

Official guides:
- [Grid'5000 Getting Started](https://www.grid5000.fr/w/Getting_Started) — OAR reservations and Kadeploy.
- [Grid'5000 documentation](https://www.grid5000.fr/w/Grid5000:Home) — sites, node capabilities, networking and deployment information.

**Illustrative frontend sequence only:** the exact site and available deployment image must be checked first.

    # On an authorized Grid'5000 site frontend
    oarsub -I -t deploy -l "nodes=1,walltime=1:45"

    # After a deploy-type reservation is active, and only for reserved nodes:
    kadeploy3 debian13-min

Kadeploy **reimages the reserved machine**. Do not run it on nodes containing unbacked-up work or without the correct reservation. Cluster bootstrapping, network rules and storage classes are site/configuration specific; do not treat a one-line sample as a complete Kubernetes deployment script.

### Safe per-node preflight checks

Record outputs and errors alongside the reservation ID:

    uname -a
    lscpu
    free -h
    df -Th
    findmnt -no FSTYPE,OPTIONS /
    stat -fc %T /sys/fs/cgroup
    test -c /dev/kvm && echo KVM-device-present || echo KVM-device-absent
    test -c /dev/net/tun && echo TUN-device-present || echo TUN-device-absent
    lsmod | grep -E '(^kvm|^tun)' || true
    command -v kubectl || true

A visible /dev/kvm **does not prove** that the user/process running Firecracker has permission to use it. A successful microVM create/exec/destroy probe is needed. For Fast Sandbox, also verify cgroup v2 configuration, a compatible kernel/networking setup and required snapshot/reflink storage. Do not infer XFS reflink support just from the filesystem name.

**Baseline telemetry:** API-server request rates/durations; scheduler and controller queues; etcd metrics (including histogram semantics); node/cgroup CPU/memory; pod lifecycle events; platform-specific logs/metrics; available storage I/O. Audit logging should be selectively configured to avoid perturbing the benchmark.

## 3. Candidate priority and native capability gates

| Candidate | Architecture and core question | First PoC / gate | Proposed priority |
| --- | --- | --- | --- |
| **Native Kubernetes Pod** | Direct Pod scheduling. What is the baseline cost for create/exec/delete? | Create Pod, execute verifiable command, write file, delete and confirm cleanup; optional PVC recreation as a **separate** test | P0 |
| **SIGs Agent Sandbox** | Sandbox controller, SandboxClaim and WarmPool. What does each operation do in Kubernetes? | Pin release; install CRDs/controller; cold Sandbox, warm claim, first exec, PVC-backed Suspended/Running; record refill and files | P0 |
| **OpenSandbox BatchSandbox** | Kubernetes Pod backend via OpenSandbox API. Does it add a useful distinct control path? | Deploy API/backend; run common contract; verify actual pause/PVC support, not presumed feature parity | P2 |
| **OpenSandbox + Fast Sandbox** | FastPath/Fastlet and multiple Firecracker guests per worker. Does specialized admission change the bottleneck? | Check KVM, TUN, cgroup v2, snapshot/reflink prerequisites; run template-backed VM start and verified exec; test pause/resume if supported | P1 |
| **Agent Substrate** | Actor identities, ready WorkerPool slots, and checkpoint/restore. Is worker reuse practical on the testbed? | Deploy actor CP, storage and worker components; create/activate actor, exec, checkpoint, resume, verify process/file fidelity | P1 |

**Priority is a recommendation, not an observed compatibility verdict.** Five Kubernetes-based candidates remain. OpenSandbox Batch and OpenSandbox + Fast Sandbox are distinct execution backends; the latter stays in scope because Kubernetes manages Fastlet worker capacity even when individual guests are Firecracker microVMs.

Key source material: [SIGs Agent Sandbox](https://github.com/kubernetes-sigs/agent-sandbox), [SIGs performance tuning](https://github.com/kubernetes-sigs/agent-sandbox/blob/main/docs/performance-tuning.md), [OpenSandbox](https://github.com/opensandbox-group/OpenSandbox), [Fast Sandbox](https://github.com/opensandbox-group/fast-sandbox), [Agent Substrate architecture](https://github.com/agent-substrate/substrate/blob/main/docs/architecture.md).

## 4. Minimal PoC contract for every candidate

Use the same small deterministic image/task where compatible. Record **native** capabilities, not similarly named API calls:

| Check | Required evidence | Pass condition |
| --- | --- | --- |
| Installation | Exact release/commit, Kubernetes version, manifest/command, errors | Platform API/driver responds |
| Cold create + first exec | Client timestamps, platform ID, stdout/exit code | First command succeeds and output is independently verified |
| Repeated exec + file state | Same logical sandbox ID, file digest, command result | File survives between commands |
| Idle handling | Actual observed resource state and documented API | Keep-alive is distinct from pause; no unsupported claim |
| Suspend/recreate/restore | State-transition logs; file marker; optional process-memory counter | Appropriate Tier 1 or Tier 2 contract proven |
| Delete and reclaim | API deletion and underlying Pod/guest/storage check | Resources reclaimed according to declared retention policy |
| Telemetry | Driver events, API write counter, verified control-plane/worker CPU and memory sources; optional platform metrics | Demonstrate a no-load and a small known-load sample before claiming metric availability |

**Failure taxonomy:** permission/host precondition, install/configuration, create failure, first-command timeout, incorrect output, state loss, checkpoint incomplete, restore failure, cleanup leak, unknown. Keep raw errors and timestamps.

### PoC result record — fill this after a real run

| Field | Record |
| --- | --- |
| Date / operator / site | **Not yet recorded** |
| Reservation ID / node IDs / hardware | **Not yet recorded** |
| Git revision / manifest / runtime | **Not yet recorded** |
| Candidate and version | **Not yet recorded** |
| Create / first exec / repeated exec | **Not yet recorded** |
| File and process state tests | **Not yet recorded** |
| Delete / residual resources | **Not yet recorded** |
| Metrics / logs / artifacts | **Not yet recorded** |
| Failure, workaround and next action | **Not yet recorded** |

Avoid overwriting “Not yet recorded” with guesses or numbers from published vendor benchmarks. Store a dated per-system run log and link it here after execution.

## 5. Shortlist decision rules

Retain **Native Pod** as the control whenever possible. Select only Kubernetes-managed candidates according to:

1. **Semantic eligibility:** shared command + file contract works; native pause semantics are explicitly verified.
2. **Architecture distinction:** different path for lifecycle orchestration, not just another API wrapper for the same Pod operation.
3. **Grid'5000 feasibility:** host support, image/network/storage requirements and repeatable deployment.
4. **Observability:** ability to attribute cost to Kubernetes and any specialized actor/worker/Fastlet control path.
5. **Time cost:** can we implement a reliable adapter and repeat experiments within the project window?

A two-stratum design is defensible: compare all feasible systems on Tier 0 common operations, then compare native stateful systems on Tier 1/2 separately. A non-deployable candidate should be documented as **infeasible on tested hardware/configuration**, not declared universally inferior.

## 6. Week 3 target evidence

- One saved Grid'5000 environment inventory and clear reservation/deployment instructions.
- Repeatable native Kubernetes baseline smoke test and SIGs Sandbox smoke test, if access permits.
- KVM/TUN/cgroup/filesystem report to make a reasoned Fast Sandbox decision.
- At least one attempted contrasting runtime/architecture with complete error logs, even if unsuccessful.
- A candidate matrix with **observed** status: untried, in progress, passed, blocked or out of scope.

**Metric readiness gate:** Save the exact Prometheus/OTel query or exporter source, series type and labels, scraping resolution, sample counts, and an example idle-vs-load comparison. Label missing specialized telemetry N/A; do not infer sub-second peak queue depth from a slow scrape.

**No claim of a completed deployment is made in this document.**
