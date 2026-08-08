<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-08-08 | Updated: 2026-08-08 -->

# .tokensave

## Purpose
State directory for **tokensave**, a third-party token-accounting/indexing tool that
scans the repo and caches a per-branch index. It is **tool state, not repository
content** — nothing here is authored by hand and nothing here affects skills, the
validator, or CI. It is committed (unlike `.omc/`, which `.gitignore` excludes), so it
shows up in diffs whenever the tool re-syncs.

## Key Files
| File | Description |
|------|-------------|
| `config.json` | Tool configuration — `version`, `root_dir`, `exclude` globs (`target/**`, `.git/**`, `.tokensave/**`, `**/node_modules/**`, `vendor/**`, `**/*.min.*`, `bin/**`, `build/**`, `out/**`, `.gradle/**`), `include`, `max_file_size` (1 MiB), `extract_docstrings`, `track_call_sites`, `git_ignore` |
| `branch-meta.json` | Per-branch index bookkeeping — `default_branch` (`master`) and a `branches` map of `db_file` / `created_at` / `last_synced_at` |
| `tokensave.db` | The generated index database (binary). Machine-written; never hand-edit |

## Subdirectories
None.

## For AI Agents

### Working In This Directory
- **Do not hand-edit anything here.** These files are written by the tokensave tool.
  A manual edit is overwritten on the next sync and can corrupt the index.
- `tokensave.db` is a **binary artifact**. Never open it for editing, never include it
  in a diff review, and don't treat a change to it as a meaningful code change.
- **Known staleness:** `config.json` records
  `root_dir: /Users/lucianosilva/src/04-open-source/02-personal-skills`, which is **not**
  this clone's current path. The config was generated when the repo lived elsewhere.
  It is harmless today (nothing in the build or CI reads it), but don't trust
  `root_dir` as a source of truth for where the repo lives, and expect the tool to
  rewrite it on its next run.
- Churn here is noise. If a commit's diff is only `.tokensave/`, it carries no
  reviewable intent — prefer keeping it out of feature commits so real changes stay legible.

### Testing Requirements
- None. This directory has no tests and is not touched by
  `scripts/validate-skills.sh` (which walks only the domain directories in its
  `DOMAIN_DIRS` array).

### Common Patterns
- JSON config is machine-generated with a top-level `version` field — treat schema
  changes as the tool's business, not the repo's.

## Dependencies

### Internal
- None. No skill, script, or workflow in this repo reads these files.

### External
- The `tokensave` CLI — the sole producer and consumer of this directory.

<!-- MANUAL: -->
