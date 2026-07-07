#!/usr/bin/env bash
# argocd-sync-status.sh — READ-ONLY per-Application sync policy + last-operation snapshot.
#
# For every Argo CD Application, shows whether automated sync is configured and its prune /
# selfHeal flags, the sync-wave annotation (if any), and the phase of the last sync
# operation. Only runs `kubectl get` (reads); it never sets a sync policy, syncs, prunes,
# or mutates anything. Needs read access to applications.argoproj.io.
#
# Review this script before running. Starting point, not a certified audit. Turning on
# automated/prune/selfHeal, or triggering a sync, is a separate, human-approved action.
#
# Usage: bash argocd-sync-status.sh
set -euo pipefail

command -v kubectl >/dev/null 2>&1 || { echo "kubectl not found on PATH" >&2; exit 2; }

echo "== Applications: sync policy (automated/prune/selfHeal) + last operation phase =="
kubectl get applications.argoproj.io -A \
  -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,AUTOMATED:.spec.syncPolicy.automated,PRUNE:.spec.syncPolicy.automated.prune,SELFHEAL:.spec.syncPolicy.automated.selfHeal,WAVE:.metadata.annotations.argocd\.argoproj\.io/sync-wave,LAST_PHASE:.status.operationState.phase' \
  2>/dev/null || echo "  (no Applications / CRD not installed / no access)"
echo

echo "== Applications WITHOUT automated sync (manual sync — expected for gated prod) =="
JPATH='{range .items[*]}{.metadata.namespace}/{.metadata.name}{"\t"}{.spec.syncPolicy.automated}{"\n"}{end}'
kubectl get applications.argoproj.io -A -o jsonpath="${JPATH}" 2>/dev/null \
  | awk -F'\t' 'NF>=1 && ($2=="" || $2=="<none>") {printf "  %s\n", $1}' \
  || echo "  (none / all automated)"
echo

echo "Goal: non-prod apps run automated with prune + selfHeal (hands-free convergence +"
echo "drift revert); PROD apps are intentionally gated — automated OFF (manual sync) or an"
echo "AppProject syncWindow. AUTOMATED=<none> on a prod app is correct; on a dev app it may"
echo "mean drift won't self-heal. This script only reads — a sync is a human-approved action."
