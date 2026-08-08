#!/usr/bin/env bash
# opencost-pricing-check.sh — READ-ONLY verification that OpenCost pricing and
# allocation metrics are actually flowing into Prometheus.
#
# If `node_cpu_hourly_cost` has no samples, EVERY cost OpenCost reports is zero or
# wrong — this script catches that before anyone quotes a number. It issues only
# Prometheus instant queries (`/api/v1/query`, a read endpoint) through a temporary
# port-forward. It NEVER writes, deletes series, edits config, or mutates anything.
#
# Needs read access to the Prometheus service. Review before running.
#
# Usage:
#   bash opencost-pricing-check.sh
#   PROM_NS=monitoring PROM_SVC=prometheus-operated PROM_PORT=9090 bash opencost-pricing-check.sh
set -euo pipefail

command -v kubectl >/dev/null 2>&1 || { echo "kubectl not found on PATH" >&2; exit 2; }
command -v curl    >/dev/null 2>&1 || { echo "curl not found on PATH" >&2; exit 2; }

PROM_NS="${PROM_NS:-prometheus-system}"
PROM_SVC="${PROM_SVC:-prometheus-server}"
PROM_PORT="${PROM_PORT:-80}"
LOCAL_PORT="${LOCAL_PORT:-19090}"

echo "== OpenCost pricing check  ·  prometheus: ${PROM_NS}/${PROM_SVC}:${PROM_PORT}  ·  read-only =="
echo

kubectl port-forward -n "${PROM_NS}" "service/${PROM_SVC}" "${LOCAL_PORT}:${PROM_PORT}" \
  >/dev/null 2>&1 &
PF_PID=$!
trap 'kill "${PF_PID}" 2>/dev/null || true' EXIT
for _ in 1 2 3 4 5 6 7 8 9 10; do
  curl -sf -o /dev/null "http://localhost:${LOCAL_PORT}/-/ready" && break
  sleep 1
done

PROM="http://localhost:${LOCAL_PORT}"

# count_samples <promql> -> prints the number of series returned (0 on failure)
count_samples() {
  local q="$1" out
  out="$(curl -sG "${PROM}/api/v1/query" --data-urlencode "query=${q}" 2>/dev/null || true)"
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "${out}" | jq -r '.data.result | length' 2>/dev/null || echo 0
  else
    # crude fallback: count occurrences of "metric"
    printf '%s' "${out}" | grep -o '"metric"' | wc -l | tr -d ' '
  fi
}

check() {
  local metric="$1" note="$2" n
  n="$(count_samples "${metric}")"
  if [[ "${n}" == "0" ]]; then
    echo "  MISSING  ${metric}  — ${note}"
  else
    echo "  ok (${n})  ${metric}"
  fi
}

echo "== Pricing metrics OpenCost EMITS (zero series here => all costs are wrong) =="
check node_cpu_hourly_cost          "no node CPU price; check the opencost scrape target + provider pricing"
check node_ram_hourly_cost          "no node RAM price"
check node_total_hourly_cost        "no total node price"
check pv_hourly_cost                "no persistent-volume price (fine if no PVs)"
check kubecost_load_balancer_cost   "no load-balancer price (fine if no LBs)"
echo

echo "== Allocation metrics OpenCost EMITS =="
check container_cpu_allocation           "no CPU allocation series"
check container_memory_allocation_bytes  "no memory allocation series"
check pod_pvc_allocation                 "no PVC allocation series (fine if no PVCs)"
echo

echo "== Input metrics OpenCost CONSUMES (from kube-state-metrics / node-exporter) =="
check kube_node_status_capacity              "kube-state-metrics may not be scraped"
check kube_pod_container_resource_requests   "kube-state-metrics may not be scraped"
check node_memory_MemTotal_bytes             "node-exporter may not be scraped"
echo

echo "== Is the 'opencost' scrape job UP? =="
UP="$(count_samples 'up{job="opencost"} == 1')"
if [[ "${UP}" == "0" ]]; then
  echo "  DOWN or ABSENT — add the 'job_name: opencost' scrape config."
  echo "  This is the #1 cause of 500s from /allocation and of NEGATIVE IDLE."
else
  echo "  ok — job 'opencost' is up (${UP} target(s))."
fi
echo

echo "== Sample price (sanity: is it a plausible non-zero rate?) =="
curl -sG "${PROM}/api/v1/query" --data-urlencode 'query=node_cpu_hourly_cost' 2>/dev/null \
  | { command -v jq >/dev/null 2>&1 && jq '.data.result[0]' || head -c 400; } \
  || echo "  (query failed)"
echo

echo "Goal: prove the pricing path works before anyone quotes a cost number."
echo "No cloud integration configured => these are PUBLIC ON-DEMAND LIST prices, not"
echo "your negotiated bill. This script only issues Prometheus read queries."
