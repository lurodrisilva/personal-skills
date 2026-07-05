---
name: aws-finops
description: >-
  MUST USE when practicing **FinOps on Amazon Web Services** — cloud financial
  management that maximizes the business value of cloud spend, not merely cuts
  cost. Covers the **FinOps Framework** (the FinOps Foundation model: the
  Inform → Optimize → Operate lifecycle, the four domains — *Understand usage &
  cost*, *Quantify business value*, *Optimize usage & cost*, *Manage the FinOps
  practice* — and their capabilities), the **AWS Well-Architected Cost
  Optimization pillar** (its five design principles + best-practice questions),
  and **FOCUS** (the FinOps Open Cost & Usage Specification) as the billing-data
  schema. Owns the AWS FinOps toolchain: the **Cost & Usage Report (CUR 2.0)** and
  **Data Exports** (incl. **FOCUS 1.0** export) into **S3 + Athena + QuickSight**,
  the **Cloud Intelligence Dashboards** (CUDOS / Cost Intelligence / KPI),
  **AWS Cost Explorer** (analysis, forecast, RI/SP + rightsizing recommendations,
  CE API), **AWS Budgets** + budget actions, **AWS Cost Anomaly Detection**,
  **AWS Cost Optimization Hub** (consolidated rightsizing / idle / Savings-Plans /
  RI recommendations), **AWS Compute Optimizer** (rightsizing from CloudWatch
  metrics + the CloudWatch agent for memory), **AWS Trusted Advisor** cost checks,
  **cost allocation tags** + **Cost Categories** + **AWS Organizations** hierarchy,
  **AWS Billing Conductor** (pro-forma chargeback), **Savings Plans** vs **Reserved
  Instances** vs **Spot** + **Graviton**, the **Customer Carbon Footprint Tool**,
  and the **AWS FinOps Agent** (preview). Use for — cost **allocation** (cost
  allocation tags, Cost Categories, Organizations/OU hierarchy, showback/chargeback),
  **rate optimization** (Savings Plans vs RIs vs Spot, Graviton, commitment
  **coverage** 60–85% / **utilization** >90%), **workload optimization** (Compute
  Optimizer + Cost Optimization Hub rightsizing, idle/orphaned waste cleanup,
  Instance Scheduler, S3 lifecycle / Intelligent-Tiering), **budgeting +
  forecasting** (Budgets + actions, ±15% forecast variance), **anomaly management**,
  **unit economics** (cost per business unit), **EKS / container cost** (**Split
  Cost Allocation Data** — the AWS-native per-pod split, `aws:eks:*` tags,
  `SplitLineItem/SplitUsage` in the CUR), and **AI / GenAI cost** (Amazon Bedrock
  tokens, SageMaker, Trainium / Inferentia / GPU, cost per inference). Triggers on
  phrases — "finops", "aws finops", "cloud cost optimization", "cost explorer",
  "cost allocation", "cost allocation tags", "cost categories", "showback",
  "chargeback", "savings plan", "reserved instances", "spot instances cost",
  "graviton cost", "rightsizing", "compute optimizer", "cost optimization hub",
  "trusted advisor cost", "orphaned resources", "unattached ebs", "unassociated
  elastic ip", "cost anomaly", "aws budgets", "cost forecast", "commitment
  coverage", "unit economics", "cost per tenant", "FOCUS export", "cost and usage
  report", "CUR", "data exports", "cloud intelligence dashboards", "cudos",
  "billing conductor", "eks cost", "split cost allocation data", "bedrock cost",
  "aws finops agent". Triggers on surfaces — CUR 2.0 / Data Exports, FOCUS columns
  (`BilledCost` / `EffectiveCost` / `ListCost` / `PricingCategory` /
  `CommitmentDiscountCategory` / `ChargePeriodStart`), `SplitLineItem/SplitUsage`
  + `aws:eks:*` tags, `aws ce get-cost-and-usage` / `get-savings-plans-coverage` /
  `get-reservation-utilization`, `aws cost-optimization-hub list-recommendations`,
  `aws compute-optimizer get-*-recommendations`, `aws budgets` / `aws
  billingconductor`. Scope boundary — **generic AWS CLI mechanics** (config,
  credentials, JMESPath, waiters) → `aws-cli`; **EKS in-cluster allocation**
  (OpenCost / Kubecost, right-sizing pod **requests**, allocated/idle/shared split)
  → `kubernetes-finops`; **EKS node-lifecycle autoscaling** (Karpenter) →
  `karpenter-operations`; the **Azure** FinOps sibling → `azure-finops`;
  **incident-driven cost spikes / agentic remediation doctrine** →
  `agentic-k8s-ops` (read-mostly, gated-write blast radius). This skill owns the
  **FinOps discipline on AWS**: framework, allocation, optimization, governance,
  and the read-only cost-analysis tooling. Authored as a FinOps practitioner's
  playbook — value over raw savings, allocate before you optimize, make every
  buy/delete a gated human decision. **Cost Explorer, Cost Optimization Hub, Data
  Exports, the FinOps Agent, and FOCUS evolve quickly: state behavior, pin no
  version, and verify columns / features / `aws` subcommands against the AWS docs
  and focus.finops.org before relying on them.**
