#!/usr/bin/env bash
# crossplane-activation-audit.sh — READ-ONLY safe-start / MR-activation surface.
#
# Reports the safe-start posture (alpha): ManagedResourceDefinitions and their state
# (Inactive vs Active — activation is one-way and creates the CRD), the
# ManagedResourceActivationPolicies with their requested spec.activate patterns vs the
# MRDs they actually activated, and each ProviderRevision's declared capabilities (does
# the provider even support safe-start?). Only runs `kubectl get` (reads); it never
# activates an MRD, applies an MRAP, or patches state. Needs read access to the
# apiextensions.crossplane.io v1alpha1 MRD/MRAP resources.
#
# Review this script before running. Starting point, not a certified audit. Activating a
# resource (MRAP apply or an MRD state patch) is a separate, human-approved action —
# and it cannot be undone by flipping state back.
#
# Usage: bash crossplane-activation-audit.sh
set -euo pipefail

command -v kubectl >/dev/null 2>&1 || { echo "kubectl not found on PATH" >&2; exit 2; }

echo "== ManagedResourceDefinitions by state (Inactive = CRD not yet created) =="
kubectl get managedresourcedefinitions -o custom-columns='NAME:.metadata.name,STATE:.spec.state,ESTABLISHED:.status.conditions[?(@.type=="Established")].status' 2>/dev/null \
  || echo "  (no MRDs / CRD not installed — safe-start may be off / no access)"
echo

echo "== Inactive MRDs (present but their CRD is not created; activate via an MRAP) =="
kubectl get managedresourcedefinitions -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.state}{"\n"}{end}' 2>/dev/null \
  | awk -F'\t' '$2!="Active" {printf "  %-55s state=%s\n", $1, $2}' \
  || echo "  (none / no access)"
echo "  (no rows above = every MRD Active)"
echo

echo "== ManagedResourceActivationPolicies: requested spec.activate =="
kubectl get managedresourceactivationpolicies -o jsonpath='{range .items[*]}{.metadata.name}{": "}{.spec.activate}{"\n"}{end}' 2>/dev/null \
  || echo "  (no MRAPs / CRD not installed / no access)"
echo

echo "== MRAPs: status.activated (what each actually turned on) =="
kubectl get managedresourceactivationpolicies -o jsonpath='{range .items[*]}{.metadata.name}{": "}{.status.activated}{"\n"}{end}' 2>/dev/null \
  || echo "  (none / no access)"
echo

echo "== ProviderRevision capabilities (safe-start = opt-in Inactive default) =="
kubectl get providerrevisions.pkg.crossplane.io -o jsonpath='{range .items[*]}{.metadata.name}{": "}{.status.capabilities}{"\n"}{end}' 2>/dev/null \
  || echo "  (none / no access)"
echo

echo "Goal: only the MRDs you use are Active; MRAP spec.activate uses exact plural names"
echo "or a prefix-only wildcard (*.grp), never mid-string. A provider WITHOUT the"
echo "safe-start capability activates everything by default. This script only reads —"
echo "activation is a separate, human-approved (and one-way) action."
