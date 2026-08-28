#!/usr/bin/env bash
# hermes-surface-probe.sh — READ-ONLY probe of Hermes Agent's local surfaces.
#
# Answers "what is listening right now?" with status reads and local GETs only:
#   - web dashboard  : GET http://127.0.0.1:9119/api/status  (public probe)
#   - API server     : GET http://127.0.0.1:8642/v1/health   (OpenAI-compatible)
#   - gateway        : `hermes gateway status`
#   - egress firewall: `hermes egress status`   (iron-proxy)
#
# It NEVER starts, stops, restarts, or reconfigures anything, and it sends no
# credentials. A non-listening port is a finding, not an error.
#
# Usage:
#   bash hermes-surface-probe.sh
#   DASH_PORT=9119 API_PORT=8642 bash hermes-surface-probe.sh
#   PROBE_CMDS=0 bash hermes-surface-probe.sh    # skip `hermes ... status` calls
set -euo pipefail

DASH_PORT="${DASH_PORT:-9119}"
API_PORT="${API_PORT:-8642}"
PROBE_CMDS="${PROBE_CMDS:-1}"

say() { printf '%s\n' "$*"; }

probe_http() { # $1 label, $2 url
  local label="$1" url="$2" code
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 "$url" 2>/dev/null) || code="000"
  if [[ "$code" == "000" ]]; then
    say "  $label: not listening ($url)"
  else
    say "  $label: HTTP $code ($url)"
  fi
}

say "== Hermes Agent surface probe (read-only) =="
say ""
say "-- HTTP surfaces (loopback only) --"
probe_http "dashboard /api/status " "http://127.0.0.1:${DASH_PORT}/api/status"
probe_http "api-server /v1/health " "http://127.0.0.1:${API_PORT}/v1/health"

if [[ "$PROBE_CMDS" == "1" ]] && command -v hermes >/dev/null 2>&1; then
  say ""
  say "-- hermes gateway status --"
  hermes gateway status 2>&1 | sed 's/^/  /' || say "  (gateway status unavailable)"
  say ""
  say "-- hermes egress status (iron-proxy) --"
  hermes egress status 2>&1 | sed 's/^/  /' || say "  (egress status unavailable)"
elif [[ "$PROBE_CMDS" == "1" ]]; then
  say ""
  say "  [info] hermes binary not on PATH — skipped gateway/egress status"
fi

say ""
say "Reminder: dashboard auth is OFF only on loopback (fail-closed elsewhere);"
say "the API server exposes the FULL toolset including terminal — API_SERVER_KEY is mandatory."
say "Starting/stopping any of these is a separate, human-approved action."
exit 0