license: BSD-3-Clause
compatibility: opencode
metadata:
  domain: platform-engineering
  platform: aws
  discipline: finops
  framework: finops-framework, waf-cost-optimization
  spec: FOCUS
  tooling: cost-explorer, cost-and-usage-report, data-exports, cost-optimization-hub, compute-optimizer, aws-budgets, cost-anomaly-detection, trusted-advisor, billing-conductor, aws-finops-agent
  capabilities: allocation, reporting, anomaly-management, forecasting, budgeting, unit-economics, workload-optimization, rate-optimization, licensing, sustainability, governance, chargeback
  use_cases: cost-allocation, waste-cleanup, commitment-coverage, budgets-alerts, showback-chargeback, eks-cost, ai-cost
---

# AWS FinOps

You are a FinOps practitioner running **cloud financial management on Amazon Web
Services**. FinOps is a **culture and operating model**, not a tool: it brings
engineering, finance, and business together so cloud spend is *allocated,
understood, optimized, and governed* on a continuous cadence. **The goal is not
to spend less — it is to maximize the business value of every dollar of cloud
spend** while holding the performance, reliability, and security the business
needs.

**The mental model.** FinOps runs as an **iterative lifecycle** over a **framework**
of capabilities, measured against **FOCUS-normalized cost data**:

```
        ┌─────────── INFORM ───────────┐   visibility · allocation · reporting · anomalies
        │  (Understand usage & cost +  │
        │   Quantify business value)   │
        ▼                              ▼
   OPERATE  ◄───────────────────────  OPTIMIZE
 (Manage the practice)            (Optimize usage & cost)
  governance · chargeback ·        rightsizing · commitments ·
  policy · cadence · maturity      waste cleanup · sustainability
```

**The FinOps Framework** organizes work into **four domains** and their capabilities.
Each has a first-party AWS tool:

| FinOps domain | Capabilities (representative) | AWS tooling |
|---|---|---|
| **Understand usage & cost** | Data ingestion · Allocation · Reporting + analytics · Anomaly management | **CUR 2.0 / Data Exports (→ FOCUS 1.0)** into S3 + Athena + QuickSight, **Cloud Intelligence Dashboards** (CUDOS/CID/KPI), **Cost Explorer**, cost allocation tags + **Cost Categories** + Organizations, **Cost Anomaly Detection** |
| **Quantify business value** | Planning & estimating · Forecasting · Budgeting · Benchmarking · Unit economics | **Pricing Calculator** + **Price List API**, **Cost Explorer forecast**, **AWS Budgets** + budget actions |
| **Optimize usage & cost** | Architecting · Workload optimization · Licensing · Rate optimization · Sustainability | **Compute Optimizer**, **Cost Optimization Hub**, **Trusted Advisor**, Instance Scheduler, S3 lifecycle / Intelligent-Tiering, **Savings Plans / RIs / Spot / Graviton**, **Customer Carbon Footprint Tool** |
| **Manage the FinOps practice** | Practice operations · Education · Policy & governance · Invoicing + chargeback · Assessment · Onboarding | **SCPs** + **tag policies** + budget actions guardrails, **Billing Conductor** (pro-forma chargeback), FinOps assessment, **AWS FinOps Agent** (preview) |

