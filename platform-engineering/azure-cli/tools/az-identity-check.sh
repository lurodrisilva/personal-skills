#!/usr/bin/env bash
# az-identity-check.sh — READ-ONLY Azure identity / subscription / cloud sanity snapshot.
#
# The "first command in every script" analogue: confirms WHO you are logged in as, WHICH
# subscription + tenant are active, and WHICH cloud (public / sovereign) `az` is pointed at,
# before any real work runs. Only calls `az account show` / `az account list` / `az cloud
# show` (reads) — it never provisions, sets, buys, or deletes anything.
#
# It deliberately prints NO access token. It reads at most the token EXPIRY field
# (`--query expires_on`) so you can see whether your login is still valid — the token
# itself is never emitted.
#
# Needs only a valid `az login` session (any role — even none, with --allow-no-subscriptions).
# Review this script before running. Any change of identity/subscription/cloud is a
# separate, deliberate `az login` / `az account set` / `az cloud set` action.
#
# Usage:
#   bash az-identity-check.sh
#   AZ_SUBSCRIPTION=<sub-id> bash az-identity-check.sh    # inspect a specific subscription
set -euo pipefail

command -v az >/dev/null 2>&1 || { echo "az CLI not found on PATH" >&2; exit 2; }

SUB="${AZ_SUBSCRIPTION:-}"
SUB_ARGS=()
[[ -n "${SUB}" ]] && SUB_ARGS=(--subscription "${SUB}")

if ! az account show "${SUB_ARGS[@]}" >/dev/null 2>&1; then
  echo "Not logged in (or subscription not found). Run 'az login' first." >&2
  exit 2
fi

echo "== Active identity / subscription =="
az account show "${SUB_ARGS[@]}" \
  --query "{name:name, subscriptionId:id, tenantId:tenantId, user:user.name, state:state, isDefault:isDefault}" \
  -o table

echo
echo "== Active cloud (endpoints differ for sovereign clouds) =="
az cloud show --query "{cloud:name, isActive:isActive}" -o table 2>/dev/null \
  || echo "  (az cloud show unavailable)"

echo
echo "== All subscriptions visible to this login =="
az account list --all \
  --query "[].{name:name, subscriptionId:id, tenantId:tenantId, state:state, isDefault:isDefault}" \
  -o table 2>/dev/null \
  || echo "  (no subscriptions — logged in with --allow-no-subscriptions?)"

echo
echo "== Login validity (token expiry only — the token itself is NOT printed) =="
EXP="$(az account get-access-token "${SUB_ARGS[@]}" --query expires_on -o tsv 2>/dev/null || true)"
if [[ -n "${EXP}" ]]; then
  echo "  access token expires_on (POSIX/UTC): ${EXP}"
else
  echo "  (could not read token expiry — managed identity / Cloud Shell may not support it)"
fi
