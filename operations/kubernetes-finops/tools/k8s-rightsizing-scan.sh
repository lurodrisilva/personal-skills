#!/usr/bin/env bash
# k8s-rightsizing-scan.sh — READ-ONLY right-sizing signals.
#
# Surfaces the request-vs-usage gap that drives most Kubernetes waste: pods' actual
# CPU/memory usage (kubectl top) next to their declared requests, pods with NO requests
# (BestEffort — unallocatable + evicted first), and the cluster's QoS-class breakdown.
# Only runs `kubectl get` / `kubectl top` (reads); it never mutates the cluster.
# `kubectl top` needs metrics-server; p95/p99 right-sizing needs Prometheus history
# (VPA / Goldilocks / KRR) — this is a first look, not a certified recommendation.
#
# Review this script before running. Read-only; needs cluster-reader RBAC + metrics-server.
# Usage: bash k8s-rightsizing-scan.sh
set -euo pipefail

command -v kubectl >/dev/null 2>&1 || { echo "kubectl not found on PATH" >&2; exit 2; }

echo "== Actual pod usage (compare to requests below; usage << request = over-provisioned) =="
kubectl top pods -A 2>/dev/null | head -40 || echo "  (kubectl top failed — is metrics-server installed?)"
echo

echo "== Declared CPU/memory requests per pod =="
kubectl get pods -A -o custom-columns=\
'NS:.metadata.namespace,POD:.metadata.name,CPUreq:.spec.containers[*].resources.requests.cpu,MEMreq:.spec.containers[*].resources.requests.memory' \
  2>/dev/null | head -40 || echo "  (query failed)"
echo

echo "== Pods with NO requests (BestEffort — unallocatable, evicted first) =="
kubectl get pods -A \
  -o custom-columns='NS:.metadata.namespace,POD:.metadata.name,QOS:.status.qosClass' \
  2>/dev/null | awk 'NR==1{print; next} $3=="BestEffort"{print}' | head -30 \
  || echo "  (none / query failed)"
echo

echo "== QoS class breakdown (Guaranteed=req==lim, Burstable=req<lim, BestEffort=none) =="
kubectl get pods -A -o custom-columns='QOS:.status.qosClass' --no-headers 2>/dev/null \
  | sort | uniq -c | sort -rn || echo "  (query failed)"
echo

echo "Goal: requests sized to ~p95/p99 of real usage (usage close to request), requests <"
echo "limits for burst, and BestEffort only for transient work. Confirm with VPA"
echo "recommendation-mode / Goldilocks / KRR before applying. Every new request value is a"
echo "separate, gradually-rolled, human-approved change — this script only reads."
