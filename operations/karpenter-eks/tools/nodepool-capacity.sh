#!/usr/bin/env bash
# nodepool-capacity.sh — READ-ONLY NodePool limits vs usage + node breakdown.
#
# Shows each NodePool's limits against its provisioned resources, then counts the
# Karpenter-managed nodes by capacity-type (spot/on-demand/reserved) and instance
# type. Only runs `kubectl get`; it never mutates the cluster. Needs read access to
# nodepools and nodes.
#
# Review this script before running. Starting point, not a certified audit.
# Usage: bash nodepool-capacity.sh
set -euo pipefail

command -v kubectl >/dev/null 2>&1 || { echo "kubectl not found on PATH" >&2; exit 2; }

echo "== NodePools: limits vs provisioned resources =="
kubectl get nodepools \
  -o custom-columns='NAME:.metadata.name,LIM_CPU:.spec.limits.cpu,LIM_MEM:.spec.limits.memory,USE_CPU:.status.resources.cpu,USE_MEM:.status.resources.memory,NODES:.status.resources.nodes' \
  2>/dev/null || echo "  (none)"
echo

echo "== Karpenter-managed nodes by capacity-type =="
kubectl get nodes --no-headers \
  -o custom-columns='CAP:.metadata.labels.karpenter\.sh/capacity-type' \
  2>/dev/null | awk 'NF && $1!="<none>"' | sort | uniq -c | sort -rn || echo "  (none)"
echo

echo "== Karpenter-managed nodes by instance type =="
kubectl get nodes --no-headers \
  -o custom-columns='POOL:.metadata.labels.karpenter\.sh/nodepool,TYPE:.metadata.labels.node\.kubernetes\.io/instance-type' \
  2>/dev/null | awk 'NF>=2 && $1!="<none>"' | sort | uniq -c | sort -rn || echo "  (none)"
echo
echo "Goal: no NodePool pinned at its limits (USE ≈ LIM means it has stopped provisioning"
echo "and pods may be Pending — raise limits or add a NodePool). A single capacity-type or"
echo "one dominant instance type means low diversity: widen requirements + set minValues"
echo "for better spot resilience and cheaper consolidation."
