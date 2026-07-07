#!/usr/bin/env bash
# argocd-app-health.sh — READ-ONLY Argo CD Application sync + health inventory.
#
# Lists every Argo CD Application across all namespaces with its project, sync status,
# health status, and synced revision, then counts apps by sync+health so you can see the
# fleet at a glance. Only runs `kubectl get` (reads); it never syncs, rolls back, prunes,
# creates, or deletes anything. Needs read access to applications.argoproj.io cluster-wide
# (a cluster-reader / argocd read-only RBAC role).
#
# Review this script before running. Starting point, not a certified audit. Triggering a
# sync or rollback is a separate, human-approved action.
#
# Usage: bash argocd-app-health.sh
# Alt (argocd CLI, read-only, if installed + logged in): argocd app list -o wide
set -euo pipefail

command -v kubectl >/dev/null 2>&1 || { echo "kubectl not found on PATH" >&2; exit 2; }
# The `argocd` CLI is optional — this script uses only kubectl reads.

echo "== Argo CD Applications (all namespaces): sync + health + revision =="
kubectl get applications.argoproj.io -A \
  -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,PROJECT:.spec.project,SYNC:.status.sync.status,HEALTH:.status.health.status,REVISION:.status.sync.revision' \
  2>/dev/null || echo "  (no Applications / CRD not installed / no access)"
echo

echo "== Count by SYNC × HEALTH (anything not Synced/Healthy is a triage target) =="
kubectl get applications.argoproj.io -A --no-headers \
  -o custom-columns='SYNC:.status.sync.status,HEALTH:.status.health.status' \
  2>/dev/null | awk 'NF' | sort | uniq -c | sort -rn || echo "  (none)"
echo

echo "Goal: every Application Synced + Healthy. OutOfSync means live diverged from Git"
echo "(argocd-drift-check.sh details each); Degraded/Progressing/Missing is a health issue"
echo "→ argocd-drift-health (Pod-level crash triage → kubernetes-operations). This script"
echo "only reads — a sync/rollback is a separate, human-approved action."
