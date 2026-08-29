<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-08-29 -->

# tools

## Purpose
Read-only **Vercel Git-CI/CD triage scripts** shipped with the
`vercel-git-cicd` skill. Two are `bash` + `curl` + `jq` wrappers that answer
one question each about a project's Git wiring using only **GET** requests
against `api.vercel.com`; the third is **purely local** (git only, no
network, no token). They are starting points to review before running, not an
approval to change anything: they never connect/disconnect a repository,
deploy, trigger a hook, or edit settings — every mutation is a separate,
human-approved action.

## Key Files
| File | Surfaces |
|------|----------|
| `vercel-git-connection-audit.sh` | `GET /v9/projects/{p}` — provider/repo/production-branch from the `link` object, fork protection, LFS, plus the last 5 deployments' Git metadata (is Git actually driving deploys?). Env: `VERCEL_TOKEN`, `VERCEL_PROJECT` (required), `VERCEL_TEAM_ID`. Requires `jq` |
| `vercel-git-deployment-trace.sh` | `GET /v6/deployments?projectId=…` filtered locally by `BRANCH` or `SHA` prefix — state, target, ref, SHA, URL, author per deployment; explains CANCELED (auto-job-cancellation / verified-commits) vs ignored/skipped. Env: `VERCEL_TOKEN`, `VERCEL_PROJECT` (required), `VERCEL_TEAM_ID`, `BRANCH`, `SHA`, `LIMIT` (20). Requires `jq` |
| `vercel-ignore-step-doctor.sh` | Local dry-run of the Ignored Build Step — runs `git diff HEAD^ HEAD --quiet -- $ROOT_DIR` (or `$IGNORE_COMMAND`) and reports **exit 0 = Vercel would SKIP / exit 1 = would BUILD**; warns near the `--depth=10` shallow edge and hints `turbo-ignore` when `turbo.json` exists. Env: `ROOT_DIR` (`.`), `IGNORE_COMMAND`. No token, no network |

## For AI Agents

### Working In This Directory
- Keep every script **GET-only or purely local**. If a task needs a POST
  (trigger a hook, redeploy), it does not belong in `tools/` — it is a gated
  action described in `../SKILL.md`.
- `VERCEL_TOKEN` comes from the environment only — never an argument, never
  printed. Deploy-hook URLs must never appear in output or examples.
- Endpoint versions move independently on Vercel; on a 404, re-check the path
  against `https://openapi.vercel.sh/` before editing the script.
- `bash -n` after every edit; keep the executable bit.

### Testing Requirements
- Not covered by `scripts/validate-skills.sh` (it validates only SKILL.md
  files). Verify with `bash -n` and a token-less smoke run (the API scripts
  must fail fast with the `VERCEL_TOKEN` usage error; the doctor script must
  run in any git checkout).

## Dependencies
- `curl` + `jq` (the two API scripts refuse to run without `jq`), `git` (the
  doctor script), a read-scope Vercel token in `VERCEL_TOKEN`.

<!-- MANUAL: -->
