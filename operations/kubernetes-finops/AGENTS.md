<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-07-04 | Updated: 2026-07-04 -->

# kubernetes-finops

## Purpose
Skill for **FinOps on Kubernetes** — allocating, understanding, and optimizing the cost
of running containerized workloads on **any** cluster (EKS / AKS / GKE / on-prem),
**vendor-neutral**. Owns the operating doctrine + the container cost model: a shared
cluster is one cloud bill hiding many tenants, and clusters run at ~20–30% utilization
because pod **requests** are set far above usage. Covers the **allocated / idle / shared**
cost split (allocate on `max(request, usage)` — the FinOps Foundation "calculating
container costs" model), cost allocation via **OpenCost** (CNCF) / **Kubecost**,
right-sizing (requests vs limits, QoS, VPA/Goldilocks/KRR), autoscaling + node efficiency
(HPA/VPA/KEDA + bin-packing + Spot), waste elimination, and cost governance
(ResourceQuota/LimitRange + admission policy). Fifth skill in the `operations/` domain;
the **cost lens** counterpart to `kubernetes-operations` (operate) and `karpenter-operations`
(node lifecycle).

## Key Files
| File | Description |
|------|-------------|
| `SKILL.md` | The skill — `name: kubernetes-finops`, `domain: operations`, `platform: kubernetes`, `scope: cross-cloud`, `discipline: finops`, `framework: finops-framework, calculating-container-costs`, `spec: FOCUS` |

## Subdirectories
| Directory | Purpose |
|-----------|---------|
| `tools/` | 3 read-only `kubectl` cost-triage scripts (`k8s-cost-allocation.sh`, `k8s-rightsizing-scan.sh`, `k8s-idle-waste.sh`); read-only is a hard invariant, `kubectl top` needs metrics-server (see `tools/AGENTS.md`) |

## For AI Agents

### Working In This Directory
- Edit `SKILL.md` (and the read-only `tools/` scripts). Almost every change is authoring.
- **The doctrine is the spine, in order:** *allocate before you optimize* (labels +
  OpenCost) → **requests are the currency** (cost follows requests, not usage;
  over-requesting is the #1 waste) → *kill idle before you buy rate* (fix utilization,
  then commit — the buy itself is the cloud FinOps skill's job) → *two levers* (workload
  efficiency vs node efficiency) → *idle is a cluster KPI, not a tenant tax* → *every
  scale-down is a safety decision* (PDB/QoS-aware, gated) → *guardrails not cleanup*
  (admission-time quotas/policy). Keep those invariants intact on edits.
- **The container cost split is load-bearing:** `node cost = Σ allocated(max(request,usage))
  + idle(unrequested capacity) + shared(kube-system/overhead)`. Don't blur allocated vs
  idle, and don't charge tenants for idle.
- **Version discipline:** OpenCost/Kubecost, VPA, KEDA, the descheduler, and NAP move fast.
  **State behavior, pin NO version, and frame the Allocation API / VPA modes / KEDA scalers
  / node-autoscaler flags as "verify against opencost.io, kubernetes.io, keda.sh,
  finops.org".** Same no-version-pin doctrine as the sibling `operations/` skills.
- Keep the **scope boundary** sharp:
  - **Cloud-account FinOps** (subscription/billing, **reservations vs savings plans**, tag
    hierarchy, the cloud bill) → `../../platform-engineering/azure-finops/`. This skill
    sizes the node commitment and hands the *purchase* there.
  - **Node-lifecycle autoscaler internals** (`NodePool` / `NodeClass` / consolidation /
    NAP) → `../karpenter-operations/`. This skill decides *how much* capacity + spot-vs-
    on-demand; Karpenter/NAP decides *which VM*.
  - **Generic cluster ops** (scheduling, HPA/VPA *mechanics*, capacity, upgrades) →
    `../kubernetes-operations/` (`k8s-autoscaling-engineer` / `k8s-cluster-operator`).
  - **Agentic MCP tool-belt + blast-radius doctrine** → `../agentic-k8s-ops/`.
- Highest-value facts to keep correct: allocate on **`max(request, usage)`**; **requests <
  limits** (Burstable) for most apps, `requests == limits` only for critical (Guaranteed);
  clusters run ~20–30% utilized (right-size requests to **p95/p99**); **KEDA scale-to-zero**
  is the fix for non-prod running 24/7; **Spot** ~90% off for interruptible; never fight
  **HPA and VPA on the same metric**.
- The `description:` uses a `>-` block scalar (colon/backtick-dense) — keep it and
  re-verify `yq '.description | type'` is `!!str` after edits.

### Testing Requirements
- **`scripts/validate-skills.sh` validates this directory** (`operations/` is in
  `DOMAIN_DIRS`): frontmatter (`name`/`description`/`license`/`compatibility`, non-empty
  `metadata` map), non-empty body, even fence count. Run it after edits.
- `tools/` is **not** validator-covered — verify by hand (`bash -n`, the mutating-`kubectl`-verb
  grep, executable bit) per `tools/AGENTS.md`.

### Companion Subagents
- Ships a **5-agent Kubernetes FinOps team** in `../../.claude/agents/` (vendor-neutral):
  `k8s-cost-allocator` (Allocate — OpenCost/Kubecost, labels + namespaces, the
  allocated/idle/shared split, showback→chargeback — owns `tools/k8s-cost-allocation.sh`),
  `k8s-rightsizer` (Right-size — requests vs limits vs usage, QoS, p95/p99, VPA/Goldilocks/
  KRR — owns `tools/k8s-rightsizing-scan.sh`), `k8s-cost-autoscaler` (Scale & pack —
  HPA/VPA/KEDA scale-to-zero, bin-packing, Spot/Arm64/SKU, node-capacity decision),
  `k8s-waste-hunter` (Eliminate — idle nodes, unused PVCs/PVs, zombie workloads,
  completed Jobs — owns `tools/k8s-idle-waste.sh`), `k8s-cost-governor` (Govern —
  ResourceQuota/LimitRange, require-requests/labels admission policy, budgets, chargeback,
  maturity). The SKILL's "Subagent Orchestration" table maps capability → agent; update
  both on rename.

### Common Patterns
- Intro + the container cost-split diagram → CORE PRINCIPLES → CAPABILITY MAP → phases
  A–E (Allocate / Right-size / Scale & pack / Eliminate / Govern) → anti-patterns →
  checklist → reference → MCP surface → subagent orchestration. Same authoring shape as
  the sibling operations skills.

## Dependencies

### Internal
- `../../scripts/validate-skills.sh` — enforces the SKILL.md contract.
- `../../README.md` — references this skill in the "Operations" table; rename → README update.
- `../../.claude/agents/k8s-cost-*.md` / `k8s-rightsizer.md` / `k8s-waste-hunter.md` — the
  5 companion subagents.
- `../karpenter-operations/SKILL.md` (node lifecycle), `../kubernetes-operations/SKILL.md`
  (generic autoscaling/capacity), `../agentic-k8s-ops/SKILL.md` (agentic blast-radius),
  `../../platform-engineering/azure-finops/SKILL.md` (the cloud-bill FinOps sibling) —
  cross-referenced to keep boundaries sharp.

### External
None at runtime — documentation. Describes Kubernetes FinOps; cites `opencost.io`,
`kubernetes.io`, `keda.sh`, and `finops.org` (calculating container costs). `tools/`
scripts need only `kubectl` (cluster-reader RBAC) + metrics-server + POSIX tools. No
version pinned.

<!-- MANUAL: -->
