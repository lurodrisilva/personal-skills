<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-04-25 | Updated: 2026-04-25 -->

# scripts

## Purpose
Local + CI validation tooling for SKILL.md files. The single script in this directory is the **only** check the repo runs — there is no test suite, no linter, no build.

## Key Files
| File | Description |
|------|-------------|
| `validate-skills.sh` | Bash validator that enforces the SKILL.md contract on every file under `coding/`. Exit code = error count; `0` = all checks passed |

## Subdirectories
None.

## For AI Agents

### Working In This Directory
- `validate-skills.sh` is invoked verbatim by `.github/workflows/validate-skills.yml` — keep it executable (`chmod +x`) and POSIX-portable shell.
- Uses `yq` (Mike Farah's Go implementation) for frontmatter parsing. Do not switch to Python `yq` (jq wrapper) — the CI step pins `mikefarah/yq@master`.
- Hardcoded `CODING_DIR="$REPO_ROOT/coding"` means **only `coding/`** is validated. Two loops use this constant — both must change together if validator coverage is expanded to `platform-engineering/`.
- Each `err` call increments the error counter and exits non-zero at the end. New checks should follow the same `err`/`info` pattern so the summary line stays accurate.

### Testing Requirements
- After editing, run `./scripts/validate-skills.sh` against the current repo to confirm the baseline still passes.
- Manually break a SKILL.md (delete a required field, unbalance a code fence) to confirm any new check fires.

### Common Patterns
- `set -euo pipefail` at the top.
- Two-pass structure: orphan-directory check first, then per-SKILL.md validation. Match this style if adding new validators.
- Errors go to `stderr`; info to `stdout` so CI logs read top-to-bottom.

## Dependencies

### External
- `yq` (mikefarah/yq) — YAML frontmatter parsing.
- `awk`, `grep`, `bash` — POSIX baseline.

### Internal
- `../coding/**/SKILL.md` — every file walked by the validator.
- `../.github/workflows/validate-skills.yml` — CI invoker.

<!-- MANUAL: -->
