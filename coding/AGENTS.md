<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-04-25 | Updated: 2026-04-25 -->

# coding

## Purpose
Application-development skills — language, framework, and build-tooling guidance that Claude Code / opencode auto-loads when a project matches the skill's description. Each subdirectory contains exactly one `SKILL.md`. **This is the only directory walked by `scripts/validate-skills.sh` today** — every skill here is enforced by CI.

## Key Files
None at this level — all content lives in subdirectories.

## Subdirectories
| Directory | Purpose |
|-----------|---------|
| `create-makefiles/` | GNU Make best-practices skill — safe shell defaults, self-documenting help, per-language templates (see `create-makefiles/AGENTS.md`) |
| `dockerfile-instructions/` | Dockerfile authoring — multi-stage, BuildKit, multi-arch, per-language templates (see `dockerfile-instructions/AGENTS.md`) |
| `dotnet-hex-clean/` | .NET Clean Architecture (Ardalis template) — aggregates, FastEndpoints, EF Core (see `dotnet-hex-clean/AGENTS.md`) |
| `golang-hex-clean/` | Go Hexagonal / Clean Architecture — aggregates, ports/adapters, idiomatic Go (see `golang-hex-clean/AGENTS.md`) |

## For AI Agents

### Working In This Directory
- **Every immediate subdirectory must contain a `SKILL.md`** — the validator's orphan-directory check fails otherwise.
- New skills follow one of two naming conventions:
  - `<language>-hex-clean` for hexagonal/clean architecture skills (e.g. `golang-hex-clean`, `dotnet-hex-clean`)
  - kebab-case descriptive name for cross-cutting build tooling (e.g. `create-makefiles`, `dockerfile-instructions`)
- Directory name is the stable reference; the SKILL.md `name:` field is allowed to differ (e.g. `dotnet-hex-clean/` ships `name: dotnet-clean-arch`).

### Testing Requirements
- Run `./scripts/validate-skills.sh` from the repo root. Both the orphan-directory check and per-file SKILL.md validation operate against this directory only.
- CI re-runs the same script on every push to `master` and every PR.

### Common Patterns
- Body structure: ARCHITECTURE RULES (or NON-NEGOTIABLE PROLOGUE) → MODE DETECTION / WHEN TO USE → layer-by-layer patterns with code → anti-patterns table → verification checklist.
- Architecture skills (`*-hex-clean`) ship a "Dependency Law" table that codifies which package may import which — phrased as "VIOLATION = AUTOMATIC FAILURE".
- Build-tooling skills (`create-makefiles`, `dockerfile-instructions`) explicitly enumerate when **not** to use them ("don't add a Makefile for a one-line `npm test` wrapper").

## Dependencies

### Internal
- `../scripts/validate-skills.sh` — enforces the SKILL.md contract on every file in this tree.
- `../README.md` — references each skill in the "Coding" table; rename → README update required.

<!-- MANUAL: -->
