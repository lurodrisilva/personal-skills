<!-- Generated: 2026-04-25 | Updated: 2026-04-25 -->

# personal-skills

## Purpose
Distribution repository for **Claude Code / opencode skills**. Each leaf directory ships a single `SKILL.md` (YAML frontmatter + markdown body) that downstream Claude Code or opencode installs auto-load when their `description` matches the user's project context. There is no application to build or run — every meaningful change in this repo is authoring or editing a `SKILL.md`.

## Key Files
| File | Description |
|------|-------------|
| `README.md` | User-facing index of available skills, SKILL.md format spec, and contribution guide |
| `CLAUDE.md` | In-repo agent guidance: validator command, layout, SKILL.md contract, validator coverage gap |
| `LICENSE` | BSD-3-Clause license text (matches `license:` frontmatter on every SKILL.md) |
| `.gitignore` | Ignores `.omc/`, local agent state, and other per-clone artifacts |

## Subdirectories
| Directory | Purpose |
|-----------|---------|
| `coding/` | Application-development skills — language, framework, build-tooling guidance (see `coding/AGENTS.md`) |
| `platform-engineering/` | Infrastructure, DevOps, CI/CD, supply-chain skills (see `platform-engineering/AGENTS.md`) |
| `scripts/` | Local + CI validation tooling for SKILL.md (see `scripts/AGENTS.md`) |
| `.github/workflows/` | CI workflow that runs `scripts/validate-skills.sh` on every push and PR |

## For AI Agents

### Working In This Directory
- Almost every change is authoring or editing a `SKILL.md`. There is no application code, no build, no test runner.
- Adding a skill requires picking the correct domain directory **first** (`coding/` vs `platform-engineering/`), then a kebab-case sub-directory, then a `SKILL.md` matching the contract documented in `CLAUDE.md`.
- Directory names are stable references — `README.md` tables and external docs link to them. Do not rename a skill directory without updating `README.md`.
- The frontmatter `name:` field is independent of the directory name (e.g. `coding/dotnet-hex-clean/` declares `name: dotnet-clean-arch`). Both forms are valid.

### Testing Requirements
- Run `./scripts/validate-skills.sh` before every push.
- Exit code = error count; CI runs the same script via `.github/workflows/validate-skills.yml`.
- The validator requires `yq` on `PATH` (Mike Farah's Go implementation, same binary as `mikefarah/yq@master` in CI).
- **Known coverage gap:** the validator only walks `coding/`. `platform-engineering/**/SKILL.md` is **not** covered by CI today — manually re-check frontmatter validity and fenced-block balance for any platform-engineering edit until the validator is extended.

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
