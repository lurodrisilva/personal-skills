<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-07-02 | Updated: 2026-07-02 -->

# azure-finops

## Purpose
Skill for **FinOps on Microsoft Azure** — cloud financial management that maximizes the
**business value** of cloud spend rather than merely cutting it. Owns the operating
doctrine + the Azure toolchain for the **FinOps Framework** (the FinOps Foundation model
Microsoft mirrors: the Inform → Optimize → Operate lifecycle and the four domains —
*Understand usage & cost*, *Quantify business value*, *Optimize usage & cost*, *Manage
the FinOps practice*), the **Azure Well-Architected Cost Optimization** pillar (five
principles + the **CO:01–CO:14** checklist), and **FOCUS** (the FinOps Open Cost & Usage
Specification) as the billing-data schema. Sits with its cost siblings in
`platform-engineering/`: `azure-retail-prices` (pricing reads) and `kusto-kql-api` (the
KQL engine).

## Key Files
| File | Description |
|------|-------------|
| `SKILL.md` | The skill — `name: azure-finops`, `domain: platform-engineering`, `platform: azure`, `discipline: finops`, `framework: finops-framework, waf-cost-optimization`, `spec: FOCUS` |

## Subdirectories
| Directory | Purpose |
|-----------|---------|
| `tools/` | 3 read-only `az` cost-triage scripts (`azure-cost-summary.sh`, `azure-waste-finder.sh`, `azure-commitment-coverage.sh`) — Cost Management + ARG KQL + Advisor; read-only is a hard invariant (see `tools/AGENTS.md`) |

## For AI Agents

### Working In This Directory
- Edit `SKILL.md` (and the read-only `tools/` scripts). Almost every change is authoring.
- **The doctrine is the spine, in order:** *value over raw savings* → *allocate before
  you optimize* (≥90% allocatable via tags + MG/subscription hierarchy) → *usage before
  rate* (rightsize/kill waste **before** buying Reservations/Savings-Plans) → *iterate*
  (3–5 capabilities per cycle, Crawl/Walk/Run) → *guardrails, not gates* (Azure Policy) →
  *the agent is read-mostly* (every buy/delete is a gated, human-approved change). Keep
  those invariants intact on edits.
- **Two levers kept distinct:** **usage optimization** (rightsize, waste, scale, schedule)
  changes *what you run*; **rate optimization** (Reservations vs Savings Plans vs Spot,
  Azure Hybrid Benefit) changes *what you pay*. Never blur them — never recommend a
  commitment on un-right-sized usage.
- **Version discipline is load-bearing:** Cost Management, the **FinOps toolkit**, and the
  **FOCUS** spec all move fast (FOCUS is versioned; toolkit ships monthly). **State
  behavior, pin NO version, and frame FOCUS columns / toolkit components / Advisor
  categories / `az` subcommands as "verify against Microsoft Learn + focus.finops.org".**
  Same no-version-pin doctrine the `azure-sre-agent` / `dynatrace` / `karpenter-operations`
  skills follow.
- Keep the **scope boundary** sharp:
  - **Pricing-API reads** (public Retail Prices REST) → `../azure-retail-prices/`.
  - **Kusto/KQL engine mechanics** (ADX / Fabric / Log Analytics REST, v1/v2 frames) →
    `../kusto-kql-api/`. This skill *uses* ARG/FOCUS KQL; it does not own the engine.
  - **AKS node-lifecycle autoscaling** (Karpenter / NAP) → `../../operations/karpenter-operations/`;
    generic requests-limits / HPA capacity → `../../operations/kubernetes-operations/`.
    This skill owns the container **cost split**, not the autoscaler.
  - **Incident-driven cost spikes / agentic remediation** → `../../operations/azure-sre-agent/`
    + `../../operations/agentic-k8s-ops/` (read-mostly, gated-write blast-radius doctrine).
- Highest-value facts to keep correct: **FOCUS** `EffectiveCost` (amortized) is the
  optimization number, `PricingCategory` (`Standard`/`Dynamic`/`Committed`) +
  `CommitmentDiscountCategory` (`Usage`=reservation / `Spend`=savings-plan) classify
  spend; KPI bands **coverage 60–85% · utilization >90% · forecast variance ±15% ·
  allocatable ≥90% · waste <10%**; **stopped ≠ deallocated** (stopped VMs still bill
  compute); AKS cost = **allocated (requests) + idle (platform's KPI) + shared**.
- The `description:` uses a `>-` block scalar (colon/backtick-dense) — keep it and
  re-verify `yq '.description | type'` is `!!str` after edits.

### Testing Requirements
- **`scripts/validate-skills.sh` validates this directory** (`platform-engineering/` is in
  `DOMAIN_DIRS`): frontmatter (`name`/`description`/`license`/`compatibility`, non-empty
  `metadata` map), non-empty body, even fence count. Run it after edits.
- `tools/` is **not** validator-covered — verify by hand (`bash -n`, the mutating-`az`-verb
  grep, executable bit) per `tools/AGENTS.md`.

### Companion Subagents
- Ships a **5-agent Azure FinOps team** in `../../.claude/agents/`:
  `finops-cost-allocator` (Inform — FOCUS exports, tags + hierarchy, showback split,
  allocatable-spend KPI), `finops-budget-forecaster` (Quantify — budgets + action groups,
  forecasting ±15%, unit economics incl. AI cost/token, anomaly management),
  `finops-usage-optimizer` (Optimize/usage — rightsizing, Advisor, ARG waste cleanup, AKS
  cost split — owns `tools/azure-waste-finder.sh`), `finops-rate-optimizer` (Optimize/rate
  — Reservations/Savings-Plans/Spot, Azure Hybrid Benefit, coverage/utilization — owns
  `tools/azure-commitment-coverage.sh`), `finops-governance-lead` (Operate — Azure Policy
  guardrails, chargeback, cadence, maturity). The SKILL's "Subagent Orchestration" table
  maps capability → agent; update both on rename.

### Common Patterns
- Intro + mental model → the FinOps-domain × Azure-tooling table → CORE PRINCIPLES →
  CAPABILITY MAP → phases A–F (Inform / Quantify / Optimize / Operate / AKS / AI) →
  anti-patterns → checklist → reference → MCP surface → subagent orchestration. Same
  authoring shape as the sibling operations skills.

## Dependencies

### Internal
- `../../scripts/validate-skills.sh` — enforces the SKILL.md contract.
- `../../README.md` — references this skill in the "Platform Engineering" table; rename → README update.
- `../../.claude/agents/finops-*.md` — the 5 companion subagents.
- `../azure-retail-prices/SKILL.md` (pricing reads), `../kusto-kql-api/SKILL.md` (KQL
  engine), `../../operations/karpenter-operations/SKILL.md` (AKS node autoscaling),
  `../../operations/agentic-k8s-ops/SKILL.md` (agentic blast-radius) — cross-referenced to
  keep boundaries sharp.

### External
None at runtime — documentation. Describes Azure FinOps; cites Microsoft Learn
(`learn.microsoft.com/cloud-computing/finops`, WAF cost optimization) and
`focus.finops.org`. `tools/` scripts need only `az` (Cost Management Reader + Reader RBAC,
`resource-graph` + `costmanagement` extensions) + POSIX tools. No version pinned.

<!-- MANUAL: -->
