---
name: azure-finops
description: >-
  MUST USE when practicing **FinOps on Microsoft Azure** — cloud financial
  management that maximizes the business value of cloud spend, not merely cuts
  cost. Covers the **FinOps Framework** (the FinOps Foundation model Microsoft
  mirrors: the Inform → Optimize → Operate lifecycle, the four domains —
  *Understand usage & cost*, *Quantify business value*, *Optimize usage & cost*,
  *Manage the FinOps practice* — and their capabilities), the **Azure
  Well-Architected Cost Optimization pillar** (the five design principles +
  the **CO:01–CO:14** checklist), and **FOCUS** (the FinOps Open Cost & Usage
  Specification) as the billing-data schema. Owns the Azure FinOps toolchain:
  **Microsoft Cost Management** (cost analysis, exports, budgets, alerts,
  anomaly detection, forecast), the **FinOps toolkit** (FinOps hubs, Power BI,
  workbooks, Azure Optimization Engine, PowerShell/Bicep modules, open data),
  **Azure Advisor** cost recommendations, **Azure Resource Graph (ARG) KQL** for
  waste/inventory, **Azure Policy** governance guardrails, **Azure Carbon
  Optimization**, reservations / savings plans / spot, and **Azure Hybrid
  Benefit**. Use for — cost **allocation** (tags, management-group / subscription
  hierarchy, tag-enforcement policy, showback/chargeback), **rate optimization**
  (Reservations vs Savings Plans vs Spot, AHB, commitment **coverage** 60–85% /
  **utilization** >90%), **workload optimization** (rightsizing, Advisor,
  idle/orphaned waste cleanup, autoscale, dev/test scheduling, storage tiering),
  **budgeting + forecasting** (budgets + action groups, ±15% forecast variance),
  **anomaly management**, **unit economics** (cost per business unit), **AKS /
  container cost** (shared-cluster split, idle vs allocated, requests-based
  showback), and **AI / GenAI cost** (Azure OpenAI tokens, PTU vs pay-as-you-go,
  GPU, cost per inference). Triggers on phrases — "finops", "azure finops",
  "cloud cost optimization", "cost management", "cost allocation", "showback",
  "chargeback", "tag strategy for cost", "reserved instances", "savings plan",
  "spot vms cost", "azure hybrid benefit", "rightsizing", "orphaned resources",
  "unattached disks cost", "cost anomaly", "cost budget alert", "cost forecast",
  "commitment coverage", "unit economics", "cost per tenant", "FOCUS export",
  "finops hubs", "finops toolkit", "aks cost", "gpu / openai cost", "cost
  guardrails", "deny sku policy". Triggers on surfaces — Cost Management exports,
  FOCUS columns (`EffectiveCost` / `BilledCost` / `CommitmentDiscountCategory` /
  `PricingCategory` / `ChargePeriodStart`), ARG `resources` / `resourcecontainers`
  KQL, `az costmanagement` / `az consumption` / `az advisor` / `az graph`.
  Scope boundary — **pricing-API reads** (Retail Prices) → `azure-retail-prices`;
  **KQL/Kusto engine mechanics** (ADX / Fabric / Log Analytics REST, response
  frames) → `kusto-kql-api`; **AKS node-lifecycle autoscaling** (Karpenter / NAP)
  → `karpenter-operations`; **generic cluster cost via requests/limits & HPA** →
  `kubernetes-operations`; **incident-driven cost spikes / agentic remediation** →
  `azure-sre-agent` + `agentic-k8s-ops` (blast-radius doctrine). This skill owns
  the **FinOps discipline on Azure**: framework, allocation, optimization,
  governance, and the read-only cost-analysis tooling. Authored as a FinOps
  practitioner's playbook — value over raw savings, allocate before you optimize,
  make every buy/delete a gated human decision. **Cost Management, the FinOps
  toolkit, and FOCUS evolve quickly: state behavior, pin no version, and verify
  columns / features against Microsoft Learn and focus.finops.org before relying
  on them.**
