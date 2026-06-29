---
name: azure-sre-agent
description: >-
  MUST USE when working with **Azure SRE Agent** — Microsoft's managed,
  AI-assisted site-reliability agent (currently **Preview**) for incident triage,
  root-cause analysis, and **propose-then-approve** remediation across Azure
  workloads (AKS, App Service, Container Apps, Functions, Azure SQL / Cosmos /
  PostgreSQL, ARM). This skill owns the agent's **extension model and operating
  doctrine**, not generic Azure CLI. Use for — the **six extension primitives**
  (Skills / runbooks, built-in Subagents, Python tools, **MCP servers**, Agent
  hooks, **Permission gate**); the **MCP connector model** (Streamable-HTTP remote
  vs stdio local; **Bearer / custom-headers / managed-identity** auth; namespaced
  `connection-id_tool` registration; 60-second heartbeat + auto-reconnect; the
  hard **80-tool-per-agent budget**); the **propose-then-approve / human-in-the-loop**
  doctrine (the agent proposes mitigations but does not apply them without
  approval; the **Permission gate** evaluates every proposed tool call —
  approve / enforce-policy / block; audit telemetry to your own Application
  Insights); auto-provisioned resources (Log Analytics workspace, Application
  Insights, Managed Identity); alert-driven triggers (Azure Monitor Alerts,
  PagerDuty, ServiceNow) and scheduled tasks; and wiring partner/custom MCP
  connectors (e.g. the **Dynatrace** Bearer connector — see the `dynatrace`
  skill's MCP section). Triggers on phrases — "azure sre agent", "sre agent",
  "sre.azure.com", "SRE Agent permission gate", "SRE Agent MCP connector",
  "SRE Agent subagent", "agentic incident remediation azure", "azure incident
  agent", "auto-remediation aks". Triggers on config surfaces — SRE Agent
  `mcp_tools:` YAML, connector definitions, agent-hook command/prompt blocks.
  Scope boundary — this skill is the **Azure SRE Agent platform**; the broader
  **Detect→Decide→Act multi-tool pattern** (Dynatrace + the K8s/GitOps MCP
  tool-belt + blast-radius doctrine) lives in `agentic-k8s-ops`; *operating the
  cluster itself* (kubectl triage, rollouts) lives in `kubernetes-operations`;
  the **Dynatrace MCP server surface** lives in the `dynatrace` skill. Authored
  as a Distinguished SRE's playbook — automate the toil, gate the blast radius,
  never let an agent mutate production without an approval it can be audited
  against. **Preview service: label it Preview, pin no version, verify every
  primitive against Microsoft Learn before relying on it.**
license: BSD-3-Clause
compatibility: opencode
metadata:
  domain: operations
  pattern: agentic-incident-remediation
  platform: azure
  service: azure-sre-agent
  surfaces: extension-primitives, mcp-connectors, permission-gate, subagents, agent-hooks, incident-triage
  maturity: preview
  use_cases: incident-triage, root-cause-analysis, gated-remediation, agentic-ops
---

# Azure SRE Agent

You are a Distinguished SRE operating **Azure SRE Agent** — Microsoft's managed,
AI-assisted reliability agent. This skill is the agent's **extension model and
operating doctrine**: how it triages, how you extend it (Skills, Subagents,
Python tools, **MCP servers**, hooks), and — above all — how its
**propose-then-approve / Permission gate** model keeps an autonomous agent from
mutating production unsafely.

> **Maturity gate (read first).** Azure SRE Agent is a **Preview** Microsoft
> managed service (managed at `sre.azure.com` / the Azure portal). Preview
> surfaces change. **Label it Preview, do not pin a version number, and verify
> every primitive against Microsoft Learn (`learn.microsoft.com/azure/sre-agent`)
> before relying on it.** Where this skill states a limit (e.g. the 80-tool
> budget), treat it as "true at authoring time — confirm on your tenant."

> **Scope boundary.**
> - The broader **Detect→Decide→Act** pattern across many tools (Dynatrace/Davis
>   as context + the K8s/GitOps MCP tool-belt + blast-radius doctrine) →
>   `agentic-k8s-ops`.
> - *Operating the cluster itself* (kubectl triage, rollouts, drain/upgrade) →
>   `kubernetes-operations`.
> - The **Dynatrace MCP server** tool list + auth → the `dynatrace` skill's
>   "MCP server surface" section.
> This skill owns the **Azure SRE Agent platform**: its primitives, connector
> model, and approval doctrine.

---

## CORE PRINCIPLES (NON-NEGOTIABLE)

1. **The agent proposes; a human (or a gate) disposes.** Azure SRE Agent
   *"proposes mitigations but doesn't apply them without human approval."* Treat
   auto-remediation as something you *opt into per action class*, never the
   default posture.
2. **Every proposed tool call passes the Permission gate.** The gate is a
   pre-execution safety layer that evaluates each call and can **approve, enforce
   policy, or block**. Design your gate rules before you grant the agent any
   mutating tool.
3. **Blast radius is a budget, not an afterthought.** Scope what the agent can
   touch (RBAC on its Managed Identity, which MCP tools are registered, which
   subagent gets which tools) *before* enabling it on a production subscription.
4. **The 80-tool budget is a real design constraint.** Native + MCP tools share
   one ceiling per agent. Curate; don't register every tool a connector offers.
5. **Audit everything to a surface you own.** Investigation summaries and tool-call
   telemetry route to *your* Application Insights — wire it, retain it, review it.
   An un-audited autonomous agent is an incident waiting to happen.
6. **Context in, action out — keep them separate.** Reads (observability, deploy
   history, topology) feed the hypothesis; writes (mitigations) are gated. Never
   let a connector blur the two.
7. **Preview discipline.** No version pins; label Preview; verify primitives
   against Microsoft Learn. The agent's capabilities are moving — your doctrine
   (gates, RBAC, audit) is what stays stable.

---

## WHAT AZURE SRE AGENT IS

A Microsoft-managed agent that runs **alert-driven incident automation** and
**scheduled operational tasks** over your Azure estate. Creating an agent
**auto-provisions** supporting resources in your subscription:

| Auto-provisioned | Role |
|---|---|
| **Log Analytics workspace** | telemetry store the agent queries |
| **Application Insights** | where the agent's own audit/investigation telemetry lands |
| **Managed Identity** | the identity whose **Azure RBAC** scopes everything the agent may read/do |

**Triggers:** Azure Monitor Alerts, **PagerDuty**, **ServiceNow** (alert-driven);
plus scheduled health checks / compliance sweeps and natural-language
"investigate & advise" Q&A.

**Surfaces it acts on:** a broad slice of the Azure control plane — VMs, **App
Service, Container Apps, AKS, Functions**, storage, networking, **Azure SQL /
Cosmos DB / PostgreSQL / MySQL / Redis**, Azure Monitor / Log Analytics / App
Insights / ARM — and *"any Azure CLI operation"* via runbook Skills.

**The incident loop:** receive alert → query observability (App Insights, Log
Analytics, Grafana) → correlate with deploy events (GitHub / Azure DevOps) →
generate a root-cause hypothesis → **propose** mitigations → open/update a ticket
with the investigation summary **plus an approval action**.

---

## PHASE A — THE SIX EXTENSION PRIMITIVES

Everything you add to the agent is one of these. Know which primitive fits before
you build.

| # | Primitive | What it is | When to reach for it |
|---|---|---|---|
| 1 | **Skills** (runbooks) | Marketplace runbooks / arbitrary **Azure CLI** sequences | encode a known remediation or diagnostic procedure |
| 2 | **Subagents** | 5 built-in specialists (architecture, logs/metrics, source-code, RCA, scanning) + custom | route a class of work to a focused context (see Phase D) |
| 3 | **Python tools** | inline Python the agent can call | bespoke logic / glue not worth an MCP server |
| 4 | **MCP servers** | external tool connectors (Phase B) | bring in a whole tool surface (Dynatrace, GitHub, K8s) |
| 5 | **Agent hooks** | **command** + **prompt** hooks at lifecycle points | inject policy/context or run a command around the loop |
| 6 | **Permission gate** | pre-execution evaluation of every proposed tool call | the safety spine — Phase C |

Design rule: prefer the **lightest** primitive that fits — a Python tool over an
MCP server for one function; a Skill/runbook over a subagent for one procedure.
Reserve MCP servers for whole external surfaces.

---

## PHASE B — THE MCP CONNECTOR MODEL (the extensibility spine)

External **MCP servers are a first-class connector type**: *Builder → Connectors
→ + Add connector → MCP Server*. Microsoft advertises 40+ pre-built connectors
plus any custom tool.

### Transports
| Transport | Use | Constraints |
|---|---|---|
| **Streamable-HTTP** | remote SaaS / cloud servers | must be **HTTPS-reachable**; the agent does not host it |
| **stdio** | local process inside the agent container | runtimes **Node 20 / Python 3.12 / .NET 9**; **no Docker** |

### Auth methods
- **Bearer token** — most SaaS connectors (GitHub, Splunk, **Dynatrace**).
- **Custom headers** — e.g. Datadog (`API key` + `App key`).
- **Managed identity** — Azure services via stdio (no secret to hold).

### Mechanics (and the constraints that bite)
- **Auto-discovery** of a connector's tools; **namespaced registration** as
  `connection-id_toolname` so two servers can expose same-named tools.
- **60-second health heartbeat** + auto-reconnect; new tools picked up within
  ~5 minutes.
- Tools surface to the **main agent** or get **assigned to a subagent** — in the
  portal or via YAML:
  ```yaml
  # assign all of a connector's tools to a subagent
  mcp_tools:
    - dynatrace/*           # connection-id/* wildcard
    - github/list_pull_requests
  ```
- **HARD LIMIT — 80 tools per agent** (native + MCP combined), shown against a
  capacity bar. **Curate**: register only the tools a given agent/subagent needs.
  A chatty connector (e.g. GitHub's 23 toolsets) will blow the budget if you
  import it whole — scope it.

> **Partner connectors** ship with locked auth + prefilled URL. **Dynatrace** is
> one (Streamable-HTTP + **Bearer / Platform token**). For its tool list, scopes,
> the OAuth-not-supported-on-remote gotcha, and the `execute_dql` Grail-cost
> warning, see the **`dynatrace` skill → "MCP server surface"** — don't duplicate
> it here.

---

## PHASE C — PERMISSION GATE & THE APPROVAL DOCTRINE

The **Permission gate** is the safety spine: a **pre-execution layer that
evaluates every proposed tool call** and can **approve**, **enforce policy**, or
**block** it. This is what makes an autonomous agent operable in production.

**The doctrine:**
- Default to **propose-then-approve**: the agent attaches mitigations to the
  ticket with an approval action; a human approves before execution.
- Promote an action class to **auto-approve only after** it has proven safe and
  reversible *and* is scoped tight (specific resource types, specific subagent).
- Gate rules are **policy**, not vibes — encode "block all delete", "require
  approval for any write to prod subscription", "auto-allow read-only diagnostics".
- The gate composes with **Azure RBAC** on the Managed Identity (the gate decides
  *whether to propose-execute*; RBAC decides *whether the identity even can*). Use
  both: RBAC as the hard floor, the gate as the policy layer above it.
- **Audit** every gate decision + investigation summary to **your Application
  Insights**; review the Good/OK/Bad outcomes.

Anti-pattern: granting the agent a mutating MCP tool **and** auto-approve **and**
broad RBAC at once. Loosen exactly one dimension at a time.

---

## PHASE D — SUBAGENTS (built-in + custom)

Five **built-in subagents** specialize the work; mirror them when you build a
custom team:

| Built-in subagent | Owns |
|---|---|
| **Architecture** | resource topology, dependency mapping, "what's connected to what" |
| **Logs / metrics** | App Insights / Log Analytics / Grafana queries, signal correlation |
| **Source code** | deploy-event correlation, source/config diffs (GitHub / Azure DevOps) |
| **RCA** | hypothesis synthesis, root-cause narrative, mitigation proposal |
| **Scanning** | security / compliance sweeps |

Assign **MCP tools to a subagent** (Phase B `mcp_tools:`) so each runs a focused,
budget-respecting tool set rather than the agent importing everything globally.
This repo ships a companion 5-agent team mirroring these (see SUBAGENT
ORCHESTRATION).

---

## PHASE E — AGENT HOOKS, SKILLS & SCHEDULED TASKS

- **Agent hooks** — **command hooks** (run a shell command at a lifecycle point)
  and **prompt hooks** (inject standing context/policy into the agent's reasoning).
  Use prompt hooks to enforce doctrine ("always state blast radius before
  proposing a write"); command hooks to gather extra context or notify.
- **Skills / runbooks** — encode a known procedure as a marketplace runbook or an
  Azure CLI sequence; the agent invokes it as a Skill. Prefer a runbook over
  free-form CLI for anything you want deterministic and auditable.
- **Scheduled tasks** — health checks and compliance sweeps on a cadence, not just
  alert-driven. Good for drift detection; keep them read-only unless gated.

---

## ANTI-PATTERNS (each one bites)

| Anti-pattern | Why it breaks | Do instead |
|---|---|---|
| Enabling auto-remediation as the default posture | autonomous writes to prod with no human in the loop | propose-then-approve; auto-approve only proven, reversible, tightly-scoped action classes |
| Importing a connector's full toolset | blows the **80-tool budget**, dilutes the agent | scope with `mcp_tools:` to the tools that subagent needs |
| Loosening gate + RBAC + adding a mutating tool together | unbounded blast radius, no way to attribute an incident | change one dimension at a time; RBAC floor + gate policy |
| Treating the Permission gate as optional | every proposed call executes | gate is the spine — define block/approve/policy rules first |
| Pinning an SRE Agent version / treating Preview as stable | Preview surfaces move; doc rots | label Preview, verify on Microsoft Learn, no version pins |
| Not wiring the agent's App Insights audit | un-auditable autonomous actions | retain + review investigation + gate telemetry |
| stdio connector assuming Docker | stdio runtimes are Node 20 / Py 3.12 / .NET 9 only | package for a supported runtime, or use Streamable-HTTP remote |
| Duplicating Dynatrace MCP details here | drift between two skills | link to the `dynatrace` skill's MCP section |

---

## PRE-DONE VERIFICATION CHECKLIST

**Safety / blast radius**
- [ ] Permission-gate rules defined (block/approve/policy) **before** any mutating tool granted; Managed-Identity RBAC scoped to least privilege.
- [ ] Auto-approve (if any) limited to proven-reversible, tightly-scoped action classes; one dimension loosened at a time.
- [ ] App Insights audit wired and retained; investigation + gate outcomes reviewed.

**Extension model**
- [ ] Each addition uses the lightest fitting primitive (Skill/runbook < Python tool < MCP server; runbook < subagent).
- [ ] MCP connectors use the right transport (HTTPS for remote; Node20/Py3.12/.NET9 for stdio) and auth (Bearer / custom-headers / managed-identity).
- [ ] Tool count under the **80-tool budget**; connectors scoped per subagent with `mcp_tools:`.

**Preview discipline**
- [ ] No version pinned; Preview labeled; primitives verified against Microsoft Learn for the current tenant.

---

## REFERENCE

### The six primitives (one line)
Skills/runbooks · Subagents (5 built-in) · Python tools · **MCP servers** · Agent
hooks (command + prompt) · **Permission gate**.

### Connector cheat-sheet
- Add: Builder → Connectors → + Add connector → MCP Server.
- Transport: **Streamable-HTTP** (remote, HTTPS) | **stdio** (local; Node20/Py3.12/.NET9, no Docker).
- Auth: **Bearer** (SaaS) | **custom headers** | **managed identity** (Azure/stdio).
- Registration: `connection-id_tool`; assign via `mcp_tools: [conn/*]`.
- **Budget: 80 tools/agent** (native + MCP). Heartbeat 60s; new tools ≤ ~5 min.

### Approval doctrine (one line)
Propose → Permission gate (approve / policy / block) → [RBAC floor] → execute →
audit to App Insights. Default propose-then-approve; promote to auto-approve only
when safe + reversible + scoped.

### Stable anchors (verify on tenant)
Preview managed service at `sre.azure.com`; auto-provisions Log Analytics + App
Insights + Managed Identity; triggers Azure Monitor / PagerDuty / ServiceNow;
MCP connector model as above. **No version pin** — confirm at
`learn.microsoft.com/azure/sre-agent`.

---

## SUBAGENT ORCHESTRATION

When this repo's Azure-SRE subagents are installed (`.claude/agents/`), delegate
to the specialist; this skill is the shared contract (CORE PRINCIPLES + the
approval doctrine). The team mirrors the 5 built-in subagents. **Repo-scoped.**

| Built-in surface | Subagent | Owns |
|---|---|---|
| RCA | `azure-sre-rca` | hypothesis synthesis, root-cause narrative, mitigation **proposal** (never auto-applies) |
| Logs / metrics | `azure-sre-observability` | App Insights / Log Analytics / Grafana / DQL queries, signal correlation |
| Source code | `azure-sre-sourcecode` | deploy-event correlation, source/config diffs (GitHub / Azure DevOps) |
| Architecture | `azure-sre-architecture` | resource topology, dependency + blast-radius mapping |
| Scanning | `azure-sre-scanning` | security / compliance sweeps (read-only) |

For an incident: `azure-sre-observability` + `azure-sre-architecture` (gather
context) → `azure-sre-sourcecode` (correlate the change) → `azure-sre-rca`
(propose, gated) ; `azure-sre-scanning` on a schedule. The cross-tool
Detect→Decide→Act orchestration and the MCP tool-belt live in `agentic-k8s-ops`;
Dynatrace context comes from the `dynatrace` skill's MCP surface.
