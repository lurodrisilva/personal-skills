#!/usr/bin/env bash
# azure-waste-finder.sh — READ-ONLY Azure waste inventory (Azure Resource Graph).
#
# Surfaces common removable waste across every subscription you can read: VMs that are
# stopped but NOT deallocated (still billing compute), unattached managed disks,
# unattached public IPs, unattached NICs, and aged snapshots. Only runs
# `az graph query` (reads); it never deallocates, resizes, or deletes anything.
# Needs the "Reader" role and the `az` `resource-graph` extension installed locally
# (usually built in; a one-time local CLI install if missing, not a cloud mutation).
#
# Review this script before running. It is a candidate list, not an approval to delete:
# a "0-byte orphan" can be a DR / staging / forensic asset. Confirm ownership, then
# remove via a separate, human-approved change (IaC PR / change ticket).
#
# Usage: AZ_GRAPH_FIRST=500 bash azure-waste-finder.sh
set -euo pipefail

command -v az >/dev/null 2>&1 || { echo "az CLI not found on PATH" >&2; exit 2; }
FIRST="${AZ_GRAPH_FIRST:-500}"

run() {  # run <title> <kusto>
  echo "== $1 =="
  az graph query -q "$2" --first "${FIRST}" -o table 2>/dev/null \
    || echo "  (query unavailable — is the 'resource-graph' extension installed and Reader granted?)"
  echo
}

run "Stopped-but-NOT-deallocated VMs (still billing compute)" '
resources
| where type =~ "microsoft.compute/virtualmachines"
| extend PowerState = tostring(properties.extended.instanceView.powerState.displayStatus)
| where PowerState !in~ ("VM deallocated", "VM running")
| project name, PowerState, location, resourceGroup, subscriptionId'

run "Unattached managed disks (pure waste)" '
resources
| where type =~ "microsoft.compute/disks"
| where tostring(properties.diskState) == "Unattached"
| project name, sku = tostring(sku.name), sizeGB = toint(properties.diskSizeGB), location, resourceGroup, subscriptionId
| order by sizeGB desc'

run "Unattached public IP addresses (billed when Standard/allocated)" '
resources
| where type =~ "microsoft.network/publicipaddresses"
| where isnull(properties.ipConfiguration) and isnull(properties.natGateway)
| project name, sku = tostring(sku.name), allocation = tostring(properties.publicIPAllocationMethod), location, resourceGroup, subscriptionId'

run "Unattached NICs" '
resources
| where type =~ "microsoft.network/networkinterfaces"
| where isnull(properties.virtualMachine) and tostring(properties.privateEndpoint) == ""
| project name, location, resourceGroup, subscriptionId'

run "Snapshots older than 30 days (review retention)" '
resources
| where type =~ "microsoft.compute/snapshots"
| extend created = todatetime(properties.timeCreated)
| where created < ago(30d)
| project name, created, sizeGB = toint(properties.diskSizeGB), location, resourceGroup, subscriptionId
| order by created asc'

echo "Goal: a defensible candidate list of removable waste. Confirm each with its owner,"
echo "then delete/deallocate via a gated, human-approved change — this script only reads."
