<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-29 | Updated: 2026-06-29 -->

# azure-sre-agent

## Purpose
Skill for **Azure SRE Agent** — Microsoft's managed, AI-assisted SRE agent
(**Preview**). Owns the agent's **extension model and operating doctrine**: the 6
extension primitives, the MCP-connector model, the built-in subagents, agent hooks,
and — centrally — the **propose-then-approve / Permission gate** safety model.
Second skill in the `operations/` domain; the AI-assisted counterpart to
`kubernetes-operations`.

## Key Files
| File | Description |
|------|-------------|
| `SKILL.md` | The skill — `name: azure-sre-agent`, `domain: operations`, `platform: azure`, `service: azure-sre-agent`, `maturity: preview`, `pattern: agentic-incident-remediation` |

## Subdirectories
None.

## For AI Agents

### Working In This Directory
- Edit `SKILL.md` only.
- **Maturity discipline is the load-bearing rule:** Azure SRE Agent is **Preview**.
  **Label it Preview, pin NO version number**, and frame every primitive as
  "verify against Microsoft Learn (`learn.microsoft.com/azure/sre-agent`)". This is
  the same no-version-pin doctrine the `dynatrace` / `kubernetes-*` skills follow.
- Keep the **scope boundary** sharp:
  - The cross-tool **Detect→Decide→Act** pattern + the MCP tool-belt + blast-radius doctrine → `../agentic-k8s-ops/`.
  - The **Dynatrace MCP server** tool list + auth → `../../platform-engineering/dynatrace/` ("MCP server surface").
  - *Operating the cluster by hand* → `../kubernetes-operations/`.
  This skill owns the **Azure SRE Agent platform**: primitives, connector model, approval doctrine.
- Highest-blast-radius facts to keep correct: **propose-then-approve** is the
  default (the agent does not auto-apply); the **Permission gate** evaluates every
  proposed tool call (approve/policy/block) and composes with **Managed-Identity
  RBAC**; the **80-tool-per-agent budget** (native + MCP) is real; MCP transports
  are **Streamable-HTTP (remote, HTTPS)** vs **stdio (Node 20 / Py 3.12 / .NET 9,
  no Docker)**; auth is **Bearer / custom-headers / managed-identity**.
- The `description:` uses a `>-` block scalar (colon/backtick-dense) — keep it and
  re-verify `yq '.description | type'` is `!!str` after edits.

### Testing Requirements
- **`scripts/validate-skills.sh` validates this directory** (`operations/` is in
  `DOMAIN_DIRS`). It checks frontmatter, non-empty body, even fences. Run a
  positive + negative check after structural edits.

### Companion Subagents
- Ships a 5-agent team in `../../.claude/agents/` mirroring Azure SRE Agent's 5
  built-in subagents: `azure-sre-rca` (RCA, proposes only — `opus`),
  `azure-sre-observability` (logs/metrics), `azure-sre-sourcecode` (deploy
  correlation), `azure-sre-architecture` (topology/blast-radius), `azure-sre-scanning`
  (security/compliance sweeps). The SKILL's "Subagent Orchestration" table maps
  built-in surface → agent; update both sides on rename.

### Common Patterns
- CORE PRINCIPLES (approval doctrine first) → WHAT IT IS → phases (6 primitives →
  MCP connector model → Permission gate → subagents → hooks/Skills) → anti-patterns
  → checklist → reference → orchestration. Same authoring shape as the sibling
  operations skill.

## Dependencies

### Internal
- `../../scripts/validate-skills.sh` — enforces the SKILL.md contract.
- `../../README.md` — references this skill in the "Operations" table; rename → README update.
- `../../.claude/agents/azure-sre-*.md` — the 5 companion subagents.
- `../agentic-k8s-ops/SKILL.md` (cross-tool pattern), `../../platform-engineering/dynatrace/SKILL.md` (MCP server surface), `../kubernetes-operations/SKILL.md` (hands-on cluster ops) — cross-referenced to keep boundaries sharp.

### External
None at runtime — documentation. Describes Azure SRE Agent (Preview); cites
`learn.microsoft.com/azure/sre-agent`. No version pinned.

<!-- MANUAL: -->
