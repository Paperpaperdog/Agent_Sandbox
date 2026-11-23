# Benchmark reading, evidence and research positioning

**Purpose:** answer “what has already been evaluated?” before claiming novelty. The work below is a prioritized reading plan with boundaries, not a claim that all papers have been replicated or fully audited.

## 1. Prioritized core reading

| Priority | Source and evidence type | Already studied / reusable insight | What our design must do differently |
| --- | --- | --- | --- |
| **P0** | [Sandman — Amazon agentic RL sandboxes](https://arxiv.org/abs/2610.39711), 2026 research preprint | Production Kubernetes Pod sandboxes; repeated tool calls; creation bursts, readiness, warm capacity, cleanup and operational scale | Avoid repeating only a Pod-create benchmark; evaluate cross-architecture **task-complete** behavior and where costs move |
| **P0** | [Kubernetes SIGs Agent Sandbox performance tuning](https://github.com/kubernetes-sigs/agent-sandbox/blob/main/docs/performance-tuning.md), official engineering results | Warm claims, burst vs sustained arrival, controller workers/refill, 409 conflicts and API writes; tuning can help bursts while worsening sustained latency | Reproduce comparable boundaries with pinned versions; distinguish warm claim from cold Pod; account for specialized CP |
| **P1** | [ARIES paper](https://arxiv.org/abs/2607.29069) + [ARIES framework](https://github.com/hyscale-lab/ARIES), research + code/traces | Agent trajectories and tool/harness/model attribution, idle/resource patterns and state-management implications | Reuse workload concepts without treating engine/harness logs as full sandbox lifecycle traces; measure native state contracts |
| **P1** | [Hermes agents-as-a-service example](https://agent-sandbox.sigs.k8s.io/docs/use-cases/examples/hermes-agents-as-a-service/), official documented application | Per-user warm claims; idle sweeper; wake-on-request; PVC-backed file continuity after Pod recreation | Use it as concrete user-case evidence; **do not** equate its volume-backed wake with process-memory snapshot restore |
| **P1** | [FrigaZzz agent-sandbox-benchmark](https://github.com/FrigaZzz/agent-sandbox-benchmark), public benchmark code | Provider API/tool correctness, code/file tasks, failure accounting and external latency | Borrow independent correctness checks; hosted provider timings are not matched Grid'5000 architecture measurements |
| **P2** | [DeltaBox](https://arxiv.org/abs/2605.22781), 2026 research preprint | Sandbox checkpoint, rollback, cloning, snapshot storage and agent workloads | Separate snapshot mechanism from lifecycle orchestration; check state fidelity and byte/I/O accounting |
| **P2** | [Fast Sandbox performance](https://github.com/opensandbox-group/OpenSandbox/blob/main/docs/architecture/fast-sandbox/performance.md), official engineering report | FastPath/Fastlet/Firecracker creation and pause/resume under prepared template/cache prerequisites | Record the same cache/snapshot preconditions and internal CP work instead of reusing headline numbers |
| **P2** | [ComputeSDK benchmarks](https://github.com/computesdk/benchmarks), public benchmark code | Request-to-first-command and real build tasks across hosted providers | Borrow consistent readiness boundaries, not hosted-cloud ranking |

Source links should be revisited at a pinned commit/release before the experiment. Distinguish papers, vendor/maintainer documentation, open benchmarks and independently measured results when writing the related-work section.

## 2. Three authentic workload anchors

### Interactive coding and task continuation

[Codex Cloud documentation](https://help.openai.com/en/articles/20001545-using-codex-cloud) explicitly describes isolated coding task workspaces, testing and continuing a task after review. This anchors the **user and tool workflow**, not infrastructure-specific state restoration. [SWE-agent](https://github.com/SWE-agent/SWE-agent) is a separate open workflow that can help construct reproducible tool trajectories.

**Reading questions:** What is a task vs a new workspace? Which file changes should persist? What fraction of gaps correspond to model inference versus a human wait? Can we capture timestamps from an open harness rather than invent them?

### Parallel agentic RL / evaluation

[Sandman](https://arxiv.org/abs/2610.39711) documents a concrete production need for isolated task images, multiple calls per sandbox and frequent creation/cleanup. Its abstract reports four October 2026 production SWE-bench Verified campaigns creating **3.1 million sandboxes**; this is evidence of real creation demand, **not** a workload trace that can be replayed unchanged.

**Reading questions:** Which phases dominate task time? How are image pulls, warm pools and abandoned Pods handled? What is reported as a production observation versus stress-test maximum? Are task types and burst distributions accessible?

### Multi-user persistent agents

The official [Hermes AaaS walkthrough](https://agent-sandbox.sigs.k8s.io/docs/use-cases/examples/hermes-agents-as-a-service/) is the closest documented application of explicit inactivity and wake-on-request to our proposed lifecycle policy experiment. Its suspend mechanism preserves **PVC-backed files**, not a running process image.

**Reading questions:** What triggers the idle sweeper? Which resources are released? What does a returning user actually wait for? How do warm acquisition, waking and deleting an account differ?

## 3. Already evaluated vs. remaining comparative question

**Already well explored in specific configurations:**
- Cold and warm creation latency, claim adoption and Pod scheduling under bursts.
- Engineering tuning for controller API writes/409 conflicts and warm-pool replenishment.
- Snapshot/checkpoint and rollback performance within particular runtimes.
- Agent tool execution correctness and first-command latency for various hosted providers.
- Production and experimental evidence that agent tool workloads contain active/idle intervals.

**Still worth testing — hypothesis, not a first-ever claim:**

> Under the same declared agent task, event schedule, state contract and reserved hardware, how do Pod-per-session control, actor/worker reuse and multi-instance workers distribute lifecycle work across Kubernetes, specialized control services, runtimes and storage? How does that distribution alter latency, successful throughput, resource efficiency and failures as user behavior changes?

This statement must be narrowed if an existing work already provides a matched cross-architecture, same-hardware implementation with equivalent state semantics. Explicitly track what each comparison holds constant and what is confounded (runtime, storage, prewarming and cache).

## 4. Research contributions to test (not yet findings)

1. **Workload-backed benchmark specification:** reproducible coding continuation and batched RL/evaluation proxy tasks, with provenance for observed vs synthetic parameters.
2. **State-contract taxonomy:** universal execution, filesystem continuity and process/memory restoration, tested rather than inferred from API names.
3. **Cross-layer attribution:** client, Kubernetes API/etcd/controller, specialized platform services, worker/microVM runtime and storage.
4. **Architecture–workload trade-off curves:** report conditions under which warm capacity, scheduling, checkpoint I/O and worker admission become limiting factors, without presuming a winner.

A paper is not justified by adding more systems alone. The mechanism explanations, reproducible contracts and realistic input patterns must provide insight beyond a leaderboard.

## 5. Focused paper-reading checklist

For each core paper, capture in notes:

- Study type and status: peer-reviewed, preprint, official benchmark or engineering blog.
- Application-level source of the workload (production trace, recorded tasks, synthetic generator).
- Systems, architecture, runtime/isolation and host configuration.
- Task / session / lifecycle definition and readiness boundary.
- Arrival process, concurrency, active/idle duration and warm/cold cache state.
- State guarantee: files, workflow checkpoint, or live process/memory.
- Measured latency percentiles, successful throughput, error classes, CPU/memory/storage cost.
- Instrumentation depth: Kubernetes control plane, internal CP, runtime and storage.
- Reproducibility: scripts, images, traces, configs, code revision, public data.
- Exact overlap with our A/B/C use cases, E1/E2/E3 and testable claims.

Before claiming experimental novelty, fill this matrix with page/section pointers and direct quotes or paraphrased evidence; do not promote a preliminary literature impression to a confirmed gap.

## 6. Immediate reading assignment suggestion

**Scenario/evidence workstream:** Sandman and ARIES first, then coding-agent trajectories and Hermes. Produce a **Use Case → Source Evidence → Trace Events → Synthetic Assumptions** matrix.

**Systems/benchmarks workstream:** SIGs performance tuning and official benchmark configs, Fast Sandbox performance and candidate architecture docs, then FrigaZzz/ComputeSDK. Produce a **System → Native Lifecycle Semantics → Observability → Reproduction Requirements** matrix.

Both workstreams jointly approve the [common benchmark event and correctness contract](https://github.com/Paperpaperdog/Agent_Sandbox_Proposal/blob/0669cd459a7e5d38d582df73300b563dd1d74529/weeks/week-03/scenario_and_benchmark_protocol.md) before running scale experiments.
