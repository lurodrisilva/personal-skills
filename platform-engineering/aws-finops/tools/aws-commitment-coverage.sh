#!/usr/bin/env bash
# aws-commitment-coverage.sh — READ-ONLY rate-optimization signals.
#
# Surfaces where rate savings sit: Savings Plans coverage + utilization, Reserved
# Instance coverage + utilization, and consolidated recommendations from Cost
# Optimization Hub. Only runs `aws ce get-*` and `aws cost-optimization-hub list-*`
# (reads); it never purchases, modifies, or removes any commitment. Needs Cost
# Explorer read access + (for the last section) Cost Optimization Hub opted in with
# read access. Cost Explorer API calls are billed ~$0.01 each.
#
# Review this script before running. Coverage/utilization + recommendations are a
# starting point — every Savings Plan / RI purchase is a separate, human-approved
# decision (money you can't get back). Right-size usage BEFORE committing.
#
# Usage:
#   bash aws-commitment-coverage.sh                     # last 30 days
#   AWS_CE_START=2026-06-01 AWS_CE_END=2026-07-01 bash aws-commitment-coverage.sh
set -euo pipefail

command -v aws >/dev/null 2>&1 || { echo "aws CLI not found on PATH" >&2; exit 2; }

# Cost Explorer End date is EXCLUSIVE. Default: last 30 days.
START="${AWS_CE_START:-$(date -u -d '30 days ago' +%Y-%m-%d 2>/dev/null || date -u -v-30d +%Y-%m-%d)}"
END="${AWS_CE_END:-$(date -u +%Y-%m-%d)}"
echo "== Period: ${START} .. ${END} (End exclusive)  ·  read-only  ·  targets: coverage 60–85%, utilization >90% =="
echo

echo "== Savings Plans coverage (% of eligible spend covered) =="
aws ce get-savings-plans-coverage \
  --time-period "Start=${START},End=${END}" \
  --query "SavingsPlansCoverages[].[TimePeriod.Start, Coverage.CoveragePercentage]" \
  --output table 2>/dev/null || echo "  (query failed — is Cost Explorer enabled and readable?)"
echo

echo "== Savings Plans utilization (% of committed \$ actually used) =="
aws ce get-savings-plans-utilization \
  --time-period "Start=${START},End=${END}" \
  --query "SavingsPlansUtilizationsByTime[].[TimePeriod.Start, Utilization.UtilizationPercentage]" \
  --output table 2>/dev/null || echo "  (none / query failed)"
echo

echo "== Reserved Instance utilization (RIs for RDS/ElastiCache/Redshift/OpenSearch) =="
aws ce get-reservation-utilization \
  --time-period "Start=${START},End=${END}" \
  --query "UtilizationsByTime[].[TimePeriod.Start, Total.UtilizationPercentage]" \
  --output table 2>/dev/null || echo "  (none / query failed)"
echo

echo "== Cost Optimization Hub recommendations (rightsizing / idle / SP / RI, your rates) =="
aws cost-optimization-hub list-recommendations \
  --query "items[].[actionType, currentResourceType, estimatedMonthlySavings]" \
  --output table 2>/dev/null | head -40 \
  || echo "  (Cost Optimization Hub not opted in / not readable — enable it first)"
echo

echo "Goal: coverage 60–85% and utilization >90% on a RIGHT-SIZED baseline. Prefer"
echo "Compute Savings Plans over EC2 RIs for compute; use RIs where no SP exists."
echo "Right-size first (aws-waste-finder.sh + Compute Optimizer), THEN commit. Every"
echo "purchase is a separate, human-approved decision — this script only reads."