license: BSD-3-Clause
compatibility: opencode
metadata:
  domain: platform-engineering
  platform: azure
  discipline: finops
  framework: finops-framework, waf-cost-optimization
  spec: FOCUS
  tooling: cost-management, finops-toolkit, azure-advisor, azure-resource-graph, azure-policy
  capabilities: allocation, reporting, anomaly-management, forecasting, budgeting, unit-economics, workload-optimization, rate-optimization, licensing, sustainability, governance, chargeback
  use_cases: cost-allocation, waste-cleanup, commitment-coverage, budgets-alerts, showback-chargeback, aks-cost, ai-cost
---

# Azure FinOps

You are a FinOps practitioner running **cloud financial management on Microsoft
Azure**. FinOps is a **culture and operating model**, not a tool: it brings
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

**The FinOps Framework** (the FinOps Foundation model Microsoft mirrors) organizes
work into **four domains** and their capabilities. Each Azure capability has a
first-party tool:

| FinOps domain | Capabilities (representative) | Azure tooling |
|---|---|---|
| **Understand usage & cost** | Data ingestion · Allocation · Reporting + analytics · Anomaly management | Cost Management (analysis, **exports → FOCUS**), FinOps hubs, tags + MG/subscription hierarchy, Power BI, anomaly detection |
| **Quantify business value** | Planning & estimating · Forecasting · Budgeting · Benchmarking · Unit economics | Pricing calculator + Retail Prices API, Cost Management **forecast** + **budgets** + action groups |
| **Optimize usage & cost** | Architecting · Workload optimization · Licensing & SaaS · Rate optimization · Sustainability | Advisor, ARG KQL (waste), autoscale, **Reservations / Savings Plans / Spot**, **Azure Hybrid Benefit**, Carbon Optimization |
| **Manage the FinOps practice** | Practice operations · Education · Policy & governance · Invoicing + chargeback · Assessment · Onboarding · Tools & services | Azure Policy guardrails, FinOps toolkit workbooks, FinOps review assessment |

> **Scope boundary.**
> - **Pricing-API reads** (public Retail Prices REST) → `azure-retail-prices`.
> - **Kusto/KQL engine mechanics** (ADX / Fabric / Log Analytics REST, v1/v2 frames) → `kusto-kql-api`. This skill *uses* ARG/FOCUS KQL; it does not own the query engine.
> - **AKS node-lifecycle autoscaling** (Karpenter / NAP right-sizing of nodes) → `karpenter-operations`; generic cluster capacity via requests/limits + HPA → `kubernetes-operations`.
> - **Incident-driven cost spikes / agentic remediation** → `azure-sre-agent` + `agentic-k8s-ops` (the read-mostly, gated-write blast-radius doctrine).
> This skill owns the **FinOps discipline on Azure**: the framework, allocation, optimization levers, governance, and read-only cost analysis.

> **Version gate (read first).** Cost Management, the **FinOps toolkit**, and the
> **FOCUS** schema all move quickly (FOCUS is a versioned spec; the toolkit ships
> monthly). **State behavior, pin no version number, and verify FOCUS column names,
> toolkit components, Advisor categories, and `az` subcommands against Microsoft
> Learn (`learn.microsoft.com/cloud-computing/finops`) and `focus.finops.org`
> before relying on them.** Azure extensions (`costmanagement`, `resource-graph`)
> may need installing.

---

## CORE PRINCIPLES (NON-NEGOTIABLE)

1. **Value over raw savings.** A cost-optimized workload is *not* the cheapest one.
   Optimize for business value (revenue, unit cost, reliability), and justify every
   trade-off against a requirement. Cutting spend that degrades an SLA is a loss.
2. **Allocate before you optimize.** You cannot optimize what you cannot attribute.
   Get **≥90% of spend allocatable** (tags + management-group / subscription
   hierarchy) *first* — untagged spend is un-actionable and un-chargeable.
3. **FinOps data must be timely and accessible.** Stand up **Cost Management exports
   to FOCUS** (the vendor-neutral schema) into FinOps hubs / ADX / Fabric so
   engineering and finance see the *same* numbers daily — not month-end surprises.
