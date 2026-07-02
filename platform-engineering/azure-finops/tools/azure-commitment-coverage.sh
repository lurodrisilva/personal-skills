#!/usr/bin/env bash
# azure-commitment-coverage.sh — READ-ONLY rate-optimization signals.
#
# Surfaces the inputs to a commitment / licensing decision: Azure Advisor COST
# recommendations (rightsize, reservations, savings plans), and — via Azure Resource
# Graph — Windows VMs that are NOT using Azure Hybrid Benefit (a licensing gap). Only
# runs `az advisor recommendation list` and `az graph query` (reads); it never
# purchases a reservation/savings plan or changes a license. Needs the "Reader" role
# (Advisor + resources). Reservation/Savings-Plan UTILIZATION lives in Cost Management
# (Reservations + Cost analysis) — check it there before committing more.
#
# Review this script before running. Its output informs a purchase; it does not make
# one. Buy commitments only AFTER usage is right-sized, as a human-approved decision
# (money you can't get back). Target coverage 60-85%, utilization >90%.
#
# Usage: AZ_GRAPH_FIRST=500 bash azure-commitment-coverage.sh
set -euo pipefail

command -v az >/dev/null 2>&1 || { echo "az CLI not found on PATH" >&2; exit 2; }
FIRST="${AZ_GRAPH_FIRST:-500}"

echo "== Azure Advisor — COST recommendations (rightsize / reservations / savings plans) =="
az advisor recommendation list --category Cost \
  --query '[].{Impact:impact, Problem:shortDescription.problem, Resource:impactedValue, Sub:properties.resourceMetadata.resourceId}' \
  -o table 2>/dev/null \
  || echo "  (Advisor unavailable — is Reader granted? Advisor recs can take time to populate.)"
echo

echo "== Windows VMs WITHOUT Azure Hybrid Benefit (licensing savings gap) =="
az graph query --first "${FIRST}" -o table 2>/dev/null -q '
resources
| where type =~ "microsoft.compute/virtualmachines"
| where tostring(properties.storageProfile.osDisk.osType) == "Windows"
| where tostring(properties.licenseType) !has "Windows"
| project name, vmSize = tostring(properties.hardwareProfile.vmSize), licenseType = tostring(properties.licenseType), location, resourceGroup, subscriptionId' \
  || echo "  (resource-graph query unavailable — check the 'resource-graph' extension + Reader.)"
echo

echo "== SQL VMs WITHOUT Azure Hybrid Benefit (AHUB) =="
az graph query --first "${FIRST}" -o table 2>/dev/null -q '
resources
| where type =~ "microsoft.sqlvirtualmachine/sqlvirtualmachines"
| where tostring(properties.sqlServerLicenseType) != "AHUB"
| where tostring(properties.sqlImageSku) !in ("Developer", "Express")
| project name, licenseType = tostring(properties.sqlServerLicenseType), sku = tostring(properties.sqlImageSku), location, resourceGroup, subscriptionId' \
  || echo "  (no SQL VM results / query unavailable)"
echo

echo "Goal: size commitments on ALREADY right-sized usage. Fix usage first"
echo "(azure-waste-finder.sh + Advisor rightsizing), then buy to coverage 60-85% with"
echo "utilization >90%. Confirm reservation/SP utilization in Cost Management. Every"
echo "purchase or AHB change is a separate, human-approved decision — this script only reads."