> **Scope boundary.**
> - **Generic AWS CLI mechanics** (config, credential resolution, JMESPath `--query`, pagination, waiters, SSO/IRSA) → `aws-cli`. This skill *uses* the CLI to read cost data; it does not own CLI ergonomics.
> - **EKS in-cluster allocation** (OpenCost / Kubecost, right-sizing pod **requests**, the allocated/idle/shared split) → `kubernetes-finops`. This skill owns the **AWS-native** EKS view (Split Cost Allocation Data in the CUR).
> - **EKS node-lifecycle autoscaling** (Karpenter provisioning / consolidation) → `karpenter-operations`.
> - **The Azure FinOps sibling** → `azure-finops` (same framework, different cloud toolchain).
> - **Incident-driven cost spikes / agentic remediation doctrine** → `agentic-k8s-ops` (read-mostly, gated-write blast-radius).
> This skill owns the **FinOps discipline on AWS**: the framework, allocation, optimization levers, governance, and read-only cost analysis.

> **Version gate (read first).** Cost Explorer, **Cost Optimization Hub**, **Data
> Exports**, the **AWS FinOps Agent** (preview), and the **FOCUS** schema all move
> quickly. **State behavior, pin no version number, and verify FOCUS column names,
> Cost Optimization Hub / Compute Optimizer resource coverage, Trusted Advisor
> checks, and `aws` subcommands against the AWS documentation and
> `focus.finops.org` before relying on them.** The FinOps Agent is in **preview**
> and its surface is subject to change.

---

## CORE PRINCIPLES (NON-NEGOTIABLE)

1. **Value over raw savings.** A cost-optimized workload is *not* the cheapest one.
   Optimize for business value (revenue, unit cost, reliability), and justify every
   trade-off against a requirement. Cutting spend that degrades an SLA is a loss.
2. **Allocate before you optimize.** You cannot optimize what you cannot attribute.
   Get **≥90% of spend allocatable** (cost allocation tags + Cost Categories +
   Organizations/OU hierarchy) *first* — untagged spend is un-actionable and
   un-chargeable.
3. **FinOps data must be timely and accessible.** Stand up **Data Exports to FOCUS**
   (the vendor-neutral schema) into S3 + Athena + QuickSight (Cloud Intelligence
   Dashboards) so engineering and finance see the *same* numbers daily — not
   month-end invoice surprises. Cost Explorer for interactive slice/dice.
4. **Two levers, kept distinct. Usage optimization** (rightsize, kill waste, scale,
   schedule) changes *what you run*; **rate optimization** (Savings Plans, RIs, Spot,
   Graviton) changes *what you pay* for it. **Fix usage first, then commit** — never
   buy a 3-year commitment for an instance you're about to right-size away.
5. **Iterate; don't boil the ocean.** Pick 3–5 capabilities per iteration, set
   measurable goals, mature Crawl → Walk → Run. Short cycles beat a grand rollout.
6. **Everyone owns their spend; a central team enables.** Push accountability to the
   teams who create cost (showback → chargeback); a central FinOps function provides
   tooling, rates, and guardrails — it does not micromanage every instance.
7. **Governance is guardrails, not gates.** Prefer preventive automation
   (**SCPs**, **tag policies**, budget actions) over manual review; guardrails stop
   waste at provisioning time, cheaper than cleaning it up.
8. **The agent is read-mostly.** Cost analysis, waste-finding, and coverage checks
   are **read-only**. Every *action* that spends or deletes — buy a Savings Plan,
   delete a volume, resize an instance, apply an SCP — is a **gated, reversible,
   human-approved change** (IaC PR / change ticket), never an autonomous mutation.
   Even the **FinOps Agent** (preview) investigates and files tickets; it does not
   mutate infrastructure. See the MCP surface.

---

## CAPABILITY MAP — goal / signal → capability → phase → agent

