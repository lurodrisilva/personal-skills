#!/usr/bin/env bash
# kapso-webhook-audit.sh — READ-ONLY audit of a Kapso project's webhooks.
#
# Answers "what webhooks exist, on which scope/kind, are any paused, and how
# are recent deliveries doing?" using only GET calls: /whatsapp/webhooks
# (project + number-scoped listing), /whatsapp/phone_numbers, and
# /webhook_deliveries. It NEVER creates, updates, or deletes anything, and
# never prints the API key or webhook secrets.
#
# Usage:
#   KAPSO_API_KEY=... bash kapso-webhook-audit.sh
set -euo pipefail

BASE="${KAPSO_BASE_URL:-https://api.kapso.ai/platform/v1}"

say() { printf '%s\n' "$*"; }

say "== Kapso webhook audit (read-only) =="
say "Base URL: $BASE"
say ""

if [[ -z "${KAPSO_API_KEY:-}" ]]; then
  say "[WARN] KAPSO_API_KEY is not set — cannot audit webhooks."
  say "       Create a project API key in the Kapso dashboard under"
  say "       Integrations -> API keys. Nothing was probed."
  exit 0
fi

auth=(-H "X-API-Key: $KAPSO_API_KEY")

if ! command -v jq >/dev/null 2>&1; then
  say "[WARN] jq is required for this audit. Install jq and re-run."
  exit 0
fi

say "-- Webhooks (project-scoped and phone-number-scoped) --"
hooks=$(curl -s --max-time 10 "${auth[@]}" "$BASE/whatsapp/webhooks" 2>/dev/null || true)
if printf '%s' "$hooks" | jq -e '.data' >/dev/null 2>&1; then
  count=$(printf '%s' "$hooks" | jq '.data | length')
  say "  webhooks: $count"
  printf '%s' "$hooks" | jq -r '.data[] |
    "    \(.id // "?") kind=\(.kind // "kapso") active=\(.active // "?") url=\(.url // "?") events=\((.events // []) | join(","))"' \
    2>/dev/null | head -20
  paused=$(printf '%s' "$hooks" | jq '[.data[] | select(.active == false)] | length')
  [[ "$paused" != "0" ]] && say "  [WARN] $paused webhook(s) inactive — auto-pause triggers at >=85% failure (>=20 deliveries, >=10 failures, 15-min window); re-enable from Integrations -> Webhooks after fixing the endpoint"
else
  say "  (webhook list unavailable)"
fi

say ""
say "-- Per-number webhooks --"
numbers=$(curl -s --max-time 10 "${auth[@]}" "$BASE/whatsapp/phone_numbers" 2>/dev/null || true)
if printf '%s' "$numbers" | jq -e '.data' >/dev/null 2>&1; then
  printf '%s' "$numbers" | jq -r '.data[].id' 2>/dev/null | head -5 | while read -r pn_id; do
    [[ -z "$pn_id" ]] && continue
    nhooks=$(curl -s --max-time 10 "${auth[@]}" "$BASE/whatsapp/phone_numbers/$pn_id/webhooks" 2>/dev/null || true)
    n=$(printf '%s' "$nhooks" | jq '.data | length' 2>/dev/null || echo "?")
    say "  number $pn_id: $n webhook(s)"
  done
else
  say "  (phone-number list unavailable)"
fi

say ""
say "-- Recent webhook deliveries --"
deliveries=$(curl -s --max-time 10 "${auth[@]}" "$BASE/webhook_deliveries" 2>/dev/null || true)
if printf '%s' "$deliveries" | jq -e '.data' >/dev/null 2>&1; then
  printf '%s' "$deliveries" | jq -r '.data[] |
    "    \(.event // .event_type // "?") status=\(.status // "?") http=\(.response_status // .response_code // "-")"' \
    2>/dev/null | head -15
else
  say "  (delivery list unavailable)"
fi

say ""
say "Done. Audit only — creating, updating, deleting, or re-enabling webhooks are separate, human-approved actions."
exit 0
