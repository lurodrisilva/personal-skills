<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-07-05 | Updated: 2026-07-05 -->

# aws-finops

## Purpose
Skill for **FinOps on Amazon Web Services** — cloud financial management that maximizes
the **business value** of cloud spend rather than merely cutting it. Owns the operating
doctrine + the AWS toolchain for the **FinOps Framework** (the FinOps Foundation model:
the Inform → Optimize → Operate lifecycle and the four domains — *Understand usage &
cost*, *Quantify business value*, *Optimize usage & cost*, *Manage the FinOps practice*),
the **AWS Well-Architected Cost Optimization** pillar (five design principles), and
**FOCUS** (the FinOps Open Cost & Usage Specification) as the billing-data schema. The
AWS sibling of `azure-finops`; sits in `platform-engineering/` next to `aws-cli` (CLI
mechanics it delegates to).

## Key Files
| File | Description |
|------|-------------|
| `SKILL.md` | The skill — `name: aws-finops`, `domain: platform-engineering`, `platform: aws`, `discipline: finops`, `framework: finops-framework, waf-cost-optimization`, `spec: FOCUS` |

## Subdirectories
| Directory | Purpose |
|-----------|---------|
| `tools/` | 3 read-only `aws` cost-triage scripts (`aws-cost-summary.sh`, `aws-waste-finder.sh`, `aws-commitment-coverage.sh`) — Cost Explorer + EC2/ELB describe + Cost Optimization Hub; read-only is a hard invariant (see `tools/AGENTS.md`) |

## For AI Agents

### Working In This Directory
- Edit `SKILL.md` (and the read-only `tools/` scripts). Almost every change is authoring.
- **The doctrine is the spine, in order:** *value over raw savings* → *allocate before
  you optimize* (≥90% allocatable via cost allocation tags + Cost Categories +
  Organizations) → *usage before rate* (rightsize/kill waste **before** buying Savings
  Plans/RIs) → *iterate* (3–5 capabilities per cycle, Crawl/Walk/Run) → *guardrails, not
  gates* (SCPs / tag policies / budget actions) → *the agent is read-mostly* (every
  buy/delete is a gated, human-approved change; even the **FinOps Agent** only files
  tickets). Keep those invariants intact on edits.
- **Two levers kept distinct:** **usage optimization** (rightsize, waste, scale,
  schedule) changes *what you run*; **rate optimization** (Savings Plans vs RIs vs Spot,
  Graviton) changes *what you pay*. Never blur them — never recommend a commitment on
  un-right-sized usage.
- **Version discipline is load-bearing:** Cost Explorer, **Cost Optimization Hub**,
  **Data Exports**, the **AWS FinOps Agent** (preview), and the **FOCUS** spec all move
  fast. **State behavior, pin NO version, and frame FOCUS columns / Cost Optimization
  Hub + Compute Optimizer coverage / Trusted Advisor checks / `aws` subcommands as
  "verify against the AWS docs + focus.finops.org".** Same no-version-pin doctrine the
  `azure-finops` / `karpenter-operations` skills follow.
- Keep the **scope boundary** sharp:
  - **Generic AWS CLI mechanics** (config, credentials, JMESPath, waiters) → `../aws-cli/`.
    This skill *uses* the CLI to read cost data; it does not own CLI ergonomics.
  - **EKS in-cluster allocation** (OpenCost / Kubecost, right-sizing pod requests, the
    allocated/idle/shared split) → `../../operations/kubernetes-finops/`. This skill owns
    the **AWS-native** EKS view (Split Cost Allocation Data in the CUR).
  - **EKS node-lifecycle autoscaling** (Karpenter) → `../../operations/karpenter-operations/`.
  - **The Azure sibling** → `../azure-finops/` (same framework, different toolchain).
  - **Incident-driven cost spikes / agentic remediation** → `../../operations/agentic-k8s-ops/`.
