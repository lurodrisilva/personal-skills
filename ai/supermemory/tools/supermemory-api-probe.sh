#!/usr/bin/env bash
# supermemory-api-probe.sh — READ-ONLY probe of a Supermemory deployment.
#
# Answers "is the API reachable and authorized, and what does the org hold?"
# using only read calls: GET /v3/settings, GET /v3/container-tags/list,
# GET /v3/documents/processing, and POST /v3/documents/list (a read-semantics
# pagination call with limit=1). It NEVER creates, updates, or deletes
# anything, and never prints the API key.
#
# Usage:
#   SUPERMEMORY_API_KEY=sm_... bash supermemory-api-probe.sh
#   SUPERMEMORY_BASE_URL=http://localhost:6767 SUPERMEMORY_API_KEY=... \
#     bash supermemory-api-probe.sh          # self-hosted instance
set -euo pipefail

BASE="${SUPERMEMORY_BASE_URL:-https://api.supermemory.ai}"

say() { printf '%s\n' "$*"; }

say "== Supermemory API probe (read-only) =="
say "Base URL: $BASE"
say ""

if [[ -z "${SUPERMEMORY_API_KEY:-}" ]]; then
  say "[WARN] SUPERMEMORY_API_KEY is not set — cannot probe authorized endpoints."
  say "       Create a key at console.supermemory.ai (or read the auto-generated"
  say "       key of a local instance). Nothing was probed."
  exit 0
fi

auth=(-H "Authorization: Bearer $SUPERMEMORY_API_KEY" -H "Content-Type: application/json")

probe_get() { # $1 label, $2 path
  local label="$1" path="$2" code
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "${auth[@]}" "$BASE$path" 2>/dev/null) || code="000"
  case "$code" in
    000) say "  $label: unreachable ($BASE$path)" ;;
    200) say "  $label: HTTP 200 ok" ;;
    401) say "  $label: HTTP 401 (bad or revoked key)" ;;
    402) say "  $label: HTTP 402 (credits exhausted)" ;;
    403) say "  $label: HTTP 403 (forbidden)" ;;
    *)   say "  $label: HTTP $code" ;;
  esac
}

say "-- Reachability / auth --"
probe_get "GET /v3/settings            " "/v3/settings"
probe_get "GET /v3/container-tags/list " "/v3/container-tags/list"
probe_get "GET /v3/documents/processing" "/v3/documents/processing"

say ""
say "-- Org snapshot (needs jq for detail) --"
if command -v jq >/dev/null 2>&1; then
  tags=$(curl -s --max-time 10 "${auth[@]}" "$BASE/v3/container-tags/list" 2>/dev/null || true)
  if [[ -n "$tags" ]] && printf '%s' "$tags" | jq -e 'type == "array"' >/dev/null 2>&1; then
    say "  container tags: $(printf '%s' "$tags" | jq 'length')"
    printf '%s' "$tags" | jq -r '.[] | "    \(.containerTag): docs=\(.documentCount // "?") memories=\(.memoryCount // "?")"' 2>/dev/null | head -15
  else
    say "  (container-tags list unavailable or not an array — scoped keys cannot read it)"
  fi

  docs=$(curl -s --max-time 10 "${auth[@]}" -X POST "$BASE/v3/documents/list" \
           -d '{"page": 1, "limit": 1}' 2>/dev/null || true)
  total=$(printf '%s' "$docs" | jq -r '.pagination.totalItems // empty' 2>/dev/null || true)
  [[ -n "$total" ]] && say "  documents total: $total" || say "  (document count unavailable)"

  processing=$(curl -s --max-time 10 "${auth[@]}" "$BASE/v3/documents/processing" 2>/dev/null || true)
  inflight=$(printf '%s' "$processing" | jq -r '.totalCount // empty' 2>/dev/null || true)
  [[ -n "$inflight" ]] && say "  documents in-flight: $inflight"
else
  say "  install jq for tag/document counts"
fi

say ""
say "Done. Probe only — key minting, ingestion, and deletion are separate, human-approved actions."
exit 0
