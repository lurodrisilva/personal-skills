<!-- Generated: 2026-04-25 | Updated: 2026-06-28 | DEEPINIT: 2026-06-28 -->

# personal-skills

## Purpose
Distribution repository for **Claude Code / opencode skills**. Each leaf directory ships a single `SKILL.md` (YAML frontmatter + markdown body) that downstream Claude Code or opencode installs auto-load when their `description` matches the user's project context. There is no application to build or run — every meaningful change in this repo is authoring or editing a `SKILL.md`.

## Key Files
| File | Description |
|------|-------------|
| `README.md` | User-facing index of available skills, SKILL.md format spec, and contribution guide |
| `CLAUDE.md` | In-repo agent guidance: validator command, layout, SKILL.md contract, validator coverage |
| `LICENSE` | BSD-3-Clause license text (matches `license:` frontmatter on every SKILL.md) |
| `.gitignore` | Ignores `.omc/` (per-clone OMC state). `.claude/settings.local.json` is ignored via the user's global gitignore, not this file |

## Subdirectories
| Directory | Purpose |
|-----------|---------|
| `ai/` | AI-tooling skills — tools that AI coding assistants drive or integrate with, e.g. knowledge-graph builders and MCP servers (see `ai/AGENTS.md`) |
| `coding/` | Application-development skills — language, framework, build-tooling guidance (see `coding/AGENTS.md`) |
| `platform-engineering/` | Infrastructure, DevOps, CI/CD, supply-chain, observability skills (see `platform-engineering/AGENTS.md`) |
| `operations/` | Day-2 / SRE skills for **operating** running systems — e.g. `kubernetes-operations` (see `operations/AGENTS.md`) |
| `security/` | Security / hardening / threat-model skills — e.g. `kubernetes-security` (ships read-only audit scripts under `tools/`) (see `security/AGENTS.md`) |
| `networking/` | Networking-plane skills — the CNI / dataplane / routing / network-policy mechanics, e.g. `kubernetes-networking` (Calico) (see `networking/AGENTS.md`) |
| `scripts/` | Local + CI validation tooling for SKILL.md (see `scripts/AGENTS.md`) |
| `omc-learned/` | Single-insight expertise notes captured by `/oh-my-claudecode:learner` — staging ground for future SKILL.md promotion; not loaded by validator (see `omc-learned/AGENTS.md`) |
| `.claude/` | Repo-scoped Claude Code config — committed subagent definitions that skills orchestrate, plus local-only settings (see `.claude/AGENTS.md`) |
| `.github/workflows/` | CI workflow that runs `scripts/validate-skills.sh` on every push and PR |

## For AI Agents

### Working In This Directory
- Almost every change is authoring or editing a `SKILL.md`. There is no application code, no build, no test runner.
- Adding a skill requires picking the correct domain directory **first** (`coding/` vs `platform-engineering/` vs `operations/` vs `security/` vs `networking/` — build skills vs infra skills vs Day-2/run-it skills vs secure/harden/threat-model skills vs networking-plane/CNI skills), then a kebab-case sub-directory, then a `SKILL.md` matching the contract documented in `CLAUDE.md`.
- Directory names are stable references — `README.md` tables and external docs link to them. Do not rename a skill directory without updating `README.md`.
- The frontmatter `name:` field is independent of the directory name (e.g. `coding/dotnet-hex-clean/` declares `name: dotnet-clean-arch`). Both forms are valid.

### Testing Requirements
- Run `./scripts/validate-skills.sh` before every push.
- Exit code = error count; CI runs the same script via `.github/workflows/validate-skills.yml`.
- The validator requires `yq` on `PATH` (Mike Farah's Go implementation, same binary as `mikefarah/yq@master` in CI).
- **Validator coverage:** the validator walks every domain in its `DOMAIN_DIRS` array — currently `coding/`, `platform-engineering/`, `operations/`, `security/`, **and** `networking/`. All five are CI-checked on every push and PR. `ai/`, `omc-learned/`, and `scripts/` are **not** walked — manually re-check frontmatter validity and fenced-block balance when editing a `SKILL.md` outside the covered domains. Add a new top-level domain to `DOMAIN_DIRS` to extend coverage.

### Common Patterns
- `license: BSD-3-Clause` on every SKILL.md (matches root `LICENSE`).
- `compatibility: opencode` is the current target runtime.
- `description:` opens with `MUST USE when …` and exhaustively lists trigger phrases / file patterns — this is what Claude Code / opencode auto-detection matches on.
- Body structure: non-negotiable rules first → layer-by-layer patterns with concrete code examples → anti-patterns table → pre-done verification checklist.
- Commit messages: imperative subject, optional bulleted body explaining the *why*, `Co-Authored-By: Claude …` trailer when Claude authored the change.

## Dependencies

### External
- `yq` (mikefarah/yq) — frontmatter parsing in the validator.
- GitHub Actions — `actions/checkout@v4`, `mikefarah/yq@master`.

<!-- MANUAL: Custom project notes can be added below -->
