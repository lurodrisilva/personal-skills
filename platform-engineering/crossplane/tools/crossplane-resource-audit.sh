#!/usr/bin/env bash
# crossplane-resource-audit.sh — READ-ONLY managed/composite resource surface.
#
# Surfaces the resources Crossplane reconciles: all Managed Resources via the
# `managed` category (flagging any not Ready/Synced), their deletionPolicy, and the
# provider-kubernetes `Object` MRs. Only runs `kubectl get` (reads); it never applies,
# patches, imports, or deletes anything — flipping managementPolicies or importing a
# resource is done deliberately by a human. Needs read access to the provider MR CRDs.
#
# Review this script before running. Starting point, not a certified audit. A change to
# managementPolicies / deletionPolicy / an import is a separate, human-approved action.
#
# Usage: bash crossplane-resource-audit.sh
set -euo pipefail

command -v kubectl >/dev/null 2>&1 || { echo "kubectl not found on PATH" >&2; exit 2; }

# One row per MR: NAMESPACE/NAME KIND READY SYNCED. The `managed` category matches all
# provider MRs. jsonpath range keeps it jq-free.
JPATH='{range .items[*]}{.metadata.namespace}/{.metadata.name}{"\t"}{.kind}{"\t"}{.status.conditions[?(@.type=="Ready")].status}{"\t"}{.status.conditions[?(@.type=="Synced")].status}{"\n"}{end}'

echo "== Managed Resources NOT Ready or NOT Synced =="
kubectl get managed -A -o jsonpath="${JPATH}" 2>/dev/null \
  | awk -F'\t' 'NF>=4 && ($3!="True" || $4!="True") {printf "  %-45s %-24s ready=%s synced=%s\n", $1, $2, $3, $4}' \
  || echo "  (no managed resources / category unsupported / no access)"
echo "  (no rows above = every MR Ready+Synced)"
echo

echo "== Managed Resources with deletionPolicy=Orphan (survive MR delete) =="
kubectl get managed -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}{"\t"}{.spec.deletionPolicy}{"\n"}{end}' 2>/dev/null \
  | awk -F'\t' '$2=="Orphan" {printf "  %-45s deletionPolicy=%s\n", $1, $2}' \
  || echo "  (none / no access)"
echo

echo "== provider-kubernetes Object MRs =="
kubectl get objects.kubernetes.crossplane.io -A -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,SYNCED:.status.conditions[?(@.type=="Synced")].status,READY:.status.conditions[?(@.type=="Ready")].status' 2>/dev/null \
  || echo "  (provider-kubernetes not installed / no Objects / no access)"
echo

echo "Goal: no NOT-Ready/Synced rows. A stuck MR usually reports the reason in its"
echo "conditions/events (kubectl describe <mr> <name>) — e.g. a missing ProviderConfig,"
echo "bad creds, or a cloud-side error. This script only reads."
