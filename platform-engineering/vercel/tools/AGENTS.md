<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-08-28 | Updated: 2026-08-28 -->

# tools

## Purpose
Read-only **Vercel triage scripts** shipped with the `vercel` skill. Each is a
small `bash` + `curl` (+ `jq`) wrapper that answers one question about a Vercel
project — who am I and what shipped, are the env vars shaped safely, and do the
domains actually verify — using only **GET** requests against
`api.vercel.com`. They are **starting points to review before running**, not an
approval to change anything. They never deploy, promote, roll back, or mutate
env vars, domains, DNS, aliases, or firewall config; every mutation is a
separate, human-approved action.

## Key Files
| File | Surfaces |
|------|----------|
| `vercel-project-status.sh` | `GET /v2/user` identity check, optional `GET /v9/projects/{p}` project card, and `GET /v7/deployments?limit=N` with per-deployment `readyState`/`readySubstate`, target, and URL; flags ERROR/CANCELED/BLOCKED deployments. Env: `VERCEL_TOKEN` (required), `VERCEL_TEAM_ID`, `VERCEL_PROJECT`, `LIMIT` (10) |
| `vercel-env-audit.sh` | `GET /v10/projects/{p}/env` — prints **key · type · targets · branch only, never values**; flags non-`sensitive` variables targeting production and duplicate keys; **requires `jq`** (refuses to run without it so raw JSON with values can never hit stdout). Env: `VERCEL_TOKEN`, `VERCEL_PROJECT` (both required), `VERCEL_TEAM_ID` |
| `vercel-domain-dns-check.sh` | `GET /v9/projects/{p}/domains` + per-domain `GET /v6/domains/{d}/config` (`misconfigured` — Vercel's own verdict), optional live `dig` A/CNAME/NS/CAA resolution with a CAA-without-Let's-Encrypt warning. Env: `VERCEL_TOKEN`, `VERCEL_PROJECT` (required), `VERCEL_TEAM_ID`, `RESOLVE=0` to skip lookups |

## For AI Agents

### Working In This Directory
- **Read-only is a hard invariant.** Every API call must be a `GET`. **Never**
  add a `POST`/`PATCH`/`DELETE`, a deploy/promote/rollback, an env write, a
  domain/DNS/alias mutation, or a firewall change. A "triage" script that
  mutates the platform everyone ships on is worse than none.
- **Never print secret material.** `VERCEL_TOKEN` comes from the environment
  (never an argument — process lists and shell history leak) and is never
  echoed. `vercel-env-audit.sh` hard-requires `jq` specifically so unfiltered
  API JSON (which can carry values for non-sensitive vars) never reaches
  stdout — keep that requirement, and never call the decrypted-env endpoint.
- Each script starts with `set -euo pipefail`, verifies its binaries, states
  its read-only contract in the header, and closes with a "Goal:" paragraph
  restating that every change is a separate, human-approved action.
- **Endpoint versions move.** `/v2/user`, `/v7/deployments`, `/v9/projects`,
  `/v10/projects/{p}/env`, `/v6/domains/{d}/config` were correct at authoring
  time — if a call 404s, re-check against `openapi.vercel.sh` and update the
  path, don't work around it with a broader scope.
- Team scoping is a `teamId` query param appended when `VERCEL_TEAM_ID` is set;
  keep that pattern instead of hardcoding a team.
- `jq` degrades gracefully in the status and domain scripts (raw JSON heads),
  but never in the env audit. `dig` is optional; DNS advice always defers to
  the **project's domain card** as the source of truth.

### Testing Requirements
- `bash -n <script>` must pass for every script; keep them executable
  (`chmod +x`). The repo has no shell test runner.
- These files live outside the validator's SKILL.md walk — the parent
  `../SKILL.md` is what `scripts/validate-skills.sh` checks. Re-run it after
  touching the skill regardless.

### Common Patterns
- Header contract → binary/env checks → `vget`-style GET helper with team
  scoping → sectioned `== … ==` output → findings → a closing "Goal:"
  paragraph naming the read-only boundary.
- Findings point outward: a misconfigured domain says "read the domain card", a
  non-sensitive prod var says "make it sensitive + redeploy" — the fix is
  always a gated change performed elsewhere, never by the script.

## Dependencies

### External
- `curl` — all API reads.
- `jq` — required by `vercel-env-audit.sh`; optional elsewhere.
- `dig` (optional) — live DNS resolution in the domain check.
- A Vercel access token with read access to the target team/project.

<!-- MANUAL: -->
