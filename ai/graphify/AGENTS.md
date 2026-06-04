<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-03 | Updated: 2026-06-03 | DEEPINIT: 2026-06-03 -->

# graphify

## Purpose
Skill that guides building, querying, serving, and maintaining a **Graphify codebase knowledge graph** for AI coding assistants. Covers the install gotcha (PyPI package **`graphifyy`** double-y → console/slash command **`graphify`**), per-assistant registration (`graphify install`, `claude/cursor/vscode/gemini/copilot/devin install`, `--platform codex|windows`), the `/graphify .` build command and flags (`--update`, `--cluster-only`, `--resolution`, `--no-viz`), graph queries (`/graphify query|path|explain`), the **three-pass pipeline** (Pass 1 local tree-sitter code structure with NO API calls → Pass 2 faster-whisper media transcription → Pass 3 Claude/LLM semantic extraction via parallel subagents), the functional module chain `detect()→extract()→build_graph()→cluster()(Leiden)→analyze()→report()→export()`, the NetworkX node-link `graph.json` schema (nodes, `relation` verb-phrase edges, `EXTRACTED`/`INFERRED`/`AMBIGUOUS` confidence, hyperedges), `graphify-out/` artifacts, `.graphifyignore`, headless CI extraction (`graphify extract --backend claude|gemini|ollama` + API-key env vars), PR-impact tooling (`graphify prs`, `--triage`, `hook install`), the MCP stdio server (`python -m graphify.serve` exposing `query_graph`/`get_node`/`get_neighbors`/`shortest_path`/`list_prs`/`get_pr_impact`/`triage_prs`), and the **separate** companion Docker MCP Toolkit SQLite server (`mcp/sqlite`, `mcp-sqlite` volume, 6 tools) — kept distinct from Graphify's own NetworkX store (Graphify has NO SQL database).

## Key Files
| File | Description |
|------|-------------|
| `SKILL.md` | Skill definition — `name: graphify`, `domain: ai`, `package: graphifyy`, `category: codebase-knowledge-graph`, `runtime: cli + mcp-stdio`, `storage: networkx-graph-json`, `extraction: tree-sitter + llm` |

## Subdirectories
None.

## For AI Agents

### Working In This Directory
- Edit `SKILL.md` only.
- The 8 non-negotiables at the top are the load-bearers: install `graphifyy` / run `graphify` (#1), code extraction is local + free — never claim code is sent to an API (#2), commit `graphify-out/` (#3), rely on SHA256 incremental cache — don't delete `cache/` (#4), read edge `confidence` before trusting a relationship (#5), use `.graphifyignore` (#6), **Graphify has no SQL DB** — its store is `graph.json`, distinct from the Docker SQLite MCP server (#7), local-first/no-telemetry (#8).
- Source facts came from the Graphify v8 docs (README, how-it-works, ARCHITECTURE, docker-mcp-sqlite) + PyPI (`graphifyy` v0.8.31, Python ≥3.10). When bumping facts, re-verify the package/command split and the language count (README says 33+; an internal doc says 25 — `33+` is used as the product-canonical figure).
- The `docker-mcp-sqlite` material is a **companion** server, not Graphify storage — never conflate the two when editing.

### Testing Requirements
- **`scripts/validate-skills.sh` does NOT walk this directory** (it only walks `coding/`). After editing, manually verify:
  1. YAML frontmatter parses and contains `name`, `description`, `license`, `compatibility`, non-empty `metadata` map.
  2. Markdown body after the closing `---` is non-empty.
  3. Fenced code-block markers are even in count (this file's SKILL.md uses many fenced shell blocks — easy to unbalance).
- Every shell snippet must obey the skill's own rules: install `graphifyy` (not `graphify`), reserve API keys for Pass 3 / `graphify extract`, use `mcp/sqlite` (not the broken `mcp/sqlite-mcp-server`).

### Common Patterns
- "Non-negotiables" numbered list → "When to use" matrix → install/workflow → pipeline + module map → graph schema → CLI reference → MCP/Docker companion → anti-patterns table → verification checklist. Same authoring style as platform-engineering skills.

## Dependencies

### Internal
- `../AGENTS.md` — `ai/` domain overview and the manual-validation procedure for this tree.
- `../../README.md` — should list this skill (no `ai/` table row yet; tracked).
- `../../scripts/validate-skills.sh` — *currently does not validate this file*; expanding the validator to cover all domains is a tracked follow-up.

### External
None at runtime — this is documentation, not code. (The documented tool itself is the PyPI `graphifyy` package + optional Docker MCP SQLite server.)

<!-- MANUAL: -->
