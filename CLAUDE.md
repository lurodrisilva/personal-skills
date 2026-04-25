# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A distribution of **Claude Code / opencode skills**. There is no application to build or run — each leaf directory ships a single `SKILL.md` file (YAML frontmatter + markdown body) that downstream Claude Code / opencode installs load as domain guidance. Almost every change in this repo is authoring or editing a `SKILL.md`.

## Commands

```bash
# Validate all skills (run before every push)
./scripts/validate-skills.sh
```

The validator requires `yq` on `PATH` (same binary GitHub Actions uses via `mikefarah/yq`). Exit code = number of errors; `0` means all checks passed. There is no separate test runner, linter, or build step.

CI (`.github/workflows/validate-skills.yml`) runs the same script on every push to `master` and every pull request.

## Repository layout

```
coding/                  # application-development skills (language / framework / build tooling)
  <skill-name>/SKILL.md
platform-engineering/    # infrastructure / DevOps / CI-CD / supply-chain skills
  <skill-name>/SKILL.md
scripts/validate-skills.sh
.github/workflows/validate-skills.yml
```

Pick the domain directory first, then the skill sub-directory name:

- `<language>-hex-clean` — hexagonal / clean architecture skills (e.g., `golang-hex-clean`)
- `<domain>-<purpose>` — platform-engineering skills (e.g., `github-actions`)
- descriptive kebab-case — cross-cutting build tooling (e.g., `create-makefiles`, `dockerfile-instructions`)

The SKILL.md's frontmatter `name:` does not have to match the directory name (e.g., `coding/dotnet-hex-clean/` declares `name: dotnet-clean-arch`). Keep directory names stable because the README tables and external references link to them.

## SKILL.md contract

Every SKILL.md must parse against the rules enforced by `scripts/validate-skills.sh`:

1. YAML frontmatter delimited by `---` as the first non-empty line and again to close.
2. Required scalar fields: `name`, `description`, `license`, `compatibility`.
3. `metadata` must be a **non-empty YAML map** (language / framework / pattern / domain / platform tags — pick what fits).
4. Non-empty markdown body after the closing `---`.
5. Fenced code blocks balanced (even count of ```` ``` ```` markers — an unclosed fence fails CI).

Conventions observed across the existing skills (keep them when adding new ones):

- `license: BSD-3-Clause` matches the repo `LICENSE`.
- `compatibility: opencode` — current target runtime for this collection.
- `description:` opens with `MUST USE when …` and enumerates the trigger phrases / file patterns that should activate the skill. This string is what Claude Code / opencode matches on for auto-loading, so be specific and exhaustive.
- Body structure: non-negotiable rules first, then layer-by-layer patterns with concrete code examples, closing with an anti-patterns table and a pre-done verification checklist.

## Known gap — validator coverage

`scripts/validate-skills.sh` walks **only** `coding/` (see `CODING_DIR="$REPO_ROOT/coding"` and both validation loops). `platform-engineering/**/SKILL.md` is **not** covered by CI today — edits there can regress the contract without the job failing. Expanding the validator to cover all domain directories is a tracked follow-up; until then, run the validator pointed at a copy, or manually re-check frontmatter / fenced-block balance for platform-engineering changes.

## Conventions

- Commit messages follow the existing style (see `git log`): imperative subject, optional bulleted body explaining the "why", trailer `Co-Authored-By: Claude …` when Claude authored the change.
- `CLAUDE.md`, `AGENTS.md`, and `.omc/` are git-ignored — treat them as per-clone local state.
