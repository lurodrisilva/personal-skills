<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-08-28 | Updated: 2026-08-28 -->

# hermes-agent

## Purpose
Skill that guides installing, configuring, operating, automating, integrating, and extending **Hermes Agent** — the open-source (MIT) autonomous AI agent framework by Nous Research (hermes-agent.nousresearch.com). One synchronous `AIAgent` core reached through the CLI/TUI, a 25+-platform messaging gateway, the ACP IDE adapter, an OpenAI-compatible API server (port 8642), and a web dashboard (port 9119). The skill is organized into six phases (A install/operate, B config/profiles/secrets/egress, C skills/memory/context, D automation/gateway/serving, E providers/MCP/Python library, F extending), each with a companion subagent in `.claude/agents/hermes-*.md`, and ships three read-only triage scripts under `tools/`.

## Key Files
| File | Description |
|------|-------------|
| `SKILL.md` | Skill definition — `name: hermes-agent`, `domain: ai`, `vendor: nous-research`, `category: autonomous-agent-framework`, `runtime: cli + tui + gateway + acp + api-server + mcp`, `config-root: ~/.hermes` |

## Subdirectories
| Directory | Purpose |
|-----------|---------|
| `tools/` | Three READ-ONLY triage scripts: `hermes-env-audit.sh` (install + config-split audit), `hermes-profile-inventory.sh` (profiles/skills/cron/MCP/plugins/memory inventory), `hermes-surface-probe.sh` (dashboard 9119 / API server 8642 / gateway / egress status probes). No script mutates state. |

## For AI Agents

### Working In This Directory
- Edit `SKILL.md` and the `tools/` scripts only; companion subagents live in `../../.claude/agents/hermes-*.md`.
- The 8 CORE PRINCIPLES at the top of SKILL.md are the load-bearers: script-only install (#1 — pip/brew/AUR/macOS-Intel unsupported), the `.env`-vs-`config.yaml` secrets split (#2), the 64,000-token model context floor (#3), one agent process per profile (#4), system prompt immutable mid-session — customize via SOUL.md/context files/skills, never `prompt_builder.py` (#5), only ONE project context file loads with `.hermes.md` > `AGENTS.override.md` > `AGENTS.md` > `CLAUDE.md` > `.cursorrules` precedence (#6), safety-rail placement — container backends skip dangerous-command checks, API server exposes terminal, dashboard fails closed off-loopback (#7), read-only first / gated actions (#8).
- Source facts came from the official docs at hermes-agent.nousresearch.com (getting-started, user-guide, reference, guides, developer-guide — ~80 pages, fetched 2026-08-28). When bumping facts, re-verify the sharp edges: memory caps (2,200/1,375 chars), ports (9119 dashboard / 8642 API / 8644 webhooks / 9090-9091 iron-proxy), MCP tool naming `mcp__<server>__<tool>` + include-overrides-exclude, the 1Password `override_existing: true` default inversion, and the no-PyPI Python-library install.
- The skill documents Hermes's OWN skills format (`metadata.hermes` namespace) — do not confuse it with this repo's SKILL.md contract when editing.

### Testing Requirements
- **`scripts/validate-skills.sh` does NOT walk this directory** (its `DOMAIN_DIRS` covers `coding/`, `platform-engineering/`, `operations/`, `security/`, and `networking/`, not `ai/`) — only the README badge count includes it. After editing, manually verify:
  1. YAML frontmatter parses (`yq`) and contains `name`, `description`, `license`, `compatibility`, non-empty `metadata` map.
  2. Markdown body after the closing `---` is non-empty.
  3. Fenced code-block markers are even in count.
- `bash -n tools/*.sh` after any script edit; scripts must stay strictly read-only (`status`-class commands, file reads, loopback GETs) and degrade gracefully when `hermes` is not installed.

### Common Patterns
- Body shape: CORE PRINCIPLES numbered list → phase map table (phases ↔ companion agents) → Phase A–F playbooks with concrete commands/config → read-only tools table → anti-patterns table → verification checklist. Same authoring style as `platform-engineering/opencost/`.

## Dependencies

### Internal
- `../AGENTS.md` — `ai/` domain overview and the manual-validation procedure for this tree.
- `../../README.md` — lists this skill in the AI domain table; badge count includes it.
- `../../.claude/agents/hermes-*.md` — the six companion subagents (installer-operator, config-secrets, skills-memory-engineer, automation-gateway-engineer, provider-integrator, extension-developer) that anchor to this SKILL.md.
- `../../scripts/validate-skills.sh` — does not schema-validate this tree; the badge check counts it.

### External
None at runtime — this is documentation plus read-only shell scripts. (The documented tool itself is the Hermes Agent framework installed via the official install script.)

<!-- MANUAL: -->
