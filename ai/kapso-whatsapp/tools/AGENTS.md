<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-08-31 -->

# tools

## Purpose
Read-only **Kapso triage scripts** shipped with the `kapso-whatsapp`
skill. All three probe a Kapso project through GET-only Platform API
calls (`https://api.kapso.ai/platform/v1`). They are starting points to
review before running, not an approval to change anything: they never
send messages, never create/update/delete webhooks, workflows, numbers,
or customers, and never print the API key — every mutation is a
separate, human-approved action.

## Key Files
| File | Surfaces |
|------|----------|
| `kapso-api-probe.sh` | Reachability + auth + project snapshot — `GET /whatsapp/phone_numbers`, `GET /customers`, and the `X-RateLimit-Limit`/`X-RateLimit-Remaining` headers Kapso returns on every response. Env: `KAPSO_API_KEY` (required, never printed), `KAPSO_BASE_URL` (override, defaults to the Platform API) |
| `kapso-webhook-audit.sh` | Webhook posture — `GET /whatsapp/webhooks` (project + number-scoped), per-number `GET /whatsapp/phone_numbers/{id}/webhooks`, `GET /webhook_deliveries`; flags inactive (auto-paused) webhooks with the 85%-failure pause rule. Env: `KAPSO_API_KEY`, `KAPSO_BASE_URL`; requires `jq` |
| `kapso-workflow-inventory.sh` | Automation snapshot — `GET /workflows`, per-workflow `GET /workflows/{id}/executions`, `GET /functions` with statuses. Env: `KAPSO_API_KEY`, `KAPSO_BASE_URL`; requires `jq` |

## For AI Agents

### Working In This Directory
- Keep every script **read-only**: GET calls only. A write call (message
  send, webhook create/update/delete, workflow push/start/resume,
  function deploy, number provisioning) never belongs here — those are
  gated actions described in `../SKILL.md`.
- `KAPSO_API_KEY` comes from the environment only — never an argument,
  never printed.
- Scripts must degrade gracefully: exit 0 with a usage warning when the
  key is missing, tolerate absent `jq` where feasible, and never fail in
  a way that suggests a mutation happened.

### Testing Requirements
- Not covered by `scripts/validate-skills.sh` (the validator walks
  neither `ai/` nor any `tools/` scripts). Verify with
  `bash -n ai/kapso-whatsapp/tools/*.sh` and a key-less smoke run (each
  script must exit 0 with the `[WARN] KAPSO_API_KEY is not set` notice).

## Dependencies
- `curl` + `jq`; a Kapso project API key in `KAPSO_API_KEY` (created in
  the dashboard under Integrations → API keys).

<!-- MANUAL: -->
