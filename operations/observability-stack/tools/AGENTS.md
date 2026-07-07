<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-07-07 | Updated: 2026-07-07 -->

# tools

## Purpose
Read-only **observability config validators** shipped with the `observability-stack`
skill. Each is a small `bash` wrapper around a stack CLI — `promtool` (Prometheus),
`otelcol`/`otelcol-contrib` (OpenTelemetry Collector), `amtool` (Alertmanager) — that
answers one question: *does this config / rule / route parse and mean what I think?*
They are **local config validators** (no live cluster needed) and **starting points to
review before running**, not a certified check. They **only read / validate / simulate**
(`check config`, `check rules`, `validate`, `components`, `config routes show|test`,
optional read-only `query instant`) — they never reload, apply, push, start a collector,
add a silence, or add an alert. Each tolerates its binary being absent (clear message +
exit 0) so it degrades gracefully where the CLI isn't installed.

## Key Files
| File | Surfaces |
|------|----------|
| `promtool-check.sh` | `promtool check config` + `promtool check rules` (+ optional read-only `promtool query instant` when `PROM_URL`+`PROM_QUERY` set) — owned by `prometheus-rules-author` |
| `otel-config-validate.sh` | `otelcol validate --config` (contrib then core) + `components` listing — owned by `otel-collector-engineer` |
| `alert-routing-check.sh` | `amtool check-config` + `amtool config routes show` (+ optional read-only `amtool config routes test` when `ROUTE_TEST_LABELS` set) — owned by `slo-alerting-engineer` |

## For AI Agents

### Working In This Directory
- **Read-only is a hard invariant.** Every CLI call must be a validator / read /
  simulation — `check`, `validate`, `components`, `config routes show`,
  `config routes test`, or `query instant`. **Never** add a mutating verb. In
  particular, **`amtool silence add` and `amtool alert add` are banned**, as is any
  `apply` / `push` / `import` / `reload` / starting the collector (`otelcol` with no
  `validate`). A "validator" that silences an alert or applies a route is worse than
  none — a wrong route can silence a real page.
- Each script starts with `set -euo pipefail`, presence-checks its binary and exits
  cleanly with a message if it is absent, and carries a header comment stating it is
  read-only, what it needs, and that it is a review-before-running starting point.
- Keep them dependency-light: the stack CLI + POSIX tools. Do **not** require `jq`.
  Tolerate missing config files / unmatched globs / absent subcommands with a clear
  message and continue.
- Inputs are overridable via env: `PROM_CONFIG` / `RULES_GLOB` / `PROM_URL` /
  `PROM_QUERY` (promtool), `OTEL_CONFIG` (otelcol), `AM_CONFIG` / `ROUTE_TEST_LABELS`
  (amtool) — with sensible local defaults.

### Testing Requirements
- **Not** covered by `scripts/validate-skills.sh` (it only validates `SKILL.md`).
  Before committing any change here, verify manually:
  1. `bash -n tools/*.sh` (syntax) — and `shellcheck` if available.
  2. No mutating `amtool` verb:
     `grep -nE 'amtool[[:space:]]+(silence[[:space:]]+add|alert[[:space:]]+add)' tools/*.sh`
     returns nothing. Also confirm no `apply` / `push` / `import` / `reload`.
  3. Scripts are executable (`chmod +x`).

### Common Patterns
- Header block (purpose + read-only + needs + "review before running") → `set -euo
  pipefail` → binary presence check (exit 0 if absent) → one or more validator/read
  calls (`check` / `validate` / `config routes show|test` / `query instant`) guarded by
  file/env existence → a short "Goal:" line explaining what to do with the output and
  that every config change is a separate, gated Git change.

## Dependencies

### Internal
- `../SKILL.md` — the `observability-stack` skill; its **REFERENCE** and Phase A/B/E
  sections document these scripts. Ownership: `prometheus-rules-author` →
  `promtool-check.sh`; `otel-collector-engineer` → `otel-config-validate.sh`;
  `slo-alerting-engineer` → `alert-routing-check.sh`.

### External
- `promtool` (Prometheus), `otelcol`/`otelcol-contrib` (OpenTelemetry Collector), and
  `amtool` (Alertmanager) — each optional and read-only — plus POSIX `bash`. No `jq`.
  No version pinned.

<!-- MANUAL: -->
