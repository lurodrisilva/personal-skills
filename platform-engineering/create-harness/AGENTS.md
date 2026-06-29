<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-28 | Updated: 2026-06-28 -->

# create-harness

## Purpose
Skill that scaffolds a **Claude Code "agent harness"** — a versioned monorepo
that is the single canonical source of skills, MCP servers, sub-agents, a
knowledge vault, and a workspace of product repos, projected into `.claude/` /
`.mcp.json` by a generated `bin/harness sync` CLI. The skill interviews the
operator for the contemplated repositories, scaffolds the topology
(`harness.config.yaml`, `bin/harness`, `bin/render_mcp.py`,
`bin/render_plugins.py`, `mcp/servers.json`, `catalog/plugins/plugins.json`,
`workspace/workspace.yaml`, `vault/`), clones those repos, projects into Claude
Code, and rebuilds every graphify graph (per-repo + the federated root graph).
**Claude-Code-only** — it does not project to Devin or any other CLI.

## Key Files
| File | Description |
|------|-------------|
| `SKILL.md` | The skill definition — `name: create-harness`, `domain: platform-engineering`, `pattern: project-scaffolding`, `tooling: claude-code-harness`, `graph: graphify`. Interview-first workflow (Step 0 → Step 4) with embedded bash/python scaffolding templates |

## Subdirectories
None.

## For AI Agents

### Working In This Directory
- Edit `SKILL.md` only.
- **Interview-first is load-bearing:** Step 0 ("interview the operator before any
  file is written") gates the whole workflow — do not soften it into "scaffold
  with defaults". The contemplated-repositories list drives
  `workspace/workspace.yaml` and the clone/graph steps.
- The skill embeds runnable scaffolding (`bin/harness`, `bin/render_mcp.py`,
  `bin/render_plugins.py`) as fenced bash/python. These are the most likely
  fence-balance regression — keep blocks closed.
- Scope guard: this skill is **Claude-Code-only**. Don't add Devin / other-CLI
  projection paths; that's an explicit non-goal in "When NOT to use".
- The final step (rebuild **all** graphify graphs, per-repo + federated) is part
  of "done" — keep it in the verification checklist when editing.

### Testing Requirements
- **`scripts/validate-skills.sh` validates this directory** (its `DOMAIN_DIRS`
  includes `platform-engineering/`) — CI runs it on every push and PR. Run it
  locally before pushing; it checks:
  1. YAML frontmatter parses and contains `name`, `description`, `license`, `compatibility`, non-empty `metadata` map.
  2. Markdown body after the closing `---` is non-empty.
  3. Fenced code-block markers are even in count (this skill ships many bash/python blocks — `grep -c '^```' SKILL.md` must be even).

### Common Patterns
- Step-by-step body (Step 0 interview → Step 4 graphs) closing with a verification
  checklist + anti-patterns table — same authoring shape as the other
  platform-engineering skills.
- References `graphify` (see `../../ai/graphify/SKILL.md`) for the knowledge-graph
  step.

## Dependencies

### Internal
- `../../scripts/validate-skills.sh` — enforces the frontmatter + body + fenced-block contract.
- `../../README.md` — references this skill in the "Platform Engineering" table; rename → README update required.
- `../../ai/graphify/SKILL.md` — the graphify tooling this skill drives to build per-repo + federated graphs.

### External
None at runtime — this is documentation, not code. The skill *describes* the
generated `bin/harness` CLI, MCP server wiring, and graphify but does not depend
on them being installed in this repo.

<!-- MANUAL: -->