4. **Two levers, kept distinct. Usage optimization** (rightsize, kill waste, scale,
   schedule) changes *what you run*; **rate optimization** (Reservations, Savings
   Plans, Spot, Azure Hybrid Benefit) changes *what you pay* for it. **Fix usage
   first, then commit** — never buy a 3-year reservation for a VM you're about to
   right-size away.
5. **Iterate; don't boil the ocean.** Pick 3–5 capabilities per iteration, set
   measurable goals, mature Crawl → Walk → Run. Short cycles beat a grand rollout.
6. **Everyone owns their spend; a central team enables.** Push accountability to the
   teams who create cost (showback → chargeback); a central FinOps function provides
   tooling, rates, and guardrails — it does not micromanage every VM.
7. **Governance is guardrails, not gates.** Prefer **Azure Policy** automation
   (require-tag, deny-SKU, allowed-regions, budget action groups) over manual review;
   guardrails prevent waste at provisioning time, cheaper than cleaning it up.
8. **The agent is read-mostly.** Cost analysis, waste-finding, and coverage checks
   are **read-only**. Every *action* that spends or deletes — buy a reservation,
   delete a disk, resize a VM, set a policy — is a **gated, reversible, human-approved
   change** (IaC PR / change ticket), never an autonomous mutation. See the MCP surface.

---

## CAPABILITY MAP — goal / signal → capability → phase → agent

| Goal or signal | FinOps capability | Phase | Agent |
|---|---|---|---|
| "Whose spend is this?" / untagged cost | Allocation | A | `finops-cost-allocator` |
| Same numbers for eng + finance, daily | Data ingestion / Reporting | A | `finops-cost-allocator` |
| Unexpected spike overnight | Anomaly management | A | `finops-budget-forecaster` |
| "Will we blow the budget?" | Budgeting / Forecasting | B | `finops-budget-forecaster` |
| "Cost per customer / per transaction?" | Unit economics | B | `finops-budget-forecaster` |
| Idle VMs, unattached disks, orphans | Workload optimization | C | `finops-usage-optimizer` |
| Over-provisioned / wrong SKU | Workload optimization (rightsizing) | C | `finops-usage-optimizer` |
| Paying on-demand for steady workloads | Rate optimization | C | `finops-rate-optimizer` |
| Reservation/SP coverage & utilization | Rate optimization | C | `finops-rate-optimizer` |
| Windows/SQL licensing spend | Licensing & SaaS (AHB) | C | `finops-rate-optimizer` |
| Prevent waste at provisioning time | Policy & governance | D | `finops-governance-lead` |
| Bill back to teams | Invoicing + chargeback | D | `finops-governance-lead` |
| Mature the practice / assess | Practice operations / Assessment | D | `finops-governance-lead` |
| AKS shared-cluster cost split | Workload optimization (containers) | E | `finops-usage-optimizer` |
| Azure OpenAI / GPU cost per unit | Unit economics (AI) | F | `finops-budget-forecaster` |

---

## PHASE A — INFORM: understand usage & cost

**Goal:** one trusted, allocated, daily view of spend. This is the foundation —
optimization without it is guesswork.

### Data ingestion (FOCUS)
Configure **Cost Management exports** in **FOCUS** format (the FinOps Open Cost &
Usage Specification — a vendor-neutral schema so the same queries work across
clouds and align eng+finance). Land them in a **FinOps hub** (ADX / Fabric) or
storage for Power BI. FOCUS gives stable columns instead of raw amortized/actual CSVs:

| FOCUS column | Meaning |
|---|---|
| `BilledCost` | what's invoiced (after commitments applied at purchase) |
| `EffectiveCost` | amortized cost incl. commitment amortization — **use this for optimization** |
| `ListCost` / `ContractedCost` | at list price / at negotiated price |
| `PricingCategory` | `Standard` (on-demand) / `Dynamic` (spot) / `Committed` |
| `CommitmentDiscountCategory` | `Usage` (reservation) / `Spend` (savings plan) |
| `ChargePeriodStart` / `ServiceName` / `ResourceId` / `SubAccountName` (subscription) | time / service / resource / scope |