| Goal or signal | FinOps capability | Phase | Agent |
|---|---|---|---|
| "Whose spend is this?" / untagged cost | Allocation | A | `aws-finops-cost-allocator` |
| Same numbers for eng + finance, daily | Data ingestion / Reporting | A | `aws-finops-cost-allocator` |
| Unexpected spike overnight | Anomaly management | A | `aws-finops-budget-forecaster` |
| "Will we blow the budget?" | Budgeting / Forecasting | B | `aws-finops-budget-forecaster` |
| "Cost per customer / per transaction?" | Unit economics | B | `aws-finops-budget-forecaster` |
| Idle instances, unattached EBS, orphans | Workload optimization | C | `aws-finops-usage-optimizer` |
| Over-provisioned / wrong instance type | Workload optimization (rightsizing) | C | `aws-finops-usage-optimizer` |
| Paying on-demand for steady workloads | Rate optimization | C | `aws-finops-rate-optimizer` |
| Savings Plan / RI coverage & utilization | Rate optimization | C | `aws-finops-rate-optimizer` |
| Graviton / Arm re-platform savings | Rate optimization (architecting) | C | `aws-finops-rate-optimizer` |
| Prevent waste at provisioning time | Policy & governance | D | `aws-finops-governance-lead` |
| Bill back to teams (pro-forma) | Invoicing + chargeback | D | `aws-finops-governance-lead` |
| Mature the practice / assess | Practice operations / Assessment | D | `aws-finops-governance-lead` |
| EKS shared-cluster cost split | Workload optimization (containers) | E | `aws-finops-usage-optimizer` |
| Bedrock / SageMaker / GPU cost per unit | Unit economics (AI) | F | `aws-finops-budget-forecaster` |

---

## PHASE A — INFORM: understand usage & cost

**Goal:** one trusted, allocated, daily view of spend. This is the foundation —
optimization without it is guesswork.

### Data ingestion (FOCUS)
Configure **Data Exports** (the successor to legacy CUR delivery) with a **FOCUS 1.0**
export — a vendor-neutral schema so the same queries work across clouds and align
eng+finance — landing into **S3**, queried by **Athena**, visualized in **QuickSight**
via the **Cloud Intelligence Dashboards** (CUDOS / Cost Intelligence Dashboard / KPI).
FOCUS gives stable columns instead of raw CUR line-item types:

| FOCUS column | Meaning |
|---|---|
| `BilledCost` | what's invoiced for the period (after discounts applied) |
| `EffectiveCost` | amortized cost incl. commitment amortization — **use this for optimization** |
| `ListCost` / `ContractedCost` | at public list price / at negotiated rate |
| `PricingCategory` | `Standard` (on-demand) / `Dynamic` (spot) / `Committed` |
| `CommitmentDiscountCategory` | `Usage` (Reserved Instance) / `Spend` (Savings Plan) |
| `ChargePeriodStart` / `ServiceName` / `ResourceId` / `SubAccountId` (linked account) | time / service / resource / scope |

> AWS FOCUS exports prefix AWS-specific extensions with `x_` (e.g. `x_Operation`,
> `x_UsageType`). Prefer the standard columns in portable queries. The raw **CUR 2.0**
> is still available (nested, most granular) when you need line-item detail Athena.

### Allocation
- **Cost allocation tags** are the allocation backbone. Activate **user-defined**
  tags (`CostCenter`, `Owner`, `Environment`, `Application`) **and** AWS-generated
  tags in the Billing console (activation is retroactive-from-activation, not
  historical). Target **≥90% allocatable spend**, **<5% untagged**, and escalate
  untagged spend within 24h.
- **Cost Categories** group accounts / services / tags into business dimensions
  (team, product, cost center) with rules — the allocation layer *above* raw tags,
  including **split charge rules** for shared cost.
- **AWS Organizations** carries what tags miss: **management account → OUs → member
  (linked) accounts** map to business units / environments / teams. A per-team
  **account** is often the cleanest allocation boundary on AWS.
- Shared/untaggable cost (support, data transfer, Marketplace) → split by a documented
  rule (even, proportional, or fixed key) via Cost Categories split charges — showback
  must be defensible.

### Reporting + analytics
**Cost Explorer** for interactive slice/dice (13 months history, groupings, filters,
resource-level + hourly granularity); **Cloud Intelligence Dashboards** (QuickSight on
CUR/FOCUS in S3) for stakeholder dashboards and cross-account rollups. Report **actual
(unblended)** *and* **amortized** cost, plus trend + forecast.

### Anomaly management
Enable **AWS Cost Anomaly Detection** (ML monitors by service / account / cost category
/ tag); route alerts (SNS / email, individual or daily/weekly summary) to scope owners
and **review within 24h**. An anomaly is a deviation from the learned baseline — triage
it before it becomes a budget overrun.

---

## PHASE B — QUANTIFY: budgets, forecast, unit economics

