<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-07-10 | Updated: 2026-07-10 -->

# tools

## Purpose
Read-only **GitHub CLI triage scripts** shipped with the `github-cli` skill. Each is a small
`bash` + `gh` wrapper that answers one question about the *local* CLI setup or the *estate* —
who am I authenticated as, is my config sane, what can this token see — using only
`gh auth status` / `gh api` GETs / `gh config get`/`list` / `gh <x> list`/`view`. They are
**starting points to review before running**, not certified reports, and they **only read** —
they never log in, refresh, switch, set config, install an extension, or create/edit/delete a
repo/PR/issue/release/secret. The token needed is at most repo-read; the config audit needs no
GitHub access at all.

## Key Files
| File | Surfaces |
|------|----------|
| `gh-auth-check.sh` | active account/host (`gh auth status`, `gh api user`), effective token **source** (env vs keyring), rate-limit headroom; **never prints a token**, never calls `gh auth token` |
| `gh-config-audit.sh` | `gh --version`, effective `gh config list`, installed extensions, hygiene smells (token env vars present, telemetry/prompt not hardened, a PAT pattern in `./.env`) |
| `gh-api-inventory.sh` | read-only estate + `--json`/`--jq` demo — `gh api rate_limit`/`user`, `gh repo list --json … --jq`, optional `gh api repos/{owner}/{repo}` |

## For AI Agents

### Working In This Directory
- **Read-only is a hard invariant.** Every `gh` call must be a read: `gh auth status`,
  `gh api <path>` **without** `-X/--method POST|PUT|PATCH|DELETE`, `gh config get`/`list`,
  `gh <group> list`/`view`. Never add a mutating verb — no `login`/`logout`/`refresh`/`switch`/
  `setup-git`/`create`/`delete`/`edit`/`set`/`merge`/`close`/`reopen`/`rename`/`transfer`/
  `archive`/`sync`/`fork`/`clone`/`install`/`upgrade`/`run`/`rerun`/`cancel`/`upload`/
  `download`/`enable`/`disable`. A "triage" script that changes identity, config, or a resource
  is worse than none. Logging in, changing config, installing an extension, or touching a
  repo/PR/issue is always a separate, human-approved action.
- **Never print a token.** These scripts must NOT call `gh auth token` (it emits a live
  credential). `gh-auth-check.sh` reports only the token *source* and the redacted
  `gh auth status`. `gh-config-audit.sh` uses `printenv` only to test the *presence* of a token
  env var, never its value.
- Each script starts with `set -euo pipefail`, checks `gh` is on `PATH`, and carries a header
  comment stating it is read-only, the access it needs, and that it is a review-before-running
  starting point.
- Keep them dependency-light: `gh` + POSIX tools. Do **not** require external `jq` — use the
  built-in `--jq` on `gh api`/`gh <x> list`. Scope is overridable via env
  (`GH_HOST` / `GH_REPO` / `LIMIT`) with sensible defaults.

### Testing Requirements
- **Not** covered by `scripts/validate-skills.sh` (it only validates `SKILL.md`). Before
  committing any change here, verify manually:
  1. `bash -n tools/*.sh` (syntax) — and `shellcheck` if available.
     (Comments (`# …`) and advisory `echo` help-text are excluded from checks 2–4 below by the
     trailing `grep -vE ':[0-9]+:[[:space:]]*#'` — the invariant is about *executed* `gh` calls.)
  2. No mutating subcommand:
     `grep -nE 'gh[[:space:]]+[a-z-]*[[:space:]]*(login|logout|refresh|switch|setup-git|create|delete|edit|set|merge|close|reopen|rename|transfer|archive|unarchive|sync|fork|clone|install|upgrade|remove|run|rerun|cancel|upload|download|enable|disable|pin|unpin|lock|unlock)([[:space:]]|$)' tools/*.sh | grep -vE ':[0-9]+:[[:space:]]*#'`
     returns nothing.
  3. No non-GET API call:
     `grep -nE 'gh api .*(-X|--method) *(POST|PUT|PATCH|DELETE)' tools/*.sh | grep -vE ':[0-9]+:[[:space:]]*#'`
     returns nothing.
  4. No token print: `grep -n 'gh auth token' tools/*.sh | grep -vE ':[0-9]+:[[:space:]]*#'`
     returns nothing.
  5. Scripts are executable (`chmod +x`).

### Common Patterns
- Header block (purpose + read-only + access needed + "review before running") →
  `set -euo pipefail` → `command -v gh` guard → env-overridable scope
  (`GH_HOST`/`GH_REPO`/`LIMIT`) → sectioned read-only `gh … --json … --jq` output with graceful
  `|| echo "(unavailable)"` fallbacks.

<!-- MANUAL: -->