- Highest-value facts to keep correct: **FOCUS** `EffectiveCost` (amortized) is the
  optimization number, `PricingCategory` (`Standard`/`Dynamic`/`Committed`) +
  `CommitmentDiscountCategory` (`Usage`=RI / `Spend`=Savings-Plan) classify spend; KPI
  bands **coverage 60–85% · utilization >90% · forecast variance ±15% · allocatable
  ≥90% · waste <10%**; a **stopped EC2 still bills EBS + Elastic IP**; **Compute Savings
  Plans** are the default commitment (RIs only where no SP: RDS/Redshift/ElastiCache/
  OpenSearch); EKS cost = **allocated (requests, via SCAD) + idle (platform's KPI) +
  shared**.
- The `description:` uses a `>-` block scalar (colon/backtick-dense) — keep it and
  re-verify `yq '.description | type'` is `!!str` after edits.

### Testing Requirements
- **`scripts/validate-skills.sh` validates this directory** (`platform-engineering/` is in
  `DOMAIN_DIRS`): frontmatter (`name`/`description`/`license`/`compatibility`, non-empty
  `metadata` map), non-empty body, even fence count. Run it after edits.
- `tools/` is **not** validator-covered — verify by hand (`bash -n`, the mutating-`aws`-verb
  grep, executable bit) per `tools/AGENTS.md`.

### Companion Subagents
- Ships a **5-agent AWS FinOps team** in `../../.claude/agents/`:
  `aws-finops-cost-allocator` (Inform — Data Exports/FOCUS + CUR into S3/Athena/QuickSight,
  cost allocation tags + Cost Categories + Organizations, CID dashboards, allocatable-spend
  KPI), `aws-finops-budget-forecaster` (Quantify — AWS Budgets + budget actions,
  forecasting ±15%, unit economics incl. Bedrock cost/token, Cost Anomaly Detection),
  `aws-finops-usage-optimizer` (Optimize/usage — Compute Optimizer + Cost Optimization
  Hub rightsizing, Trusted Advisor, waste cleanup, EKS SCAD split — owns
  `tools/aws-waste-finder.sh`), `aws-finops-rate-optimizer` (Optimize/rate — Savings
  Plans/RIs/Spot, Graviton, coverage/utilization — owns `tools/aws-commitment-coverage.sh`),
  `aws-finops-governance-lead` (Operate — SCPs/tag policies/budget-action guardrails,
  Billing Conductor chargeback, cadence, maturity). The SKILL's "Subagent Orchestration"
  table maps capability → agent; update both on rename.

### Common Patterns
- Intro + mental model → the FinOps-domain × AWS-tooling table → CORE PRINCIPLES →
  CAPABILITY MAP → phases A–F (Inform / Quantify / Optimize / Operate / EKS / AI) →
  anti-patterns → checklist → reference → MCP surface → subagent orchestration. Same
  authoring shape as the sibling `azure-finops` skill.

## Dependencies

### Internal
- `../../scripts/validate-skills.sh` — enforces the SKILL.md contract.
- `../../README.md` — references this skill in the "Platform Engineering" table; rename → README update.
- `../../.claude/agents/aws-finops-*.md` — the 5 companion subagents.
- `../aws-cli/SKILL.md` (CLI mechanics), `../azure-finops/SKILL.md` (Azure sibling),
  `../../operations/kubernetes-finops/SKILL.md` (EKS in-cluster allocation),
  `../../operations/karpenter-operations/SKILL.md` (EKS node autoscaling),
  `../../operations/agentic-k8s-ops/SKILL.md` (agentic blast-radius) — cross-referenced to
  keep boundaries sharp.

### External
None at runtime — documentation. Describes AWS FinOps; cites the AWS docs
(Cost Management, Cost Optimization Hub, Compute Optimizer, Billing Conductor, FinOps
Agent) and `focus.finops.org`. `tools/` scripts need only `aws` (billing / Cost Explorer
read-only + EC2/ELB describe RBAC; Cost Optimization Hub opted in) + POSIX tools. No
version pinned.

<!-- MANUAL: -->