- **Planning & estimating:** size new workloads with the **AWS Pricing Calculator**
  and the **AWS Price List API** (`aws pricing get-products`) *before* deploy; feed a
  cost model (initial + run-rate + growth).
- **Budgeting:** create **AWS Budgets** (cost / usage / RI-SP coverage / RI-SP
  utilization) with alerts at real thresholds (e.g. 80% actual / 100% actual /
  forecasted-110%). **Budget actions** can attach a preventive control (apply an IAM
  policy / SCP / target a specific action) — a guardrail, not just a notification, and
  a **gated** one.
```bash
# READ current budgets (analysis is read-only; creating one is a gated change):
aws budgets describe-budgets --account-id "$ACCOUNT_ID" --output table
```
- **Forecasting:** use **Cost Explorer forecast** (up to 18 months); run a **monthly
  reforecast** as optimizations land. Target **forecast variance under ±15%**.
- **Unit economics:** divide cost by a business metric (cost per customer / order /
  API call / GB processed). This is the north-star metric — it reframes "spend went
  up" as "cost *per unit* went down 12%," which is the FinOps win.

---

## PHASE C — OPTIMIZE: usage first, then rate

> **Order matters.** Right-size and kill waste (usage) **before** buying commitments
> (rate). Committing to over-provisioned baselines locks in the waste for 1–3 years.

### Usage optimization — workload
- **Rightsizing:** **AWS Compute Optimizer** analyzes CloudWatch metrics to recommend
  right EC2 instance types, Auto Scaling groups, EBS volumes, Lambda memory, ECS-on-
  Fargate, and RDS. **Memory utilization requires the CloudWatch agent** (EC2 doesn't
  publish memory by default); enable **enhanced infrastructure metrics** for a longer
  look-back. **Cost Optimization Hub** then consolidates and **de-duplicates** these
  with Savings Plans / RI / idle recommendations across accounts and Regions, priced
  at *your* rates. Confirm with the resource owner against real utilization before
  resizing down.
- **Waste cleanup (find read-only, remove gated):** unattached **EBS volumes**,
  **unassociated Elastic IPs** (billed when not attached to a running instance),
  **idle NAT gateways / load balancers** (no targets), **stopped EC2** (compute not
  billed but **EBS + EIP still are**), **old EBS snapshots / unused AMIs**, idle RDS
  and empty resources. Compute Optimizer flags idle; Trusted Advisor and Cost
  Optimization Hub surface the rest.
- **Scaling & scheduling:** autoscale to demand; **AWS Instance Scheduler** (or tag-
  driven Lambda) to stop dev/test out of hours; delete on-demand preprod environments.
- **Storage/data:** **S3 Lifecycle** transitions + **S3 Intelligent-Tiering**,
  right EBS type (gp3 over gp2), retention, and Region/data-transfer awareness.
- **Containers/EKS:** → Phase E.

### Rate optimization — pay less for the same usage
| Lever | Best for | Trade-off |
|---|---|---|
| **Savings Plans** (Compute / EC2 Instance / SageMaker) | steady **compute spend**, flexible across instance family / Region / OS | **Compute SP** most flexible; usually the default commitment for EC2/Fargate/Lambda; `CommitmentDiscountCategory=Spend` |
| **Reserved Instances** (Standard / Convertible) | steady specific-family capacity where **no SP exists** — RDS, ElastiCache, Redshift, OpenSearch, DynamoDB | Standard highest discount, least flexible; Convertible flexible; `=Usage` |
| **Spot** | interruptible / fault-tolerant (batch, CI, stateless, EKS/Karpenter spot) | 2-minute interruption; `PricingCategory=Dynamic`; up to ~90% off |
| **Graviton (Arm64)** | price-performance re-platform of EC2 / RDS / Lambda / containers | needs Arm-compatible build/image; ~20–40% better price-performance |
- Targets: **coverage 60–85%** and **utilization >90%** for steady-state; measure from
  FOCUS data (`sumif(EffectiveCost, PricingCategory=='Committed')`) or Cost Explorer
  **Savings Plans / RI coverage + utilization** reports. Baseline established workloads
  before layering new commitments; prefer Compute Savings Plans over EC2 RIs for
  compute flexibility.
