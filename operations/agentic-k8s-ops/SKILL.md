---
name: agentic-k8s-ops
description: >-
  MUST USE when designing or operating an **AI-assisted (agentic) SRE workflow for
  Kubernetes on Azure** — the cross-tool **Detect → Decide → Act** pattern and the
  **MCP tool-belt** an agent drives to investigate and (gated) remediate. This is
  the umbrella playbook that ties the pieces together; it does not replace the
  single-tool skills. Use for — the **Detect→Decide→Act** architecture (observability
  / causal RCA as the **Detect** layer → an agent triages and pulls more context as
  the **Decide** layer → change lands as a **gated** GitHub PR or Azure runbook as
  the **Act** layer, always behind a **human approval gate**); the **blast-radius
  doctrine** for letting an agent touch a cluster (prefer **read-only** modes,
  scope toolsets, least-privilege tokens, the tool-count budget, one-dimension-at-a-time
  loosening); and the **credible MCP tool-belt** with each server's read/write
  posture and guardrail — **containers/kubernetes-mcp-server** (`--read-only` /
  `--disable-destructive`), **argoproj-labs/mcp-for-argocd** (`MCP_READ_ONLY=true`),
  **github/github-mcp-server** (`--read-only` / `--toolsets` / `--tools`),
  **Azure MCP Server** (RBAC + Entra / managed identity), **k8sgpt** (`serve --mcp`,
  read-only diagnosis), **trivy-mcp** (read-only scan). Triggers on phrases —
  "agentic ops", "agentic sre", "ai sre workflow", "detect decide act", "kubernetes
  mcp server", "argocd mcp", "k8sgpt mcp", "trivy mcp", "mcp tool belt", "agent
  remediation kubernetes", "blast radius agent", "read-only mcp". Scope boundary —
  the **Azure SRE Agent platform** (its primitives, connector model, Permission
  gate) lives in `azure-sre-agent`; the **Dynatrace MCP server** tool list + auth
  lives in the `dynatrace` skill; **operating the cluster by hand** (kubectl triage,
  rollouts, drain) lives in `kubernetes-operations`; **security strategy** in
  `kubernetes-security`; **wiring MCP into a harness generally** in `create-harness`.
  This skill owns the **pattern + the tool-belt selection + the blast-radius
  doctrine**. Authored as a Distinguished SRE's playbook — give the agent the
  smallest read-mostly tool-belt that solves the incident, and make every write a
  gated, auditable, reversible PR. **Several referenced tools are Preview or
  community — label maturity, pin no versions, verify before trusting.**
license: BSD-3-Clause
compatibility: opencode
metadata:
  domain: operations
  pattern: agentic-sre-detect-decide-act
  platform: kubernetes-on-azure
  surfaces: detect-decide-act, mcp-tool-belt, blast-radius-doctrine, gitops-remediation
  use_cases: agentic-incident-response, mcp-server-selection, ai-assisted-ops
---

# Agentic Kubernetes Ops (AI-assisted SRE for K8s on Azure)

You are a Distinguished SRE designing an **AI-assisted operations workflow** for
Kubernetes on Azure. This is the **umbrella playbook**: the cross-tool
**Detect → Decide → Act** pattern, the **MCP tool-belt** an agent drives, and the
**blast-radius doctrine** that keeps a semi-autonomous agent safe in production.
It ties together the single-tool skills — it does not replace them.

> **Scope boundary.**
> - **Azure SRE Agent** as a platform (primitives, connector model, Permission
>   gate) → `azure-sre-agent`.
> - **Dynatrace MCP server** (tool list, Platform-token auth, Grail-cost) → the
>   `dynatrace` skill's "MCP server surface".
> - **Operating the cluster by hand** (kubectl triage, rollouts, drain/upgrade) →
>   `kubernetes-operations`.
> - **Security strategy** (zero-trust, threat model) → `kubernetes-security`;
>   **networking mechanics** → `kubernetes-networking`.
> - **Wiring MCP into a harness in general** → `create-harness`.
> This skill owns the **pattern, the tool-belt selection, and the doctrine**.