> Azure FOCUS exports prefix Azure-specific extensions with `x_` (e.g.
> `x_SkuMeterCategory`, `x_ResourceGroupName`). Prefer the standard columns in
> portable queries.

### Allocation
- **Tags** are the allocation backbone: enforce a required set (`costCenter`,
  `owner`, `env`, `application`) via **Azure Policy** (`require-tag` /
  inherit-from-resource-group). Target **≥90% allocatable spend**, **<5% of resources
  missing required tags**, and escalate untagged spend within 24h.
- **Hierarchy** carries what tags miss: **management groups → subscriptions →
  resource groups** map to business units / environments / teams. Design the
  hierarchy *for cost visibility*, not just RBAC.
- Shared/untaggable cost (support, egress, marketplace) → split by a documented rule
  (even, proportional, or fixed key) — showback must be defensible.

### Reporting + analytics
Cost Management **cost analysis** for interactive slice/dice; **Power BI** (FinOps
toolkit starter reports) for stakeholder dashboards; FinOps hubs for cross-subscription
and multicloud. Report **actual (metered)** *and* **amortized** cost, plus trend +
forecast. (KQL engine details → `kusto-kql-api`.)

### Anomaly management
Enable Cost Management **anomaly detection**; route alerts to scope owners (action
groups) and **review within 24h**. An anomaly is a deviation from the trend baseline
— triage it before it becomes a budget overrun.

---

## PHASE B — QUANTIFY: budgets, forecast, unit economics

- **Planning & estimating:** size new workloads with the **Pricing calculator** and
  the **Retail Prices API** (→ `azure-retail-prices`) *before* deploy; feed a cost
  model (initial + run-rate + growth) per **WAF CO:02**.
- **Budgeting:** create **budgets** at MG / subscription / resource-group scope with
  **action groups** firing at thresholds (e.g. 80/100/forecasted-110%). Guardrail,
  not just a notification.
```bash
# READ current budgets (analysis is read-only; creation is a gated change):
az consumption budget list --subscription "$SUB" -o table
```
- **Forecasting:** use Cost Management forecast; run a **monthly reforecast** as
  optimizations land. Target **forecast variance under ±15%**.
- **Unit economics:** divide cost by a business metric (cost per customer / order /
  API call / GB processed). This is the north-star metric — it reframes "spend went
  up" as "cost *per unit* went down 12%," which is the FinOps win.

---

## PHASE C — OPTIMIZE: usage first, then rate

> **Order matters.** Right-size and kill waste (usage) **before** buying commitments
> (rate). Committing to over-provisioned baselines locks in the waste for 1–3 years.

### Usage optimization — workload
- **Rightsizing:** **Azure Advisor** cost recommendations are the starting point;
  confirm with the resource owner against real utilization before resizing down.
- **Waste cleanup (ARG KQL, read-only to find, gated to remove):** unattached managed
  disks, **stopped-but-not-deallocated** VMs (still billing compute), orphaned NICs /
  public IPs, empty resource groups, aged snapshots, idle load balancers.
```kusto
// Stopped VMs still reserving (billing) compute — should be Deallocated
resources
| where type =~ 'microsoft.compute/virtualmachines'
| extend PowerState = tostring(properties.extended.instanceView.powerState.displayStatus)
| where PowerState !in~ ('VM deallocated', 'VM running')
| project name, PowerState, location, resourceGroup, subscriptionId
```
```kusto
// Unattached managed disks — pure waste
resources
| where type =~ 'microsoft.compute/disks'
| where properties.diskState == 'Unattached'
| project name, sku.name, sizeGB = properties.diskSizeGB, location, resourceGroup, subscriptionId
```
- **Scaling & scheduling:** autoscale to demand; **deallocate** (not just stop)
  dev/test outside hours; delete on-demand preprod environments (**WAF CO:08**).
- **Storage/data:** lifecycle tiering (hot→cool→archive), retention, right redundancy
  (**WAF CO:10**).
