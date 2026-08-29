<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-08-29 -->

# tools

## Purpose
Read-only **Supermemory triage scripts** shipped with the `supermemory`
skill. Two probe a Supermemory deployment (cloud or self-hosted) using only
read calls — GETs plus read-semantics `list`/`search` POSTs — and one audits
a local repo's Supermemory wiring with file reads only. They are starting
points to review before running, not an approval to change anything: they
never create, update, or delete documents/memories/tags, never install
packages, and never print the API key — every mutation is a separate,
human-approved action.

## Key Files
| File | Surfaces |
|------|----------|
| `supermemory-api-probe.sh` | Reachability + auth + org snapshot — `GET /v3/settings`, `GET /v3/container-tags/list`, `GET /v3/documents/processing`, and `POST /v3/documents/list` with `limit=1` (read-semantics pagination). Env: `SUPERMEMORY_API_KEY` (required, never printed), `SUPERMEMORY_BASE_URL` (e.g. `http://localhost:6767` for self-hosted) |
| `supermemory-search-probe.sh` | One end-to-end retrieval check — a single `POST /v4/search` (read-semantics query) reporting timing, totals, and top similarities. Env: `SUPERMEMORY_API_KEY`, `Q` (the query), `TAG` (containerTag), plus knobs documented in the header |
| `supermemory-config-audit.sh` | How THIS repo is wired — SDK dependencies, `@supermemory/tools` version, env-var usage, hardcoded-key detection (warned, never printed), MCP config entries, local self-hosted state. Local file reads only, zero network. Usage: `bash supermemory-config-audit.sh [/path/repo]` |

## For AI Agents

### Working In This Directory
- Keep every script **read-only**: GETs and read-semantics list/search calls
  for the API probes; pure file reads for the config audit. A write call
  (`add`, `PATCH`, `DELETE`, `forget-matching`) never belongs here — those
  are gated actions described in `../SKILL.md`.
- `SUPERMEMORY_API_KEY` comes from the environment only — never an argument,
  never printed; hardcoded keys found by the audit are warned about, never
  echoed.
- Self-hosted parity: scripts must work against `SUPERMEMORY_BASE_URL`
  overrides, not just the cloud endpoint.

### Testing Requirements
- Not covered by `scripts/validate-skills.sh` (the validator walks neither
  `ai/` nor any `tools/` scripts). Verify with `bash -n ai/supermemory/tools/*.sh`
  and a key-less smoke run (the API probes must fail fast with a usage
  error; the config audit must run anywhere).

## Dependencies
- `curl` + `jq` for the API probes; `bash` + `grep` for the config audit; a
  read-scope Supermemory key in `SUPERMEMORY_API_KEY` for the two probes.

<!-- MANUAL: -->