> **Maturity gate.** This space moves fast and mixes maturity levels. **Azure SRE
> Agent is Preview**; the Dynatrace **"Cloud SRE Agents" multicloud router is
> community-supported and NOT GA**; vendor MTTR-reduction figures are marketing —
> do not cite them as fact. Label maturity, pin no versions, verify each tool's
> current capabilities and flags before trusting them.

---

## CORE PRINCIPLES (NON-NEGOTIABLE)

1. **Read-mostly by default.** An agent investigating an incident needs reads, not
   writes. Give it the smallest **read-only** tool-belt that can form a hypothesis;
   add a write tool only for a specific, justified remediation.
2. **Every write is a gated, reversible PR — never a direct mutation.** The **Act**
   step should land as a GitOps change (a PR ArgoCD reconciles) or an audited
   runbook behind a human approval gate, not an agent running `kubectl delete`.
3. **Blast radius is budgeted explicitly.** Scope tokens, toolsets, and tool counts
   *before* connecting an agent to production. Loosen exactly **one** dimension at
   a time (a read-only flag off, a token scope up, a new write tool) and observe.
4. **Detect, Decide, and Act are different trust levels.** Detect (observability)
   and Decide (triage/RCA) are read-heavy and low-risk; Act (mutation) is the only
   place that needs a gate. Keep them architecturally distinct.
5. **Prefer first-party, clearly-licensed, guardrailed servers.** A server with a
   `--read-only` mode, a real owner, and a clear license beats a feature-richer one
   without them. An unverifiable or auto-generated tool is a security liability.
6. **Maturity is part of the design.** Treat Preview/community pieces as
   experiments with explicit caveats, not load-bearing production dependencies.
7. **Audit the agent like a privileged user.** Every tool call — especially writes —
   must be attributable and retained. An un-audited agent action is an
   un-investigable incident.

---

## THE DETECT → DECIDE → ACT PATTERN

The reference architecture for agentic incident response. Three layers, three
trust levels:

| Layer | Role | Typical tools | Trust |
|---|---|---|---|
| **Detect** | surface the problem + causal context, blast-radius/impact | Dynatrace / **Davis AI** (causal RCA, topology), Azure Monitor, k8sgpt analysis, Prometheus | read-only |
| **Decide** | triage, correlate with deploys, form a root-cause hypothesis, **propose** a fix | the agent (Azure SRE Agent / HolmesGPT-style) pulling more context via MCP | read-heavy |
| **Act** | apply the fix — **gated** | GitHub PR (Copilot) that ArgoCD reconciles, or an Azure runbook | **human-gated write** |

**The flow:** Detect raises a causally-scoped problem → the agent (Decide) queries
observability + deploy history + topology, narrows root cause, and **proposes** a
remediation → the fix lands as a **PR or runbook** that a human approves (Act) →
ArgoCD/Azure executes it → audit the whole chain.

- **Davis AI** = deterministic, causation-based RCA + topology (the *why* and the
  *blast radius*); **Davis CoPilot** = NL→DQL and conversational analysis. Pull
  both via the Dynatrace MCP server (see the `dynatrace` skill).
- **HolmesGPT** (CNCF Sandbox, Apache-2.0, **read-only by default**, optional
  opt-in remediation MCP toolset) is the open archetype of the Decide-layer agent
  — reference it as the pattern; this repo's own subagents play the same role.

> **The multicloud router (caveat).** Dynatrace's **"Cloud SRE Agents"** app routes
> problems (by category / entity / cloud account / tags / **budget**) to parallel
> hyperscaler agents (AWS DevOps Agent, **Azure SRE Agent**, Google Gemini Cloud
> Assist) with a unified audit trail and per-agent duration budgets. It is
> **community-supported and NOT GA** — document it as a forward pattern, not a
> stable dependency.

---

## THE MCP TOOL-BELT (credible servers + guardrails)

The vetted set for **K8s on Azure + ArgoCD + Helm + GitHub**. For each: what it's
for, its **read/write posture and guardrail**, and its auth. Register the
**minimum** per agent (mind any host's tool budget — e.g. Azure SRE Agent's
80-tool ceiling).

