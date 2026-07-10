#!/usr/bin/env bash
# az-resource-inventory.sh — READ-ONLY estate inventory + a `--query` / JMESPath demo.
#
# Lists subscriptions, resource groups, and resources for a scope, shaping the output with
# JMESPath multiselect hashes so it doubles as a worked `--query` example. Only calls
# `az account list` / `az group list` / `az resource list` (reads) — it never creates,
# updates, moves, or deletes anything.
#
# Needs the built-in "Reader" role on the scope. Review this script before running. It is a
# starting point for inventory, not a certified asset register; any change to a resource is
# always a separate, human-approved action.
#
# Usage:
#   bash az-resource-inventory.sh
#   AZ_SUBSCRIPTION=<sub-id> bash az-resource-inventory.sh
#   AZ_SUBSCRIPTION=<sub-id> AZ_GROUP=<rg-name> bash az-resource-inventory.sh   # scope to one RG
set -euo pipefail

command -v az >/dev/null 2>&1 || { echo "az CLI not found on PATH" >&2; exit 2; }

SUB="${AZ_SUBSCRIPTION:-$(az account show --query id -o tsv 2>/dev/null || true)}"
if [[ -z "${SUB}" ]]; then
  echo "No subscription resolved. Set AZ_SUBSCRIPTION or run 'az login'." >&2
  exit 2
fi
GROUP="${AZ_GROUP:-}"

echo "== Subscriptions visible to this login =="
az account list --all --query "[].{name:name, subscriptionId:id, state:state}" -o table 2>/dev/null \
  || echo "  (none)"

echo
echo "== Resource groups in subscription ${SUB} =="
az group list --subscription "${SUB}" \
  --query "sort_by([].{name:name, location:location}, &name)" -o table 2>/dev/null \
  || echo "  (none or not readable)"

echo
if [[ -n "${GROUP}" ]]; then
  echo "== Resources in resource group ${GROUP} =="
  az resource list --subscription "${SUB}" --resource-group "${GROUP}" \
    --query "sort_by([].{name:name, type:type, location:location}, &type)" -o table 2>/dev/null \
    || echo "  (none or not readable)"
else
  echo "== Resource count by type across subscription ${SUB} =="
  # JMESPath demo: flatten, project a type field, then a table of name/type/rg/location.
  az resource list --subscription "${SUB}" \
    --query "sort_by([].{name:name, type:type, resourceGroup:resourceGroup, location:location}, &type)" \
    -o table 2>/dev/null \
    || echo "  (none or not readable)"
fi
