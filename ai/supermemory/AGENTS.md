<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-08-28 | Updated: 2026-08-29 -->

# ai/supermemory

## Purpose
Skill for **Supermemory** (supermemory.ai) — the memory/context API used to
give AI applications and agentic workflows persistent, multi-tenant memory.
Covers the v3/v4 REST surface (documents, conversations, search, memories,
profiles, container-tags, connections, settings), the TS/Python SDKs and
`@supermemory/tools` v2 framework wrappers, the Memory MCP / Docs MCP /
Claude Code plugin, scoped API keys + billing meters, and the API-parity
self-hosted single binary (`npx supermemory local`, port 6767). Five phases
(A–E in the SKILL.md) are delegated to five companion subagents in
`../../.claude/agents/` (`supermemory-*`).

## Key Files
| File | Description |
|------|-------------|
| `SKILL.md` | The skill: phase↔agent table, 8 CORE PRINCIPLES (containerTag scoping, three-artifact model, customId/diff billing, async dreaming, soft forgetting, scoped keys, one-API-two-deployments, automatic-vs-tool-based memory), Phase A–E playbooks, anti-patterns table, verification checklist |

## Subdirectories
| Directory | Purpose |
|-----------|---------|
| `tools/` | 3 strictly read-only scripts: `supermemory-api-probe.sh` (reachability/auth/org snapshot), `supermemory-search-probe.sh` (one end-to-end `/v4/search` query with timing/similarity), `supermemory-config-audit.sh` (local project wiring: deps, env vars, hardcoded-key warning, MCP entries, self-hosted state) (see `tools/AGENTS.md`) |

## For AI Agents

### Working In This Directory
- The SKILL.md `description` opens with `MUST USE when …` — keep trigger
  phrases exhaustive when editing; auto-loading matches on that string.
- Every technical claim traces to the Supermemory docs
  (`https://supermemory.ai/docs/llms.txt` indexes every page as fetchable
  `.md`; OpenAPI at `https://api.supermemory.ai/v3/openapi` and
  `/v4/openapi`). Two documented discrepancies are called out in-place
  (v4 `threshold` default 0.6 vs 0.5; filter nesting 5 vs 8 levels) —
  verify against the live OpenAPI before "fixing" either number.
- `tools/` scripts must stay read-only: GETs and read-semantics list/search
  POSTs only, no create/update/delete, never print key material, graceful
  exit 0 without `SUPERMEMORY_API_KEY`.
- Companion subagents live in `../../.claude/agents/supermemory-*.md`; keep
  their frontmatter `name:` equal to the filename stem and their hand-off
  lists in sync with the SKILL.md phase table.

### Validation (this tree is NOT walked by the validator)
`../../scripts/validate-skills.sh` covers only its `DOMAIN_DIRS`
(`coding/`, `platform-engineering/`, `operations/`, `security/`,
`networking/`) — but the README badge count DOES include `ai/`. After any
edit here, manually verify:

```bash
f=ai/supermemory/SKILL.md
fm=$(awk '/^---$/{n++} n==1 && !/^---$/{print} n==2{exit}' "$f")
echo "$fm" | yq eval '.' - >/dev/null && echo "yaml ok"
grep -cE '^\s*```' "$f"   # must be even
bash -n ai/supermemory/tools/*.sh
```

## Dependencies

### Internal
- `../../.claude/agents/supermemory-*.md` — the 5 companion subagents
  (ingestion-engineer, retrieval-engineer, sdk-integrator,
  platform-operator, agentic-architect).
- `../../README.md` — AI-domain table row + skills badge count include this
  skill.
- `../AGENTS.md` — parent domain table lists this directory.

### External
- Supermemory docs: `https://supermemory.ai/docs` (llms.txt index),
  OpenAPI v3/v4, `github.com/supermemoryai/supermemory` (MIT monorepo),
  `github.com/supermemoryai/claude-supermemory`,
  hosted MCP `https://mcp.supermemory.ai/mcp`,
  Docs MCP `https://supermemory.ai/docs/mcp`.