### HIGH priority — the core trio
- **containers/kubernetes-mcp-server** (Red Hat `containers`, Apache-2.0) — the K8s
  workhorse: inspect **and** mutate any resource, pod ops (logs/exec/top), plus a
  **Helm** toolset that can actually `install`/`uninstall`. **Mutating by default**
  — gate it with **`--read-only`** (blocks create/update/delete) or
  **`--disable-destructive`** (blocks delete/update, allows create). Auth:
  kubeconfig / in-cluster service account; optional OIDC in HTTP mode.
- **argoproj-labs/mcp-for-argocd** (Argoproj Labs, Apache-2.0) — the GitOps control
  plane: list/get apps, **sync**, resource tree, workload logs, run resource
  actions. **Mutating by default** — set **`MCP_READ_ONLY=true`** to disable the
  five write tools (create/update/delete/sync/run-action). Auth: `ARGOCD_API_TOKEN`
  + `ARGOCD_BASE_URL` (tokens kept out of tool args by design — anti-prompt-injection).
- **github/github-mcp-server** (GitHub official, MIT) — the Git source of truth for
  GitOps and the **Act**-layer PR surface. 20+ toolsets. **Both read and write** —
  strong guardrails: **`--read-only`**, **`--toolsets`** (limit domains),
  **`--tools`** (per-tool allow-list). Scope to `repos` / `pull_requests` /
  `actions`. Auth: OAuth (hosted remote) or PAT.

