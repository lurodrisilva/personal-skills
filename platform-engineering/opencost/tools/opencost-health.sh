#!/usr/bin/env bash
# opencost-health.sh — READ-ONLY OpenCost deployment health check.
#
# Answers "is OpenCost up, wired, and answering?" using only `kubectl get/describe/
# logs` reads plus a single GET against the OpenCost API. It NEVER applies, patches,
# scales, deletes, restarts, or edits anything. Needs read access to the OpenCost
# namespace (pods, deployments, services, endpoints, secrets metadata) and, for the
# API probe, the ability to port-forward.
#
# OpenCost ports: 9003 = API + /metrics · 9090 = UI · 8081 = MCP.
#
# Review this script before running. Installing or reconfiguring OpenCost is always
# a separate, human-approved change delivered through Helm values in Git.
#
# Usage:
#   bash opencost-health.sh
#   OC_NS=cost-system OC_SVC=opencost bash opencost-health.sh
#   PROBE_API=0 bash opencost-health.sh          # skip the port-forward probe
set -euo pipefail

command -v kubectl >/dev/null 2>&1 || { echo "kubectl not found on PATH" >&2; exit 2; }

OC_NS="${OC_NS:-opencost}"
OC_SVC="${OC_SVC:-opencost}"
OC_API_PORT="${OC_API_PORT:-9003}"
PROBE_API="${PROBE_API:-1}"

echo "== OpenCost health  ·  namespace: ${OC_NS}  ·  service: ${OC_SVC}  ·  read-only =="
echo

echo "== Deployment =="
kubectl get deployment -n "${OC_NS}" -o wide 2>/dev/null \
  || echo "  (no deployments readable in ${OC_NS} — is the namespace correct?)"
echo

echo "== Pods =="
kubectl get pods -n "${OC_NS}" -o wide 2>/dev/null || echo "  (no pods readable)"
echo
NOT_RUNNING="$(kubectl get pods -n "${OC_NS}" \
  --field-selector=status.phase!=Running -o name 2>/dev/null || true)"
if [[ -n "${NOT_RUNNING}" ]]; then
  echo "  NOT Running (investigate these first):"
  printf '%s\n' "${NOT_RUNNING}" | sed 's/^/    /'
else
  echo "  All pods in ${OC_NS} are Running."
fi
echo

echo "== Service + endpoints (an empty endpoint list means nothing is backing the service) =="
kubectl get svc -n "${OC_NS}" "${OC_SVC}" -o wide 2>/dev/null || echo "  (service ${OC_SVC} not readable)"
kubectl get endpoints -n "${OC_NS}" "${OC_SVC}" 2>/dev/null || true
echo

echo "== Cloud integration secret (existence only — contents are never printed) =="
if kubectl get secret -n "${OC_NS}" cloud-costs >/dev/null 2>&1; then
  echo "  secret/cloud-costs present — cloud billing integration is configured."
else
  echo "  secret/cloud-costs NOT found — OpenCost is likely using PUBLIC LIST PRICING."
  echo "  Any cost reported is on-demand list price, not your negotiated bill."
fi
echo

echo "== Startup log head (version + early errors) =="
kubectl logs -n "${OC_NS}" "deployment/${OC_SVC}" --tail=-1 2>/dev/null | head -20 \
  || echo "  (logs not readable)"
echo

if [[ "${PROBE_API}" == "1" ]]; then
  echo "== API probe: GET /allocation/compute?window=60m (read-only) =="
  LOCAL_PORT="${LOCAL_PORT:-19003}"
  kubectl port-forward -n "${OC_NS}" "service/${OC_SVC}" "${LOCAL_PORT}:${OC_API_PORT}" \
    >/dev/null 2>&1 &
  PF_PID=$!
  trap 'kill "${PF_PID}" 2>/dev/null || true' EXIT
  # give the forward a moment to establish
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    curl -sf -o /dev/null "http://localhost:${LOCAL_PORT}/allocation/compute?window=60m" && break
    sleep 1
  done
  BODY="$(curl -s "http://localhost:${LOCAL_PORT}/allocation/compute?window=60m" 2>/dev/null || true)"
  if [[ -z "${BODY}" ]]; then
    echo "  NO RESPONSE — check the scrape config and Prometheus target (see troubleshooting)."
  elif printf '%s' "${BODY}" | grep -q '"code":200'; then
    echo "  HTTP 200 from /allocation/compute."
    if printf '%s' "${BODY}" | grep -qE '"data":\s*\[\s*\{\s*\}\s*\]|"data":\s*\[\s*\]'; then
      echo "  WARNING: response is EMPTY — usually a missing 'job_name: opencost' scrape target."
    fi
  else
    echo "  Non-200 response (first 200 chars):"
    printf '%s\n' "${BODY}" | head -c 200 | sed 's/^/    /'
    echo
    echo "  A 500 here usually means a wrong/missing Prometheus target."
  fi
  echo
fi

echo "Goal: confirm OpenCost is Running, backed by endpoints, and answering the API."
echo "Empty data or negative idle almost always means the 'job_name: opencost' scrape"
echo "target is missing from Prometheus. This script only reads; installing or"
echo "reconfiguring OpenCost is a separate, human-approved Helm/Git change."
