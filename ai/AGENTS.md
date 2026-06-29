<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-03 | Updated: 2026-06-03 | DEEPINIT: 2026-06-03 -->

# ai

## Purpose
AI-tooling skills — guidance for tools that AI coding assistants drive or integrate with (knowledge-graph builders, MCP servers, agent-facing CLIs). Each subdirectory contains exactly one `SKILL.md` that Claude Code / opencode auto-loads when a project matches the skill's `description`. This is a domain directory parallel to `coding/`, `platform-engineering/`, `operations/`, `security/`, and `networking/`.

## Key Files
None at this level — all content lives in subdirectories.

## Subdirectories
| Directory | Purpose |
|-----------|---------|
| `graphify/` | Graphify codebase knowledge-graph CLI/MCP — `graphifyy` package, `/graphify` slash command, NetworkX `graph.json`, tree-sitter + LLM extraction, MCP serve, PR impact (see `graphify/AGENTS.md`) |

## For AI Agents

### Working In This Directory
- Every immediate subdirectory must contain a `SKILL.md` matching the contract in the root `CLAUDE.md` (`name`, `description`, `license`, `compatibility`, non-empty `metadata` map; non-empty body; balanced fences).
- Naming convention here: descriptive kebab-case, typically the tool name (e.g. `graphify`).
- Directory name is the stable reference — `README.md` links to it; the SKILL.md `name:` field may differ.
- `description:` opens with `MUST USE when …` and exhaustively lists trigger phrases / file patterns — this is what auto-detection matches on.

### Testing Requirements
- **`scripts/validate-skills.sh` does NOT walk this directory** — its `DOMAIN_DIRS` covers `coding/`, `platform-engineering/`, `operations/`, `security/`, and `networking/`, not `ai/`. After editing any SKILL.md here, manually verify:
  1. YAML frontmatter parses and contains `name`, `description`, `license`, `compatibility`, non-empty `metadata` map.
  2. Markdown body after the closing `---` is non-empty.
  3. Fenced code-block markers are even in count.
- Quick manual check (mirrors the validator logic):
  ```bash
  f=ai/<skill>/SKILL.md
  fm=$(awk '/^---$/{n++} n==1 && !/^---$/{print} n==2{exit}' "$f")
  echo "$fm" | yq eval '.' - >/dev/null && echo "yaml ok"
  grep -cE '^\s*```' "$f"   # must be even
  ```

### Common Patterns
- Body structure: non-negotiable rules first → "When to use" matrix → patterns with concrete commands/code → anti-patterns table → pre-done verification checklist.
- Tool skills enumerate exact install commands and call out install gotchas (e.g. Graphify's `graphifyy` package vs `graphify` command).

## Dependencies

### Internal
- `../scripts/validate-skills.sh` — does **not** validate this tree; its `DOMAIN_DIRS` covers `coding/`, `platform-engineering/`, `operations/`, `security/`, and `networking/`, not `ai/`. Validate manually (or add `ai` to `DOMAIN_DIRS` to opt in).
- `../README.md` — should reference skills in this domain; add a row when a new skill lands.
- `../CLAUDE.md` — authoritative SKILL.md contract and repo layout.

<!-- MANUAL: -->
