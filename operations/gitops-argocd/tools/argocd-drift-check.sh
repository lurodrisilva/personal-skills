#!/usr/bin/env bash
# argocd-drift-check.sh — READ-ONLY drift surface: Applications not Synced or not Healthy.
#
# Walks every Argo CD Application and prints only the ones whose status.sync.status is not
# "Synced" (OutOfSync — live diverged from Git) or whose status.health.status is not
# "Healthy" (Degraded / Progressing / Missing / Suspended). Only runs `kubectl get`
# (reads); it never syncs, reverts, prunes, or patches anything — drift is reconciled
# through Git, not by this script. Needs read access to applications.argoproj.io.
#
# Review this script before running. Starting point, not a certified audit. Reconciling
# drift (a sync, or a revert in Git) is a separate, human-approved action.
#
# Usage: bash argocd-drift-check.sh
set -euo pipefail

command -v kubectl >/dev/null 2>&1 || { echo "kubectl not found on PATH" >&2; exit 2; }

# One line per app: "<ns>/<name> <sync> <health>" via jsonpath range (no jq needed).
JPATH='{range .items[*]}{.metadata.namespace}/{.metadata.name}{"\t"}{.status.sync.status}{"\t"}{.status.health.status}{"\n"}{end}'

echo "== OutOfSync Applications (live != Git — reconcile through Git, not by hand) =="
kubectl get applications.argoproj.io -A -o jsonpath="${JPATH}" 2>/dev/null \
  | awk -F'\t' 'NF>=3 && $2!="Synced" {printf "  %-45s sync=%s health=%s\n", $1, $2, $3}' \
  || echo "  (none / CRD not installed / no access)"
echo

echo "== Unhealthy Applications (Degraded / Progressing / Missing / Suspended) =="
kubectl get applications.argoproj.io -A -o jsonpath="${JPATH}" 2>/dev/null \
  | awk -F'\t' 'NF>=3 && $3!="Healthy" {printf "  %-45s sync=%s health=%s\n", $1, $2, $3}' \
  || echo "  (none / CRD not installed / no access)"
echo

echo "Goal: no rows above (every app Synced + Healthy). An OutOfSync app with selfHeal on"
echo "reverts itself; without it the fix is in Git (gated on prod). Degraded/Progressing →"
echo "read the live resource's status.conditions + events (argocd-drift-health). This script"
echo "only reads — a sync/rollback is a separate, human-approved action."
