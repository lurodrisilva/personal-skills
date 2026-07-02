#!/usr/bin/env bash
# karpenter-health.sh — READ-ONLY Karpenter-on-EKS health snapshot.
#
# Shows the Karpenter controller Deployment/pods, whether the CRDs are installed,
# and the Ready conditions of NodePools, EC2NodeClasses, and NodeClaims. Only runs
# `kubectl get`; it never mutates the cluster. Needs read access to deployments,
# pods, crds, nodepools, ec2nodeclasses, nodeclaims.
#
# Review this script before running. Starting point, not a certified audit.
# Usage: KARPENTER_NAMESPACE=kube-system bash karpenter-health.sh
set -euo pipefail

command -v kubectl >/dev/null 2>&1 || { echo "kubectl not found on PATH" >&2; exit 2; }
NS="${KARPENTER_NAMESPACE:-kube-system}"

echo "== Karpenter controller (namespace: $NS) =="
kubectl get deploy -n "$NS" -l app.kubernetes.io/name=karpenter \
  -o custom-columns='NAME:.metadata.name,READY:.status.readyReplicas,DESIRED:.spec.replicas' \
  2>/dev/null || echo "  (no karpenter deployment found in $NS)"
echo

echo "== Required CRDs =="
for crd in nodepools.karpenter.sh ec2nodeclasses.karpenter.k8s.aws nodeclaims.karpenter.sh; do
  if kubectl get crd "$crd" >/dev/null 2>&1; then
    printf "  present: %s\n" "$crd"
  else
    printf "  MISSING: %s\n" "$crd"
  fi
done
echo

echo "== NodePools (Ready condition) =="
kubectl get nodepools \
  -o custom-columns='NAME:.metadata.name,NODECLASS:.spec.template.spec.nodeClassRef.name,READY:.status.conditions[?(@.type=="Ready")].status,WEIGHT:.spec.weight' \
  2>/dev/null || echo "  (none)"
echo

echo "== EC2NodeClasses (Ready condition) =="
kubectl get ec2nodeclasses \
  -o custom-columns='NAME:.metadata.name,READY:.status.conditions[?(@.type=="Ready")].status' \
  2>/dev/null || echo "  (none)"
echo

echo "== NodeClaims (default printer columns: TYPE/CAPACITY/ZONE/NODE/READY/AGE) =="
kubectl get nodeclaims 2>/dev/null || echo "  (none)"
echo
echo "Goal: controller READY == DESIRED, all three CRDs present, every NodePool and"
echo "EC2NodeClass Ready=True, and NodeClaims reaching READY=True. A False/blank Ready"
echo "or a MISSING CRD is where to dig next (kubectl describe the offending object)."
