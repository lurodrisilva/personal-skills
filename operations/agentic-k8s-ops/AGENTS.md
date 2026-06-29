<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-29 | Updated: 2026-06-29 -->

# agentic-k8s-ops

## Purpose
Umbrella skill for **AI-assisted (agentic) SRE on Kubernetes/Azure** — the
cross-tool **Detect → Decide → Act** pattern, the credible **MCP tool-belt** an
agent drives, and the **blast-radius doctrine** for letting a semi-autonomous agent
touch production. Coordinates the single-tool skills rather than duplicating them.
Third skill in the `operations/` domain.

## Key Files
| File | Description |
|------|-------------|
| `SKILL.md` | The skill — `name: agentic-k8s-ops`, `domain: operations`, `platform: kubernetes-on-azure`, `pattern: agentic-sre-detect-decide-act` |

## Subdirectories
None.

## For AI Agents

### Working In This Directory
- Edit `SKILL.md` only. This is an **umbrella/pattern** skill — it must **link, not
  duplicate**. The hard rule: per-tool specifics live in their own skill.
  - Azure SRE Agent platform internals → `../azure-sre-agent/`.
  - Dynatrace MCP tool list + auth → `../../platform-engineering/dynatrace/`.
  - Hands-on cluster ops → `../kubernetes-operations/`; security strategy →
    `../../security/kubernetes-security/`; networking mechanics →
    `../../networking/kubernetes-networking/`; general MCP-into-harness wiring →
    `../../platform-engineering/create-harness/`.
- **Doctrine to keep correct:** read-mostly by default; every **Act** is a gated,
  reversible GitOps PR / audited runbook, never an imperative agent mutation;
  loosen **one** blast-radius dimension at a time; budget the tool count.
- **Maturity labeling is mandatory** (the confabulation trap here): **Azure SRE
  Agent = Preview**; the Dynatrace **"Cloud SRE Agents" multicloud router =
  community / NOT GA**; **HolmesGPT = CNCF Sandbox**; **vendor MTTR-reduction
  figures are marketing — never state them as fact**. Pin no versions.
- **Tool-belt accuracy:** each server's read/write posture + guardrail flag must be
  right — `kubernetes-mcp-server` (`--read-only` / `--disable-destructive`),
  `mcp-for-argocd` (`MCP_READ_ONLY=true`), `github-mcp-server`
  (`--read-only`/`--toolsets`/`--tools`), `azure-mcp` (RBAC, no flag), `k8sgpt`
  (`serve --mcp`, read-only), `trivy-mcp` (read-only). Skip-list (already covered /
  unverifiable): Keep, lens-mcp, azure-devops-mcp, **jithinjk eBPF MCP (repo 404)**,
  **Calico mcpmarket listing**.
- `description:` uses a `>-` block scalar — keep it; re-verify `yq '.description | type'` is `!!str`.

### Testing Requirements
- **`scripts/validate-skills.sh` validates this directory** (`operations/` ∈
  `DOMAIN_DIRS`): frontmatter, non-empty body, even fences. Positive + negative
  check after structural edits.

### Common Patterns
- CORE PRINCIPLES → the Detect→Decide→Act pattern → the MCP tool-belt (with
  guardrails + skip-list) → blast-radius doctrine → anti-patterns → checklist →
  reference → orchestration (coordinates existing teams; ships no own agents).

## Dependencies

### Internal
- `../../scripts/validate-skills.sh` — enforces the SKILL.md contract.
- `../../README.md` — references this skill in the "Operations" table; rename → README update.
- `../azure-sre-agent/SKILL.md`, `../../platform-engineering/dynatrace/SKILL.md`, `../kubernetes-operations/SKILL.md`, `../../security/kubernetes-security/SKILL.md`, `../../networking/kubernetes-networking/SKILL.md`, `../../platform-engineering/create-harness/SKILL.md` — the skills this umbrella coordinates (link-not-duplicate).

### External
None at runtime — documentation. References external MCP servers (kubernetes-mcp-server,
mcp-for-argocd, github-mcp-server, azure-mcp, k8sgpt, trivy-mcp) and the
Detect→Decide→Act tooling, but does not depend on them being installed in this repo.
No versions pinned.

<!-- MANUAL: -->
