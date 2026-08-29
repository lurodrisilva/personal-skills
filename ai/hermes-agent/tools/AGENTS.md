<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-08-29 -->

# tools

## Purpose
Read-only **Hermes Agent triage scripts** shipped with the `hermes-agent`
skill. Each answers one question about a local Hermes installation using only
file reads, `status`-class commands, and loopback GETs. They are starting
points to review before running, not an approval to change anything: they
never install, edit config, write `.env`, start/stop/reconfigure a process,
or send credentials — every mutation is a separate, human-approved action.

## Key Files
| File | Surfaces |
|------|----------|
| `hermes-env-audit.sh` | Install + config-split audit — binary + `hermes --version`, the `~/.hermes` directory contract (code dir, `state.db`, `config.yaml`, `.env`), `.env` permissions (must be 600), and the config-split invariant (key-shaped secrets belong in `.env`, never `config.yaml`). Degrades gracefully when `hermes` is not installed |
| `hermes-profile-inventory.sh` | Inventory of a Hermes home — profiles, skills, cron jobs, MCP servers, plugins, and memory-file sizes vs documented caps (MEMORY.md 2,200 chars / USER.md 1,375 chars). Env: `HERMES_HOME` to point at a non-default profile home |
| `hermes-surface-probe.sh` | What is listening right now — web dashboard `GET 127.0.0.1:9119/api/status` (public probe), API server `GET 127.0.0.1:8642/v1/health`, `hermes gateway status`, `hermes egress status` (iron-proxy). A non-listening port is a finding, not an error |

## For AI Agents

### Working In This Directory
- Keep every script **strictly read-only**: file reads, `status`-class
  commands, loopback GETs. If a task needs to start, stop, install, or edit
  anything, it does not belong in `tools/` — it is a gated action described
  in `../SKILL.md`.
- Never print secrets: `.env` contents are permission-checked and
  shape-checked, never echoed; probes send no credentials.
- Degrade gracefully when `hermes` is absent or nothing is listening —
  report the finding instead of erroring out.

### Testing Requirements
- Not covered by `scripts/validate-skills.sh` (the validator walks neither
  `ai/` nor any `tools/` scripts). Verify with `bash -n tools/*.sh` and a
  smoke run on a machine without Hermes installed (must report, not crash).

## Dependencies
- `bash`, standard file utilities, `curl` for the loopback probes, and the
  `hermes` CLI when present (its absence is itself a reported finding).

<!-- MANUAL: -->