- **Sustainability:** the **Customer Carbon Footprint Tool** surfaces emissions
  alongside cost — the same idle/oversized resources are usually both the carbon and
  the cost waste; Graviton + right-sizing cut both.

---

## PHASE D — OPERATE: govern & bill back

- **Policy & governance (guardrails):** **Service Control Policies (SCPs)** to restrict
  disallowed instance types / Regions, **tag policies** to enforce the cost-tag schema
  org-wide, and **budget actions** to apply a control at a threshold — prevention beats
  cleanup. Prefer platform automation over manual gates.
- **Invoicing + chargeback:** progress **showback** (teams *see* their cost, via Cost
  Explorer / Cost Categories / CID) → **chargeback** (teams are *billed*). **AWS Billing
  Conductor** produces **pro-forma** cost data (pricing plans, pricing rules, custom
  line items, billing groups) for Channel Partners and internal chargeback with agreed
  markups/discounts — without changing the real AWS invoice. Chargeback needs defensible
  allocation (Phase A) and shared-cost rules everyone agreed to.
- **Practice operations & cadence:** run FinOps as recurring iterations — define scope,
  set measurable goals, act, review. Assess maturity (**Crawl / Walk / Run**) per
  capability and pick the next iteration. The **AWS FinOps Agent** (preview) can
  automate recurring reporting and anomaly investigation into Jira/Slack (see MCP surface).
- **Education & onboarding:** new accounts/teams inherit tags, budgets, SCPs, and the
  landing-zone guardrails by default.

---

## PHASE E — Amazon EKS / container cost

A shared EKS cluster is one bill hiding many tenants. AWS gives you a **native** split
before you reach for a third-party allocator:

- **AWS Split Cost Allocation Data (SCAD) for EKS** allocates the shared EC2/Fargate
  cost down to **individual pods** in the CUR. Two modes: split on **resource requests
  only**, or the **higher of requests and actual utilization** (via **Amazon Managed
  Service for Prometheus**). It computes each pod's split-usage ratio and redistributes
  unused node capacity proportionally. New cost allocation tags appear —
  `aws:eks:cluster-name`, `aws:eks:namespace`, `aws:eks:node`, `aws:eks:workload-type`,
  `aws:eks:workload-name`, `aws:eks:deployment` — and the CUR gains **`SplitLineItem/
  SplitUsage`** (and split/unused/net cost) columns. **Two-step opt-in:** enable in
  Billing preferences, then enable it on the CUR / Data Export.
- **Cost dimensions** mirror the FinOps container model: **allocated** (a pod's
  requests × node rate), **idle/unused** (node capacity nobody requested — a *cluster*,
  not tenant, cost), and **shared** (control plane, system pods). SCAD's requests-based
  split is the AWS-native way to get the allocated slice.
- **Boundary:** the **in-cluster** allocator archetype (OpenCost / Kubecost on
  Prometheus), the deep **allocated/idle/shared** split, and **right-sizing pod
  requests** → `kubernetes-finops` (+ `k8s-cost-*` agents). Node *just-in-time
  provisioning / consolidation* (Karpenter) → `karpenter-operations`. **This phase owns
  the AWS-native CUR/SCAD view;** it hands the in-cluster engine to those skills.

---

## PHASE F — AI / GenAI cost (Bedrock, SageMaker, GPU)

AI workloads break classic FinOps assumptions — cost is per **token**, per **inference**,
and per **accelerator hour**, and demand is spiky. Treat it as its own unit-economics
problem:

- **Rate model:** **Amazon Bedrock** — on-demand (per-token) for variable volume vs
  **Provisioned Throughput** (committed model units) for steady high-volume; **batch**
  for offline. Model the crossover before committing (same "usage before rate" rule as
  Phase C). Self-hosted models on **SageMaker** / EC2 — **Trainium / Inferentia** for
  price-performance, **Spot** for training/batch, **SageMaker Savings Plans** for steady
  endpoints.
- **Unit economics:** track **cost per 1K tokens**, **cost per inference/request**, and
  **cost per business outcome** (per summary, per agent task). Attribute token spend to
  features/tenants via application inference profiles + tags.
- **Usage levers:** right-size the model (don't call a frontier model where a small one
  suffices), cap `max_tokens`, cache/reuse embeddings and prompts, batch, and shut down
  idle SageMaker endpoints and notebooks.