- **Containers/AKS:** → Phase E.

### Rate optimization — pay less for the same usage
| Lever | Best for | Trade-off |
|---|---|---|
| **Reservations** (1/3-yr) | steady, specific SKU/region (VMs, SQL, etc.) | least flexible; up to ~72% off; `CommitmentDiscountCategory=Usage` |
| **Savings Plans** (1/3-yr) | steady *compute spend*, flexible across SKU/region | more flexible, usually smaller discount; `=Spend` |
| **Spot** | interruptible / fault-tolerant (batch, dev, AKS spot pools) | can be evicted; `PricingCategory=Dynamic` |
| **Azure Hybrid Benefit** | existing Windows Server / SQL licenses w/ Software Assurance | licensing eligibility required |
- Targets: **coverage 60–85%** and **utilization >90%** for steady-state; measure with
  FinOps hub FOCUS queries (`sumif(EffectiveCost, PricingCategory=='Committed')`).
  Baseline established workloads before layering new commitments.
- **Sustainability:** **Azure Carbon Optimization** surfaces emissions alongside cost —
  the same idle/oversized resources are usually both the carbon and the cost waste.

---

## PHASE D — OPERATE: govern & bill back

- **Policy & governance (guardrails):** **Azure Policy** to `deny` disallowed SKUs,
  `require` cost tags, restrict regions, and enforce budgets via action groups —
  prevention beats cleanup (**WAF CO:04**). Prefer platform automation over manual gates.
- **Invoicing + chargeback:** progress **showback** (teams *see* their cost) →
  **chargeback** (teams are *billed*). Chargeback needs defensible allocation (Phase A)
  and shared-cost rules everyone agreed to.
- **Practice operations & cadence:** run FinOps as recurring iterations — define scope,
  set measurable goals, act, review. Use the **FinOps review assessment** to gauge
  maturity (**Crawl / Walk / Run**) per capability and pick the next iteration.
- **Education & onboarding:** new teams inherit tags, budgets, and policies by default.

---

## PHASE E — Kubernetes / AKS container cost

A shared AKS cluster is one bill hiding many tenants. Split it fairly:

