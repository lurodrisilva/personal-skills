#!/usr/bin/env bash
# kapso-workflow-inventory.sh — READ-ONLY inventory of Kapso workflows and
# functions.
#
# Answers "which workflows and serverless functions exist, in what status,
# and how are recent executions doing?" using only GET calls: /workflows,
# /workflows/{id}/executions, and /functions. It NEVER creates, updates,
# deletes, starts, or resumes anything, and never prints the API key.
#
# Usage:
#   KAPSO_API_KEY=... bash kapso-workflow-inventory.sh
set -euo pipefail

BASE="${KAPSO_BASE_URL:-https://api.kapso.ai/platform/v1}"

say() { printf '%s\n' "$*"; }

say "== Kapso workflow inventory (read-only) =="
say "Base URL: $BASE"
say ""

if [[ -z "${KAPSO_API_KEY:-}" ]]; then
  say "[WARN] KAPSO_API_KEY is not set — cannot inventory workflows."
  say "       Create a project API key in the Kapso dashboard under"
  say "       Integrations -> API keys. Nothing was probed."
  exit 0
fi

auth=(-H "X-API-Key: $KAPSO_API_KEY")

if ! command -v jq >/dev/null 2>&1; then
  say "[WARN] jq is required for this inventory. Install jq and re-run."
  exit 0
fi

say "-- Workflows (newest first) --"
workflows=$(curl -s --max-time 10 "${auth[@]}" "$BASE/workflows" 2>/dev/null || true)
if printf '%s' "$workflows" | jq -e '.data' >/dev/null 2>&1; then
  say "  workflows: $(printf '%s' "$workflows" | jq '.data | length') (first page)"
  printf '%s' "$workflows" | jq -r '.data[] |
    "    \(.name // .slug // .id): status=\(.status // "?")"' 2>/dev/null | head -15
else
  say "  (workflow list unavailable)"
  workflows=""
fi

say ""
say "-- Recent executions (up to 3 workflows) --"
if [[ -n "$workflows" ]]; then
  printf '%s' "$workflows" | jq -r '.data[].id' 2>/dev/null | head -3 | while read -r wf_id; do
    [[ -z "$wf_id" ]] && continue
    execs=$(curl -s --max-time 10 "${auth[@]}" "$BASE/workflows/$wf_id/executions" 2>/dev/null || true)
    if printf '%s' "$execs" | jq -e '.data' >/dev/null 2>&1; then
      say "  workflow $wf_id:"
      printf '%s' "$execs" | jq -r '.data[] |
        "    exec \(.id // "?"): \(.status // "?")"' 2>/dev/null | head -5
    else
      say "  workflow $wf_id: (executions unavailable)"
    fi
  done
fi

say ""
say "-- Functions --"
functions=$(curl -s --max-time 10 "${auth[@]}" "$BASE/functions" 2>/dev/null || true)
if printf '%s' "$functions" | jq -e '.data' >/dev/null 2>&1; then
  say "  functions: $(printf '%s' "$functions" | jq '.data | length') (first page)"
  printf '%s' "$functions" | jq -r '.data[] |
    "    \(.name // .slug // .id): status=\(.status // .deployment_status // "?")"' 2>/dev/null | head -10
else
  say "  (function list unavailable)"
fi

say ""
say "Done. Inventory only — creating, editing, deploying, starting, or resuming workflows/functions are separate, human-approved actions."
exit 0