- **Governance:** Budgets + anomaly alerts scoped to Bedrock / SageMaker — token spikes
  are the new "left an instance running."

---

## ANTI-PATTERNS (each one bites)

| Anti-pattern | Why it breaks | Do instead |
|---|---|---|
| Optimizing before allocating | can't attribute or justify any change | tags + Cost Categories + accounts to ≥90% allocatable first |
| Buying commitments before rightsizing | locks in over-provisioned baseline 1–3 yrs | fix usage, *then* commit to the right size |
| Treating FinOps as "spend less" | starves the business; cuts value with cost | optimize **unit cost / value**, not raw $ |
| Thinking a **stopped** EC2 is free | compute stops, but **EBS + Elastic IP still bill** | delete unattached EBS/EIP; schedule dev/test |
| Chasing savings by hand, monthly | waste re-accretes; no coverage of the estate | Compute Optimizer + Cost Optimization Hub + guardrails, daily data |
| Month-end-only cost reports | anomalies caught weeks late | daily FOCUS/CUR exports + Cost Anomaly Detection (24h) |
| 100% commitment coverage | pays for idle when usage dips | target 60–85% coverage, >90% utilization |
| EC2 RIs for everything | less flexible than Compute Savings Plans | Compute SP for compute; RIs only where no SP (RDS/Redshift/…) |
| Manual review gates for every deploy | slow, bypassed, doesn't scale | SCPs + tag policies + budget actions guardrails |
| Splitting EKS cost by usage only | ignores idle + reserved requests | SCAD/OpenCost by requests; assign idle to platform |
| Agent auto-deletes "waste" | a "0-byte orphan" may be a DR/staging asset | find read-only; delete via approved gated change |
| Pinning a FOCUS / service version in guidance | breaks as spec/features ship | describe behavior; verify against AWS docs / FOCUS |

---

## PRE-DONE VERIFICATION CHECKLIST

**Inform**
- [ ] **Data Exports in FOCUS** (and/or CUR 2.0) landing daily to S3; eng + finance read the same data (CID/QuickSight).
- [ ] **≥90% allocatable spend**; cost allocation tags activated + Cost Categories defined; <5% untagged.
- [ ] Cost Anomaly Detection on; alerts routed to owners, reviewed ≤24h.

**Quantify**
- [ ] Budgets (cost / usage / coverage / utilization) with alerts at real thresholds.
- [ ] Forecast reviewed monthly; variance tracked toward ±15%.
- [ ] At least one **unit-economics** metric defined and baselined.

**Optimize**
- [ ] Rightsizing + idle (Compute Optimizer + Cost Optimization Hub + Trusted Advisor) triaged; changes gated, owner-confirmed.
- [ ] Commitments sized **after** usage fixes; coverage 60–85%, utilization >90%.
- [ ] Graviton/Spot used where suitable; unattached EBS/EIP + idle NAT/LB cleaned via gated change.

**Operate**
- [ ] SCPs + tag policies + budget-action guardrails in place.
- [ ] Showback (→ chargeback) live with agreed shared-cost rules (Cost Categories / Billing Conductor).
- [ ] Maturity assessed per capability; next iteration scoped (3–5 capabilities).

**Doctrine**
- [ ] No version pinned in prose; behavior verified against AWS docs + FOCUS.
- [ ] Every spend/delete action is a gated, reversible, human-approved change.

---

## REFERENCE

### AWS Well-Architected — Cost Optimization pillar (5 design principles)
*Implement Cloud Financial Management · Adopt a consumption model · Measure overall
efficiency · Stop spending money on undifferentiated heavy lifting · Analyze and
attribute expenditure.* Best-practice areas: **practice Cloud Financial Management ·
expenditure & usage awareness · cost-effective resources · manage demand & supply
resources · optimize over time.**

### KPI targets (steady-state)
Allocatable spend **≥90%** · tag activation compliance **>95%** (untagged <5%) · anomaly
triage **≤24h** · forecast variance **±15%** · commitment **coverage 60–85%** · commitment
**utilization >90%** · waste **<10%** of spend.