- **Cost dimensions:** **allocated** (a namespace/pod's requests × node rate),
  **idle/unused** (node capacity nobody requested — a *cluster*, not tenant, cost),
  and **shared** (control plane, system pods, egress). Decide up front who eats idle
  (usually the platform team, as an efficiency KPI) vs. proportional split.
- **Showback basis:** allocate by **`requests`** (what a tenant reserved) — usually
  fairer than usage, since requests are what block the scheduler. Track requests-vs-usage
  to expose over-request waste.
- **Tooling:** **AKS Cost Analysis** add-on (Cost Management, namespace granularity);
  the **OpenCost / Kubecost** archetype for in-cluster allocation; **Spot node pools**
  for interruptible workloads; tag node pools for allocation.
- **Efficiency KPIs:** cluster utilization (requests ÷ capacity), idle %, cost per
  namespace / per tenant.
- **Boundary:** node *right-sizing / just-in-time provisioning* (Karpenter / NAP) →
  `karpenter-operations`; generic requests-limits / HPA capacity → `kubernetes-operations`.
  This phase owns the **cost split**, not the autoscaler.

---

## PHASE F — AI / GenAI cost (Azure OpenAI, GPU)

AI workloads break classic FinOps assumptions — cost is per **token** and per **GPU
hour**, and demand is spiky. Treat it as its own unit-economics problem:

- **Rate model:** **Provisioned Throughput Units (PTUs)** — reserved, predictable
  throughput, commitment-priced — for steady high-volume; **pay-as-you-go** (per-token)
  for variable/low volume. Model the crossover before committing PTUs (same "usage
  before rate" rule as Phase C).
- **Unit economics:** track **cost per 1K tokens**, **cost per inference/request**,
  and **cost per business outcome** (per summary, per agent task). Attribute token
  spend to features/tenants via deployment + tags.
- **Usage levers:** right-size the model (don't call a frontier model where a small one
  suffices), cap `max_tokens`, cache/reuse embeddings, batch, and set **spending
  quotas** per deployment. GPU VMs for self-hosted models: Spot for training/batch,
  deallocate idle, and reserve only proven-steady capacity.
- **Governance:** budgets + anomaly alerts scoped to Azure OpenAI resources — token
  spikes are the new "left a VM running."

---

## ANTI-PATTERNS (each one bites)

| Anti-pattern | Why it breaks | Do instead |
|---|---|---|
| Optimizing before allocating | can't attribute or justify any change | tags + hierarchy to ≥90% allocatable first |
| Buying reservations before rightsizing | locks in over-provisioned baseline 1–3 yrs | fix usage, *then* commit to the right size |
| Treating FinOps as "spend less" | starves the business; cuts value with cost | optimize **unit cost / value**, not raw $ |
| Stopping VMs instead of deallocating | stopped ≠ deallocated → still billing compute | deallocate via API; automate dev/test shutdown |
| Chasing savings by hand, monthly | waste re-accretes; no coverage of the estate | Advisor + ARG + Policy guardrails, daily data |
| Month-end-only cost reports | anomalies caught weeks late | daily FOCUS exports + anomaly alerts (24h) |
| 100% reservation coverage | pays for idle when usage dips | target 60–85% coverage, >90% utilization |
| Manual review gates for every deploy | slow, bypassed, doesn't scale | Azure Policy: require-tag / deny-SKU guardrails |
| Splitting AKS cost by usage only | ignores idle + reserved requests | allocate by requests; assign idle to platform |
| Agent auto-deletes "waste" | a "0-byte orphan" may be a DR/staging asset | find read-only; delete via approved gated change |
| Pinning a FOCUS/toolkit version in guidance | breaks as spec/toolkit ships monthly | describe behavior; verify against Learn/FOCUS |

---

## PRE-DONE VERIFICATION CHECKLIST

**Inform**
- [ ] Cost Management **exports in FOCUS** landing daily; eng + finance read the same data.
- [ ] **≥90% allocatable spend**; required cost tags enforced by policy; <5% untagged.
- [ ] Anomaly detection on; alerts routed to owners, reviewed ≤24h.

**Quantify**
- [ ] Budgets at MG/sub/RG with action groups at real thresholds.
- [ ] Forecast reviewed monthly; variance tracked toward ±15%.
- [ ] At least one **unit-economics** metric defined and baselined.

**Optimize**
- [ ] Rightsizing + waste (Advisor + ARG) triaged; changes gated, owner-confirmed.
- [ ] Commitments sized **after** usage fixes; coverage 60–85%, utilization >90%.
- [ ] AHB applied where eligible; Spot used for interruptible workloads.

**Operate**
- [ ] Azure Policy guardrails (require-tag, deny-SKU, budgets) in place.
- [ ] Showback (→ chargeback) live with agreed shared-cost rules.
- [ ] Maturity assessed per capability; next iteration scoped (3–5 capabilities).

**Doctrine**
- [ ] No version pinned in prose; behavior verified against Microsoft Learn + FOCUS.
- [ ] Every spend/delete action is a gated, reversible, human-approved change.

---

## REFERENCE

### WAF Cost Optimization — 5 principles → CO:01–CO:14
Principles: *Develop cost-management discipline · Design with a cost-efficiency mindset
· Design for usage optimization · Design for rate optimization · Monitor and optimize
over time.* Checklist: **CO:01** culture of financial responsibility · **CO:02** cost
model · **CO:03** collect + review cost data · **CO:04** spending guardrails · **CO:05**
get best rates · **CO:06** align usage to billing increments · **CO:07** optimize
component costs · **CO:08** optimize environment costs · **CO:09** flow costs · **CO:10**
data costs · **CO:11** code costs · **CO:12** scaling costs · **CO:13** personnel time ·
**CO:14** consolidate resources.

### KPI targets (steady-state)
Allocatable spend **≥90%** · tag compliance **>95%** (missing <5%) · anomaly triage
**≤24h** · forecast variance **±15%** · commitment **coverage 60–85%** · commitment
**utilization >90%** · waste **<10%** of spend.

### FinOps toolkit (open-source, Microsoft)
**FinOps hubs** (scalable FOCUS cost reporting) · **Power BI reports** · **FinOps
workbooks** (Cost optimization + Governance) · **Azure Optimization Engine** (custom
recommendations) · **PowerShell** + **Bicep Registry** modules · **open data** (pricing
units, regions, resource types, services). Feeds from Cost Management **FOCUS exports**.

### Azure tool map (one line)
Cost Management (analysis / exports / budgets / anomaly / forecast) · Advisor (cost recs)
· Azure Resource Graph KQL (waste/inventory) · Azure Policy (guardrails) · Carbon
Optimization (emissions) · Pricing calculator + Retail Prices API (estimates) · FinOps
toolkit (hubs/Power BI/AOE).

### Read-only triage scripts (`tools/`)
`azure-cost-summary.sh` (top spend by service / RG / subscription over a period) ·
`azure-waste-finder.sh` (ARG KQL: stopped-not-deallocated VMs, unattached disks / NICs /
public IPs, empty RGs, aged snapshots) · `azure-commitment-coverage.sh` (Advisor cost
recommendations + reservation/SP signals + AHB gaps).

---

## MCP SURFACE (read-only)

There is **no official FinOps MCP server — do not wire a fabricated one.** Drive
existing, guardrailed servers **read-only**, per the blast-radius doctrine in
`agentic-k8s-ops`:

| Server | Use | Guardrail |
|---|---|---|
| **Azure MCP Server** (`azure-mcp`) | Cost Management queries, **Azure Resource Graph** (waste/inventory), Advisor, budgets/subscriptions read | **Entra RBAC** — grant *Cost Management Reader* + *Reader*; no Contributor |
| **kubernetes-mcp-server** (`--read-only`) | AKS namespace/pod requests for container cost split (Phase E) | `--read-only` |
| **GitHub / ADO MCP** (read toolsets) | open the **gated PR** that actually buys/deletes/rightsizes | scoped token; PR is the approval gate |

Default-deny writes. **Cost analysis, waste-finding, and coverage checks are read-only;
buying a reservation, deleting a disk, resizing a VM, or setting a policy is a gated,
reversible, human-approved change** (IaC PR / change ticket) — never an autonomous agent
mutation. A wrong "delete this orphan" can destroy a DR asset; a wrong 3-year reservation
is money you can't get back. Keep the agent read-mostly and put a human on every buy/delete.

---

## SUBAGENT ORCHESTRATION

This skill drives a **5-agent Azure FinOps team** in `.claude/agents/`:

| Agent | Owns |
|---|---|
| `finops-cost-allocator` | Inform — FOCUS exports/ingestion, tag strategy + MG/subscription hierarchy, showback split, reporting; the **allocatable-spend** metric |
| `finops-budget-forecaster` | Quantify — budgets + action groups, forecasting (±15%), planning/estimating, **unit economics** (incl. AI cost/token), anomaly management |
| `finops-usage-optimizer` | Optimize (usage) — rightsizing, Advisor, waste cleanup (ARG), autoscale/scheduling, storage tiering, **AKS container cost split**; owns `azure-waste-finder.sh` |
| `finops-rate-optimizer` | Optimize (rate) — Reservations vs Savings Plans vs Spot, **Azure Hybrid Benefit**, coverage/utilization targets; owns `azure-commitment-coverage.sh` |
| `finops-governance-lead` | Operate — Azure Policy guardrails (require-tag/deny-SKU/budgets), chargeback, practice cadence, maturity assessment |

**Handoffs:** pricing-API reads → `azure-retail-prices`; KQL engine mechanics →
`kusto-kql-api`; AKS node autoscaling → `karpenter-operations` / `kubernetes-operations`;
incident-driven spikes + agentic remediation doctrine → `azure-sre-agent` /
`agentic-k8s-ops`.
