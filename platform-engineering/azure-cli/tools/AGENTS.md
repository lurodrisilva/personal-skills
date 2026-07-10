<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-07-10 | Updated: 2026-07-10 -->

# tools

## Purpose
Read-only **Azure CLI triage scripts** shipped with the `azure-cli` skill. Each is a small
`bash` + `az` wrapper that answers one question about the *local* CLI setup or the *estate* —
who am I, is my config sane, what resources exist — using only `az ... show` / `list` /
`get` / `query`. They are **starting points to review before running**, not certified
reports, and they **only read** — they never log in, provision, set config, install, resize,
or delete. RBAC needed is at most the built-in **Reader** role (the inventory script); the
identity check needs only a valid `az login`; the config audit needs no Azure RBAC at all.

## Key Files
| File | Surfaces |
|------|----------|
| `az-identity-check.sh` | active subscription / tenant / user / cloud + all visible subs (`az account show`/`list`, `az cloud show`); reads only the token *expiry*, never the token |
| `az-config-audit.sh` | local `az version`, effective config, installed extensions, and hygiene smells (telemetry ON, `AZURE_CLIENT_SECRET` in env, TLS-verification disabled, no default output) |
| `az-resource-inventory.sh` | subscriptions, resource groups, and `az resource list` shaped with JMESPath multiselect hashes (doubles as a `--query` demo) |

## For AI Agents

### Working In This Directory
- **Read-only is a hard invariant.** Every `az` call must be a read
  (`show` / `list` / `get` / `query`). Never add a mutating verb — no `login`/`logout`/
  `create`/`delete`/`update`/`set`/`start`/`stop`/`restart`/`deallocate`/`purchase`/`add`/
  `remove`/`apply`/`import`/`enable`/`disable`/`cancel`/`move`/`reset`/`regenerate`. A
  "triage" script that changes identity, config, or resources is worse than none. Logging in,
  changing a subscription/cloud, installing an extension, or touching a resource is always a
  separate, human-approved action.
- **Never print a token.** `az-identity-check.sh` may call `az account get-access-token` but
  only with `--query expires_on` — the `accessToken` field is a live Bearer credential and
  must never be emitted, logged, or captured.
- Each script starts with `set -euo pipefail`, checks `az` is on `PATH`, and carries a header
  comment stating it is read-only, the RBAC it needs, and that it is a review-before-running
  starting point.
- Keep them dependency-light: `az` + POSIX tools. Do **not** require `jq` (use `--query`
  JMESPath / `-o table`). Scope is overridable via env (`AZ_SUBSCRIPTION` / `AZ_GROUP`) with
  sensible defaults (`az account show` for the current subscription).

### Testing Requirements
- **Not** covered by `scripts/validate-skills.sh` (it only validates `SKILL.md`). Before
  committing any change here, verify manually:
  1. `bash -n tools/*.sh` (syntax) — and `shellcheck` if available.
  2. No mutating subcommand:
     `grep -nE 'az[[:space:]]+[a-z0-9 -]*[[:space:]](login|logout|create|delete|update|set|start|stop|restart|deallocate|purchase|add|remove|apply|import|enable|disable|cancel|move|reset|regenerate)([[:space:]]|$)' tools/*.sh`
     returns nothing.
  3. No token print: the only `get-access-token` use is paired with `--query expires_on`.
  4. Scripts are executable (`chmod +x`).

### Common Patterns
- Header block (purpose + read-only + RBAC + "review before running") → `set -euo pipefail`
  → `command -v az` guard → env-overridable scope → sectioned read-only `az … --query … -o
  table` output with graceful `|| echo "(unavailable)"` fallbacks.

<!-- MANUAL: -->
