#!/usr/bin/env bash
# k8s-cost-allocation.sh — READ-ONLY Kubernetes cost-allocation signals.
#
# Surfaces the inputs to a container-cost allocation: node utilization (the idle
# signal), per-namespace resource usage, and workloads missing cost labels (which are
# unallocatable). Only runs `kubectl get` / `kubectl top` (reads); it never mutates the
# cluster. `kubectl top` needs metrics-server; certified per-namespace cost needs
# OpenCost/Kubecost on Prometheus — this is a starting point, not that report.
#
# Review this script before running. Read-only; needs cluster-reader RBAC + metrics-server.
# Set COST_LABEL to the label key your org allocates on (default: team).
#
# Usage: COST_LABEL=team bash k8s-cost-allocation.sh
set -euo pipefail

command -v kubectl >/dev/null 2>&1 || { echo "kubectl not found on PATH" >&2; exit 2; }
COST_LABEL="${COST_LABEL:-team}"

echo "== Node utilization (idle signal: low % = paid-for empty capacity) =="
kubectl top nodes 2>/dev/null || echo "  (kubectl top nodes failed — is metrics-server installed?)"
echo

echo "== Per-namespace usage total (allocated signal) =="
for ns in $(kubectl get ns -o custom-columns=NAME:.metadata.name --no-headers 2>/dev/null); do
  total=$(kubectl top pods -n "$ns" --sum 2>/dev/null | awk '/^[[:space:]]*[0-9]/{last=$0} END{print last}')
  [ -n "${total:-}" ] && printf "  %-32s %s\n" "$ns" "$total"
done
echo "  (each line is that namespace's summed CPU/memory usage; empty = no metrics)"
echo

echo "== Workloads missing the cost label '$COST_LABEL' (unallocatable) =="
kubectl get pods -A \
  -o custom-columns="NS:.metadata.namespace,POD:.metadata.name,LABEL:.metadata.labels.$COST_LABEL" \
  2>/dev/null | awk 'NR==1{print; next} $3=="<none>"{print}' | head -40 || echo "  (none / query failed)"
echo "  (pods showing <none> are not attributable — enforce the label at admission)"
echo

echo "Goal: high node utilization + every namespace/pod carrying a cost label. Feed"
echo "OpenCost/Kubecost for the allocated/idle/shared split; right-size the over-requesters"
echo "(k8s-rightsizing-scan.sh). This script only reads — no allocation change is applied here."