### MEDIUM priority — cloud + diagnostics
- **Azure MCP Server** (Microsoft official) — the Azure control plane under AKS:
  resource queries, **KQL** on Log Analytics, diagnostics, azd deploys. **Mutating**;
  the guardrail is **Azure RBAC** + **Entra ID / managed identity** ("tool
  availability reflects your subscription permissions") — no global read-only flag,
  so RBAC *is* the boundary. Best for cloud-resource + AKS-provisioning context;
  in-cluster object work is better served by kubernetes-mcp-server.
- **k8sgpt `serve --mcp`** (k8sgpt-ai, Apache-2.0) — **read-only** cluster diagnosis
  (14+ analyzers; runs with or without an LLM). A clean Detect-layer tool; also a
  fine standalone CLI. No mutation.
- **trivy-mcp** (Aqua official, MIT) — **read-only** vuln + misconfig scanning as MCP
  tools (`trivy plugin install mcp`). Complements `kubernetes-security` prose with a
  live scan surface; no enforcement/blocking. Auth: local; optional Aqua Platform login.

### Selection rules
- Start every agent **read-only**: kubernetes-mcp-server `--read-only`, mcp-for-argocd
  `MCP_READ_ONLY=true`, github `--read-only`, plus k8sgpt + trivy (already read-only).
- Add a write capability only for a **specific** remediation, scoped to the
  narrowest toolset, behind the host's approval gate.
- **Budget the tool count** — don't import a server's full surface (GitHub alone is
  20+ toolsets). Use `--toolsets` / `--tools` / `mcp_tools:` wildcards to stay lean.

### Skip / caution (already covered or unverifiable)
`Keep` (heavy standalone AIOps platform, not an agent-driven tool) · `lens-mcp`
(undisclosed license + vendor-account coupling) · `azure-devops-mcp` (only if you
run ADO; GitHub-centric stacks skip it) · **jithinjk eBPF MCP (source repo 404s —
do not wire a security tool with no verifiable source)** · **Calico mcpmarket
"skill"** (auto-generated marketplace listing, not first-party) — and the last two
are already covered by `kubernetes-security` + `kubernetes-networking`.

---

## BLAST-RADIUS DOCTRINE

The non-negotiable safety frame for connecting an agent to a live cluster/cloud:

1. **Default-deny on writes.** Every server starts in its read-only mode. A write
   tool is an explicit, justified exception.
2. **Least-privilege identity.** The token/identity the agent uses (kubeconfig RBAC,
   ArgoCD token scope, GitHub PAT scope, Azure RBAC on Managed Identity) is scoped
   to exactly what the workflow needs — nothing broader "for convenience".
3. **One dimension at a time.** Never simultaneously: turn off read-only **and**
   widen a token **and** add a destructive tool. Change one, observe, then the next.
4. **Writes are reversible + auditable.** Prefer GitOps PRs (revertable via git) and
   audited runbooks over imperative mutations. Wire the audit sink (App Insights,
   ArgoCD history, GitHub audit log) before enabling writes.
5. **Budget the tool surface.** Fewer tools = smaller attack/confusion surface and
   (on hosts like Azure SRE Agent) respects the tool ceiling.
6. **Human gate on Act.** The approval step is not optional for production mutation.

---

## ANTI-PATTERNS (each one bites)

| Anti-pattern | Why it breaks | Do instead |
|---|---|---|
| Giving the agent mutating servers without their read-only flags | one bad inference mutates prod | `--read-only` / `MCP_READ_ONLY=true` / `--toolsets`; writes are exceptions |
| Agent runs `kubectl delete` / direct mutation as the Act step | unreviewable, hard to revert | land Act as a gated GitHub PR (ArgoCD reconciles) or audited runbook |
| Importing a server's whole toolset | tool-budget blowout, confused agent | scope with `--tools` / `--toolsets` / `mcp_tools:` wildcards |
| Loosening read-only + token scope + adding a write tool together | unbounded, unattributable blast radius | one dimension at a time, observe between |
| Wiring an unverifiable/auto-generated MCP server | supply-chain + security liability | first-party, clearly-licensed, guardrailed servers only |
| Treating Preview/community pieces as stable | doc + dependency rot; surprise breakage | label maturity; experiments with caveats, not load-bearing |
| Citing vendor MTTR-reduction percentages as fact | marketing, not measurement | describe the pattern; measure your own MTTR |
| Duplicating Azure SRE Agent / Dynatrace specifics here | drift across skills | link to `azure-sre-agent` and the `dynatrace` MCP section |

---

## PRE-DONE VERIFICATION CHECKLIST

**Pattern**
- [ ] Detect / Decide / Act are architecturally distinct; only Act mutates, and only behind a human gate.
- [ ] Act lands as a reversible GitOps PR or audited runbook — no imperative agent mutations.

**Tool-belt**
- [ ] Every mutating server started in its read-only mode (`--read-only` / `MCP_READ_ONLY=true` / scoped `--toolsets`); writes are explicit exceptions.
- [ ] Identities least-privilege (kubeconfig RBAC, ArgoCD token, GitHub PAT, Azure RBAC); tool count budgeted; no unverifiable servers wired.

**Doctrine & maturity**
- [ ] One dimension loosened at a time; audit sink wired before any write.
- [ ] Preview/community pieces labeled; no version pins; no vendor MTTR claims stated as fact.

---

## REFERENCE

### Detect→Decide→Act (one line)
Detect (Dynatrace/Davis, Azure Monitor, k8sgpt — read) → Decide (agent triages +
proposes via MCP — read-heavy) → Act (gated GitHub PR / Azure runbook → ArgoCD/Azure
executes → audit).

### Tool-belt posture cheat-sheet
| Server | Default | Read-only guardrail |
|---|---|---|
| kubernetes-mcp-server | mutating | `--read-only` / `--disable-destructive` |
| mcp-for-argocd | mutating | `MCP_READ_ONLY=true` |
| github-mcp-server | both | `--read-only` / `--toolsets` / `--tools` |
| azure-mcp | mutating | Azure RBAC + managed identity (no flag) |
| k8sgpt `serve --mcp` | read-only | n/a |
| trivy-mcp | read-only | n/a |

### Blast-radius (one line)
Default-deny writes · least-privilege identity · one dimension at a time ·
reversible+audited Act · budget the tool surface · human gate.

### Maturity labels (verify)
Azure SRE Agent = **Preview** · Dynatrace "Cloud SRE Agents" multicloud router =
**community / not GA** · HolmesGPT = CNCF Sandbox · vendor MTTR figures = marketing.
Pin no versions.

---

## SUBAGENT ORCHESTRATION

This umbrella playbook coordinates the existing teams rather than shipping its own:
the **Detect** layer draws on the `dynatrace` team (Grail/Davis) and
`kubernetes-operations` triage; the **Decide** layer maps to the `azure-sre-agent`
team (RCA / observability / source-code / architecture / scanning); the **Act**
layer hands writes to gated GitHub PRs / ArgoCD. Security checks defer to
`kubernetes-security`; networking mechanics to `kubernetes-networking`; harness
plumbing to `create-harness`. Keep each tool's specifics in its own skill — this
one owns the pattern and the tool-belt selection.
