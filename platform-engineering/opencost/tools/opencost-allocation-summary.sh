#!/usr/bin/env bash
# opencost-allocation-summary.sh — READ-ONLY OpenCost allocation query.
#
# Issues a single `GET /allocation` against the OpenCost API through a temporary
# port-forward and prints a per-key cost summary. It is a READ: the allocation API
# does not mutate cluster or cost state. This script NEVER applies, edits, scales,
# or deletes anything.
#
# Every number it prints is qualified by FOUR things that must travel with it:
#   window · aggregate · resolution · idle treatment (includeIdle / shareIdle)
# A cost figure quoted without them is not interpretable. The script prints them.
#
# NOTE ON PRICING SOURCE: with no cloud integration configured, OpenCost reports
# PUBLIC ON-DEMAND LIST PRICING — not your negotiated bill. Run
# opencost-pricing-check.sh / opencost-health.sh to see which source is in play.
#
# Allocation is max(request, usage) per resource — a workload is charged for what it
# RESERVED or what it USED, whichever is greater.
#
# Usage:
#   bash opencost-allocation-summary.sh
#   WINDOW=7d AGGREGATE=namespace bash opencost-allocation-summary.sh
#   WINDOW=24h AGGREGATE=label:team RESOLUTION=1m INCLUDE_IDLE=true bash opencost-allocation-summary.sh
set -euo pipefail

command -v kubectl >/dev/null 2>&1 || { echo "kubectl not found on PATH" >&2; exit 2; }
command -v curl    >/dev/null 2>&1 || { echo "curl not found on PATH" >&2; exit 2; }

OC_NS="${OC_NS:-opencost}"
OC_SVC="${OC_SVC:-opencost}"
OC_API_PORT="${OC_API_PORT:-9003}"
LOCAL_PORT="${LOCAL_PORT:-19003}"

WINDOW="${WINDOW:-7d}"            # today|week|month|yesterday|lastweek|lastmonth | 30m|12h|7d | RFC3339 pair | unix pair
AGGREGATE="${AGGREGATE:-namespace}" # cluster|node|namespace|controllerKind|controller|service|pod|container|label:NAME|annotation:NAME
RESOLUTION="${RESOLUTION:-1m}"    # 1m | 30m  — coarsen for long windows
INCLUDE_IDLE="${INCLUDE_IDLE:-true}"
SHARE_IDLE="${SHARE_IDLE:-false}" # true redistributes idle ONTO workloads — hides bin-packing problems

echo "== OpenCost allocation summary  ·  read-only =="
echo "   window=${WINDOW}  aggregate=${AGGREGATE}  resolution=${RESOLUTION}"
echo "   includeIdle=${INCLUDE_IDLE}  shareIdle=${SHARE_IDLE}"
echo "   (allocation = max(request, usage) per resource)"
echo

kubectl port-forward -n "${OC_NS}" "service/${OC_SVC}" "${LOCAL_PORT}:${OC_API_PORT}" \
  >/dev/null 2>&1 &
PF_PID=$!
trap 'kill "${PF_PID}" 2>/dev/null || true' EXIT
for _ in 1 2 3 4 5 6 7 8 9 10; do
  curl -sf -o /dev/null "http://localhost:${LOCAL_PORT}/allocation?window=60m" && break
  sleep 1
done

BODY="$(curl -sG "http://localhost:${LOCAL_PORT}/allocation" \
  -d "window=${WINDOW}" \
  -d "aggregate=${AGGREGATE}" \
  -d "resolution=${RESOLUTION}" \
  -d "includeIdle=${INCLUDE_IDLE}" \
  -d "shareIdle=${SHARE_IDLE}" 2>/dev/null || true)"

if [[ -z "${BODY}" ]]; then
  echo "  NO RESPONSE from /allocation — run opencost-health.sh first." >&2
  exit 1
fi

if ! printf '%s' "${BODY}" | grep -q '"code":200'; then
  echo "  Non-200 from /allocation (first 300 chars):"
  printf '%s\n' "${BODY}" | head -c 300 | sed 's/^/    /'
  echo
  echo "  A 500 usually means a wrong/missing Prometheus target for OpenCost."
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "  jq not found — printing raw JSON (install jq for the summary table)."
  printf '%s\n' "${BODY}" | head -c 4000
  exit 0
fi

echo "== Cost by ${AGGREGATE} (descending totalCost) =="
printf '%s' "${BODY}" | jq -r '
  [ .data[]? | to_entries[] ]
  | group_by(.key)
  | map({ key: .[0].key,
          total: (map(.value.totalCost // 0) | add),
          cpu:   (map(.value.cpuCost   // 0) | add),
          ram:   (map(.value.ramCost   // 0) | add),
          gpu:   (map(.value.gpuCost   // 0) | add),
          pv:    (map(.value.pvCost    // 0) | add) })
  | sort_by(-.total)
  | (["KEY","TOTAL","CPU","RAM","GPU","PV"] | @tsv),
    (.[] | [ .key,
             (.total|.*10000|round/10000|tostring),
             (.cpu  |.*10000|round/10000|tostring),
             (.ram  |.*10000|round/10000|tostring),
             (.gpu  |.*10000|round/10000|tostring),
             (.pv   |.*10000|round/10000|tostring) ] | @tsv)
' 2>/dev/null | column -t -s "$(printf '\t')" || {
  echo "  (could not summarize — raw JSON head:)"
  printf '%s\n' "${BODY}" | head -c 2000
}
echo

echo "== Idle =="
IDLE="$(printf '%s' "${BODY}" | jq -r '
  [ .data[]? | to_entries[] | select(.key | test("__idle__"; "i")) | .value.totalCost // 0 ] | add // 0
' 2>/dev/null || echo 0)"
echo "  __idle__ totalCost: ${IDLE}"
case "${IDLE}" in
  -*) echo "  NEGATIVE IDLE — the 'job_name: opencost' scrape target is almost certainly missing." ;;
  0|0.0|null) echo "  (no idle row — set INCLUDE_IDLE=true and SHARE_IDLE=false to see it)" ;;
  *)  echo "  Idle is a CLUSTER bin-packing metric, not a tenant's bill. Report it separately." ;;
esac
echo

echo "Goal: a per-${AGGREGATE} cost view whose window, aggregation, resolution, and"
echo "idle treatment are all stated. What to DO about these numbers (right-sizing,"
echo "quotas, chargeback) belongs to ../../operations/kubernetes-finops/ — and every"
echo "resulting change is a separate, human-approved PR. This script only reads."