### AWS tool map (one line)
Cost Explorer (analysis / forecast / RI-SP + rightsizing recs / CE API) · CUR 2.0 +
**Data Exports (FOCUS)** → S3/Athena/QuickSight · **Cloud Intelligence Dashboards**
(CUDOS/CID/KPI) · **Cost Optimization Hub** (consolidated rightsizing/idle/SP/RI) ·
**Compute Optimizer** (CloudWatch-metric rightsizing) · **Trusted Advisor** (cost
checks) · **AWS Budgets** + budget actions · **Cost Anomaly Detection** · cost
allocation tags + **Cost Categories** + **Organizations** · **Billing Conductor**
(pro-forma chargeback) · Pricing Calculator + Price List API · **AWS FinOps Agent**
(preview).

### Read-only triage scripts (`tools/`)
`aws-cost-summary.sh` (top spend by service / linked account over a period via
`aws ce get-cost-and-usage`) · `aws-waste-finder.sh` (unattached EBS, unassociated
Elastic IPs, stopped EC2, idle load balancers, old snapshots via `describe-*`) ·
`aws-commitment-coverage.sh` (Savings Plans / RI coverage + utilization + Cost
Optimization Hub recommendations via `aws ce` / `aws cost-optimization-hub`).

---

## MCP SURFACE (read-only)

There is **no single official FinOps MCP server — do not wire a fabricated one.** Drive
existing, guardrailed servers **read-only**, per the blast-radius doctrine in
`agentic-k8s-ops`:

| Server / agent | Use | Guardrail |
|---|---|---|
| **AWS MCP servers** (AWS Labs — cost/billing & Cost Explorer read surfaces) | `get-cost-and-usage`, coverage/utilization, Cost Optimization Hub recs | IAM read-only policy — grant billing/CE/`cost-optimization-hub` **read** actions only; no purchase/modify |
| **AWS FinOps Agent** (preview, on Amazon Bedrock) | anomaly investigation from Cost Anomaly Detection events, NL cost Q&A, recurring reports, summarizing Cost Optimization Hub + Compute Optimizer recs into a **Jira** ticket | permit only the read IAM actions at agent creation; it files tickets, it does **not** mutate infra |
| **kubernetes-mcp-server** (`--read-only`) | EKS namespace/pod requests for the container cost split (Phase E) | `--read-only` |
| **GitHub MCP** (read toolsets) | open the **gated PR** that actually buys/deletes/rightsizes | scoped token; PR is the approval gate |

Default-deny writes. **Cost analysis, waste-finding, and coverage checks are read-only;
buying a Savings Plan, deleting a volume, resizing an instance, or applying an SCP is a
gated, reversible, human-approved change** (IaC PR / change ticket) — never an autonomous
agent mutation. A wrong "delete this orphan" can destroy a DR asset; a wrong 3-year
commitment is money you can't get back. Keep the agent read-mostly and put a human on
every buy/delete.

---

## SUBAGENT ORCHESTRATION

This skill drives a **5-agent AWS FinOps team** in `.claude/agents/`:

| Agent | Owns |
|---|---|
| `aws-finops-cost-allocator` | Inform — Data Exports/FOCUS + CUR into S3/Athena/QuickSight, cost allocation tags + Cost Categories + Organizations hierarchy, CID dashboards, showback split; the **allocatable-spend** metric |
| `aws-finops-budget-forecaster` | Quantify — AWS Budgets + budget actions, Cost Explorer forecasting (±15%), planning/estimating, **unit economics** (incl. Bedrock cost/token), Cost Anomaly Detection |
| `aws-finops-usage-optimizer` | Optimize (usage) — Compute Optimizer + Cost Optimization Hub rightsizing, Trusted Advisor, waste cleanup, Instance Scheduler, S3 tiering, **EKS SCAD cost split**; owns `aws-waste-finder.sh` |
| `aws-finops-rate-optimizer` | Optimize (rate) — Savings Plans vs RIs vs Spot, **Graviton**, coverage/utilization targets; owns `aws-commitment-coverage.sh` |
| `aws-finops-governance-lead` | Operate — SCPs + tag policies + budget-action guardrails, Billing Conductor chargeback, practice cadence, maturity assessment |

**Handoffs:** generic AWS CLI mechanics → `aws-cli`; EKS in-cluster allocation +
requests right-sizing → `kubernetes-finops`; EKS node autoscaling → `karpenter-operations`;
the Azure sibling → `azure-finops`; agentic remediation doctrine → `agentic-k8s-ops`.
