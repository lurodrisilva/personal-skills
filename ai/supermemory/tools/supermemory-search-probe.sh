#!/usr/bin/env bash
# supermemory-search-probe.sh — READ-ONLY end-to-end retrieval check.
#
# Runs ONE search against POST /v4/search (a read-semantics query call) and
# reports timing, totals, and top similarities. It NEVER writes, updates, or
# deletes anything, and never prints the API key.
#
# Usage:
#   SUPERMEMORY_API_KEY=sm_... Q="what do we know about invoicing" \
#     TAG="org:acme:user:jane" bash supermemory-search-probe.sh
#
# Env knobs:
#   Q      search query                  (default: "smoke test query")
#   TAG    containerTag to scope to      (default: unset — org-wide)
#   MODE   memories | documents | hybrid (default: memories)
#   LIMIT  max results 1-100             (default: 5)
#   SUPERMEMORY_BASE_URL                 (default: https://api.supermemory.ai)
set -euo pipefail

BASE="${SUPERMEMORY_BASE_URL:-https://api.supermemory.ai}"
Q="${Q:-smoke test query}"
MODE="${MODE:-memories}"
LIMIT="${LIMIT:-5}"

say() { printf '%s\n' "$*"; }

say "== Supermemory search probe (read-only) =="
say "Base URL: $BASE"
say "Query: $Q"
say "Mode: $MODE  Limit: $LIMIT  Tag: ${TAG:-<none — org-wide>}"
say ""

if [[ -z "${SUPERMEMORY_API_KEY:-}" ]]; then
  say "[WARN] SUPERMEMORY_API_KEY is not set — nothing probed."
  exit 0
fi
if ! command -v jq >/dev/null 2>&1; then
  say "[WARN] jq is required to build/parse the request safely. Install jq first."
  exit 0
fi
if ! [[ "$LIMIT" =~ ^[0-9]+$ ]]; then
  say "[WARN] LIMIT must be a positive integer (got: $LIMIT) — nothing probed."
  exit 0
fi

body=$(jq -n --arg q "$Q" --arg mode "$MODE" --argjson limit "$LIMIT" \
  '{q: $q, searchMode: $mode, limit: $limit}')
if [[ -n "${TAG:-}" ]]; then
  body=$(printf '%s' "$body" | jq --arg tag "$TAG" '. + {containerTag: $tag}')
fi

resp=$(curl -s --max-time 30 -w '\n%{http_code}' \
  -H "Authorization: Bearer $SUPERMEMORY_API_KEY" \
  -H "Content-Type: application/json" \
  -X POST "$BASE/v4/search" -d "$body" 2>/dev/null) || { say "unreachable ($BASE)"; exit 0; }

code=$(printf '%s' "$resp" | tail -1)
json=$(printf '%s' "$resp" | sed '$d')

if [[ "$code" != "200" ]]; then
  say "HTTP $code"
  printf '%s' "$json" | jq -r '"  error: \(.error // "unknown")\(if .details then " — " + .details else "" end)"' 2>/dev/null \
    || say "  (non-JSON response body)"
  say ""
  say "Hints: 401 = bad/revoked key; 402 = credits exhausted; 400 = check MODE/LIMIT values."
  exit 0
fi

say "HTTP 200"
say "  timing: $(printf '%s' "$json" | jq -r '.timing // "?"') ms"
say "  total results: $(printf '%s' "$json" | jq -r '.total // "?"')"
say ""
say "-- Top results --"
printf '%s' "$json" | jq -r '.results[]?
  | "  [\(.similarity // "?" | tostring | .[0:5])] \((.memory // .chunk // "<no content>") | tostring | gsub("\n"; " ") | .[0:100])"' \
  | head -"$LIMIT"

count=$(printf '%s' "$json" | jq -r '.results | length')
if [[ "$count" == "0" ]]; then
  say "  (no results — check: same containerTag as the writes? document status done"
  say "   or dreaming=instant on ingest? threshold not too high on real call-sites?)"
fi

say ""
say "Done. Query only — nothing was written or changed."
exit 0
