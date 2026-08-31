#!/usr/bin/env bash
# kapso-api-probe.sh — READ-ONLY probe of a Kapso project.
#
# Answers "is the Platform API reachable and authorized, and what does the
# project hold?" using only GET calls: /whatsapp/phone_numbers, /customers,
# and the rate-limit headers Kapso returns on every response. It NEVER
# creates, updates, or deletes anything, and never prints the API key.
#
# Usage:
#   KAPSO_API_KEY=... bash kapso-api-probe.sh
set -euo pipefail

BASE="${KAPSO_BASE_URL:-https://api.kapso.ai/platform/v1}"

say() { printf '%s\n' "$*"; }

say "== Kapso API probe (read-only) =="
say "Base URL: $BASE"
say ""

if [[ -z "${KAPSO_API_KEY:-}" ]]; then
  say "[WARN] KAPSO_API_KEY is not set — cannot probe authorized endpoints."
  say "       Create a project API key in the Kapso dashboard under"
  say "       Integrations -> API keys. Nothing was probed."
  exit 0
fi

auth=(-H "X-API-Key: $KAPSO_API_KEY")

probe_get() { # $1 label, $2 path
  local label="$1" path="$2" code
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "${auth[@]}" "$BASE$path" 2>/dev/null) || code="000"
  case "$code" in
    000) say "  $label: unreachable ($BASE$path)" ;;
    200) say "  $label: HTTP 200 ok" ;;
    401) say "  $label: HTTP 401 (bad or revoked key)" ;;
    403) say "  $label: HTTP 403 (forbidden)" ;;
    429) say "  $label: HTTP 429 (rate limited — honor Retry-After)" ;;
    *)   say "  $label: HTTP $code" ;;
  esac
}

say "-- Reachability / auth --"
probe_get "GET /whatsapp/phone_numbers" "/whatsapp/phone_numbers"
probe_get "GET /customers             " "/customers"

say ""
say "-- Rate-limit headroom (fixed per-minute window, per API key) --"
headers=$(curl -s -D - -o /dev/null --max-time 10 "${auth[@]}" "$BASE/customers" 2>/dev/null || true)
limit=$(printf '%s' "$headers" | tr -d '\r' | awk -F': ' 'tolower($1)=="x-ratelimit-limit"{print $2}')
remaining=$(printf '%s' "$headers" | tr -d '\r' | awk -F': ' 'tolower($1)=="x-ratelimit-remaining"{print $2}')
[[ -n "$limit" ]] && say "  X-RateLimit-Limit: $limit (Free/Legacy 100, Pro 500, Platform 1000, Enterprise 2000)"
[[ -n "$remaining" ]] && say "  X-RateLimit-Remaining: $remaining"
[[ -z "$limit" && -z "$remaining" ]] && say "  (rate-limit headers not observed)"

say ""
say "-- Project snapshot (needs jq for detail) --"
if command -v jq >/dev/null 2>&1; then
  numbers=$(curl -s --max-time 10 "${auth[@]}" "$BASE/whatsapp/phone_numbers" 2>/dev/null || true)
  if printf '%s' "$numbers" | jq -e '.data' >/dev/null 2>&1; then
    say "  WhatsApp numbers: $(printf '%s' "$numbers" | jq '.data | length')"
    printf '%s' "$numbers" | jq -r '.data[] | "    \(.phone_number // .id // "?") status=\(.status // "?")"' 2>/dev/null | head -10
  else
    say "  (phone-number list unavailable)"
  fi

  customers=$(curl -s --max-time 10 "${auth[@]}" "$BASE/customers" 2>/dev/null || true)
  if printf '%s' "$customers" | jq -e '.data' >/dev/null 2>&1; then
    say "  customers: $(printf '%s' "$customers" | jq '.data | length') (first page)"
  fi
else
  say "  install jq for number/customer detail"
fi

say ""
say "Done. Probe only — sends, provisioning, and webhook changes are separate, human-approved actions."
exit 0
