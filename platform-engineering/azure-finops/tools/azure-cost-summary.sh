#!/usr/bin/env bash
# azure-cost-summary.sh — READ-ONLY Azure spend snapshot.
#
# Shows top spend for a scope over a timeframe, grouped by service and by resource
# group, using Microsoft Cost Management queries. Only runs `az costmanagement query`
# / `az consumption usage list` (reads); it never provisions, buys, or deletes anything.
# Needs the "Cost Management Reader" (or Reader) role on the scope, and the `az`
# `costmanagement` extension installed locally (a one-time local CLI install, not a
# cloud mutation).
#
# Review this script before running. A starting point for cost analysis, not a
# certified financial report. Optimization actions (rightsize / buy / delete) are
# always a separate, human-approved change.
#
# Usage:
#   AZ_SUBSCRIPTION=<sub-id> AZ_TIMEFRAME=MonthToDate bash azure-cost-summary.sh
#   AZ_SCOPE="/providers/Microsoft.Management/managementGroups/<mg>" bash azure-cost-summary.sh
set -euo pipefail

command -v az >/dev/null 2>&1 || { echo "az CLI not found on PATH" >&2; exit 2; }

SUB="${AZ_SUBSCRIPTION:-$(az account show --query id -o tsv 2>/dev/null || true)}"
SCOPE="${AZ_SCOPE:-/subscriptions/${SUB}}"
TIMEFRAME="${AZ_TIMEFRAME:-MonthToDate}"   # MonthToDate | TheLastMonth | BillingMonthToDate

if [[ -z "${SUB}" && "${SCOPE}" == /subscriptions/* ]]; then
  echo "No subscription resolved. Set AZ_SUBSCRIPTION or run 'az login'." >&2
  exit 2
fi

echo "== Scope: ${SCOPE}  ·  Timeframe: ${TIMEFRAME} =="
echo "   (EffectiveCost/amortized view; read-only)"
echo

echo "== Top spend by service =="
az costmanagement query \
  --type ActualCost --timeframe "${TIMEFRAME}" --scope "${SCOPE}" \
  --dataset-aggregation '{"totalCost":{"name":"Cost","function":"Sum"}}' \
  --dataset-grouping name="ServiceName" type="Dimension" \
  -o table 2>/dev/null \
  || echo "  (costmanagement query unavailable — is the 'costmanagement' extension installed and the scope readable?)"
echo

echo "== Top spend by resource group =="
az costmanagement query \
  --type ActualCost --timeframe "${TIMEFRAME}" --scope "${SCOPE}" \
  --dataset-aggregation '{"totalCost":{"name":"Cost","function":"Sum"}}' \
  --dataset-grouping name="ResourceGroupName" type="Dimension" \
  -o table 2>/dev/null \
  || echo "  (no resource-group breakdown returned)"
echo

echo "Goal: know your biggest cost drivers before optimizing. Drill the top services /"
echo "resource groups next (azure-waste-finder.sh for removable waste; Advisor +"
echo "azure-commitment-coverage.sh for rate savings). Every buy/resize/delete that"
echo "follows is a separate, human-approved change — this script only reads."
