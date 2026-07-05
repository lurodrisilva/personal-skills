#!/usr/bin/env bash
# aws-cost-summary.sh — READ-ONLY AWS spend snapshot.
#
# Shows top spend over a period, grouped by service and by linked (member) account,
# using AWS Cost Explorer. Only runs `aws ce get-cost-and-usage` (a read); it never
# provisions, buys, resizes, or removes anything. Needs Cost Explorer read access
# (e.g. the `ce:GetCostAndUsage` action / a billing read-only policy) in the payer
# or a Cost-Explorer-enabled account. Cost Explorer API calls are billed ~$0.01 each.
#
# Review this script before running. A starting point for cost analysis, not a
# certified financial report. Optimization actions (rightsize / buy / remove) are
# always a separate, human-approved change.
#
# Usage:
#   bash aws-cost-summary.sh                     # month-to-date, UnblendedCost
#   AWS_CE_START=2026-06-01 AWS_CE_END=2026-07-01 bash aws-cost-summary.sh
#   AWS_CE_METRIC=AmortizedCost bash aws-cost-summary.sh
set -euo pipefail

command -v aws >/dev/null 2>&1 || { echo "aws CLI not found on PATH" >&2; exit 2; }

# Cost Explorer End date is EXCLUSIVE. Default: first-of-month .. today (month-to-date).
START="${AWS_CE_START:-$(date -u +%Y-%m-01)}"
END="${AWS_CE_END:-$(date -u +%Y-%m-%d)}"
METRIC="${AWS_CE_METRIC:-UnblendedCost}"   # UnblendedCost | AmortizedCost | NetUnblendedCost

if [ "${START}" = "${END}" ]; then
  echo "Period ${START}..${END} is empty (End is exclusive). Set AWS_CE_START/AWS_CE_END." >&2
  exit 2
fi

echo "== Period: ${START} .. ${END} (End exclusive)  ·  Metric: ${METRIC}  ·  read-only =="
echo

echo "== Top spend by service =="
aws ce get-cost-and-usage \
  --time-period "Start=${START},End=${END}" \
  --granularity MONTHLY --metrics "${METRIC}" \
  --group-by Type=DIMENSION,Key=SERVICE \
  --query "ResultsByTime[0].Groups[].[Keys[0], Metrics.${METRIC}.Amount]" \
  --output table 2>/dev/null \
  || echo "  (Cost Explorer query failed — is CE enabled and are ce:GetCostAndUsage reads allowed?)"
echo

echo "== Top spend by linked (member) account =="
aws ce get-cost-and-usage \
  --time-period "Start=${START},End=${END}" \
  --granularity MONTHLY --metrics "${METRIC}" \
  --group-by Type=DIMENSION,Key=LINKED_ACCOUNT \
  --query "ResultsByTime[0].Groups[].[Keys[0], Metrics.${METRIC}.Amount]" \
  --output table 2>/dev/null \
  || echo "  (no linked-account breakdown — run from the payer/management account)"
echo

echo "Goal: know your biggest cost drivers before optimizing. Drill the top services /"
echo "accounts next (aws-waste-finder.sh for removable waste; aws-commitment-coverage.sh"
echo "for rate savings). Every buy/resize/remove that follows is a separate, human-"
echo "approved change — this script only reads."
