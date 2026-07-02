#!/usr/bin/env bash
# disruption-blockers.sh — READ-ONLY: why won't Karpenter deprovision a node?
#
# Surfaces the common blockers of voluntary (graceful) disruption: pods and nodes
# carrying karpenter.sh/do-not-disrupt, PodDisruptionBudgets that currently allow
# zero disruptions, and nodes already tainted karpenter.sh/disrupted. Only runs
# `kubectl get`; it never mutates the cluster. Needs read access to pods, nodes, pdb.
#
# Review this script before running. Starting point, not a certified audit.
# Usage: bash disruption-blockers.sh
set -euo pipefail

command -v kubectl >/dev/null 2>&1 || { echo "kubectl not found on PATH" >&2; exit 2; }

echo "== Pods with karpenter.sh/do-not-disrupt (block consolidation/drift of their node) =="
kubectl get pods -A --no-headers \
  -o custom-columns='NS:.metadata.namespace,POD:.metadata.name,DND:.metadata.annotations.karpenter\.sh/do-not-disrupt' \
  2>/dev/null | awk '$3!="<none>" && $3!=""' || true
echo

echo "== Nodes with karpenter.sh/do-not-disrupt (blocked from voluntary disruption) =="
kubectl get nodes --no-headers \
  -o custom-columns='NODE:.metadata.name,DND:.metadata.annotations.karpenter\.sh/do-not-disrupt' \
  2>/dev/null | awk '$2!="<none>" && $2!=""' || true
echo

echo "== PodDisruptionBudgets allowing ZERO disruptions right now (block eviction) =="
kubectl get pdb -A --no-headers \
  -o custom-columns='NS:.metadata.namespace,PDB:.metadata.name,ALLOWED:.status.disruptionsAllowed' \
  2>/dev/null | awk '$3=="0"' || true
echo

echo "== Nodes already tainted karpenter.sh/disrupted (disruption in progress) =="
kubectl get nodes --no-headers \
  -o custom-columns='NODE:.metadata.name,TAINTS:.spec.taints[*].key' \
  2>/dev/null | grep 'karpenter.sh/disrupted' || echo "  (none)"
echo
echo "Goal: if a node won't consolidate/deprovision, one of the above usually holds it."
echo "Remove the do-not-disrupt annotation, relax the PDB, or set terminationGracePeriod"
echo "on the NodePool as an escape valve. Also confirm the node is karpenter.sh/initialized"
echo "and that no 'nodes: 0' disruption budget window is currently active."
