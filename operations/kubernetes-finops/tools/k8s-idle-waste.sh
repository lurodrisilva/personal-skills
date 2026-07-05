#!/usr/bin/env bash
# k8s-idle-waste.sh — READ-ONLY idle / orphaned-resource inventory.
#
# Surfaces removable Kubernetes waste: unbound PVCs and Released PVs (storage billed
# with no consumer), zero-replica Deployments, completed/failed Jobs and evicted pods
# (clutter, and Job PVC cost). Only runs `kubectl get` (reads); it never deletes or
# mutates anything. This is a CANDIDATE list, not an approval to delete — a Released PVC
# can be a DR / forensic / staging asset.
#
# Review this script before running. Read-only; needs cluster-reader RBAC. Confirm each
# candidate with its owner, then remove via a separate, human-approved change (GitOps PR).
#
# Usage: bash k8s-idle-waste.sh
set -euo pipefail

command -v kubectl >/dev/null 2>&1 || { echo "kubectl not found on PATH" >&2; exit 2; }

echo "== Unbound / pending PVCs (storage requested, nothing using it) =="
kubectl get pvc -A -o custom-columns='NS:.metadata.namespace,PVC:.metadata.name,STATUS:.status.phase,CAP:.status.capacity.storage' \
  --no-headers 2>/dev/null | awk '$3!="Bound"{print}' | head -30 || echo "  (none / query failed)"
echo

echo "== Released / Available PVs (orphaned volumes still billing) =="
kubectl get pv -o custom-columns='PV:.metadata.name,STATUS:.status.phase,CAP:.spec.capacity.storage,CLAIM:.spec.claimRef.name' \
  --no-headers 2>/dev/null | awk '$2=="Released" || $2=="Available"{print}' | head -30 || echo "  (none / query failed)"
echo

echo "== Zero-replica Deployments (scaled to nothing — leftover?) =="
kubectl get deploy -A -o custom-columns='NS:.metadata.namespace,DEPLOY:.metadata.name,DESIRED:.spec.replicas' \
  --no-headers 2>/dev/null | awk '$3=="0"{print}' | head -30 || echo "  (none / query failed)"
echo

echo "== Completed / failed pods (clutter; Jobs with PVCs still cost) =="
kubectl get pods -A -o custom-columns='NS:.metadata.namespace,POD:.metadata.name,PHASE:.status.phase' \
  --no-headers 2>/dev/null | awk '$3=="Succeeded" || $3=="Failed"{print}' | head -30 || echo "  (none / query failed)"
echo

echo "Goal: a defensible candidate list of idle/orphaned resources. Confirm each is truly"
echo "unused with its owner, then delete via a gated, human-approved change. The biggest"
echo "waste bucket is over-provisioned requests (k8s-rightsizing-scan.sh), not orphans."
echo "This script only reads — nothing is deleted here."
