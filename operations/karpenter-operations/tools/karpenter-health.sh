#!/usr/bin/env bash
# karpenter-health.sh — READ-ONLY Karpenter health snapshot (EKS + AKS).
#
# Shows the Karpenter controller Deployment/pods (self-hosted; on AKS NAP the
# controller runs in the managed control plane and is not visible here), whether
# the core + provider CRDs are installed, and the Ready conditions of NodePools,
# NodeClasses (EC2NodeClass on AWS / AKSNodeClass on Azure), and NodeClaims. Only
# runs `kubectl get`; it never mutates the cluster. Needs read access to deployments,
# pods, crds, nodepools, ec2nodeclasses/aksnodeclasses, nodeclaims.
#
# Review this script before running. Starting point, not a certified audit.
# Usage: KARPENTER_NAMESPACE=kube-system bash karpenter-health.sh
set -euo pipefail

command -v kubectl >/dev/null 2>&1 || { echo "kubectl not found on PATH" >&2; exit 2; }
NS="${KARPENTER_NAMESPACE:-kube-system}"

echo "== Karpenter controller (namespace: $NS; empty on AKS NAP = managed control plane) =="
kubectl get deploy -n "$NS" -l app.kubernetes.io/name=karpenter \
  -o custom-columns='NAME:.metadata.name,READY:.status.readyReplicas,DESIRED:.spec.replicas' \
  2>/dev/null || echo "  (no karpenter deployment in $NS — expected on AKS NAP)"
echo

echo "== CRDs (core + whichever provider is installed) =="
for crd in nodepools.karpenter.sh nodeclaims.karpenter.sh \
           ec2nodeclasses.karpenter.k8s.aws aksnodeclasses.karpenter.azure.com; do
  if kubectl get crd "$crd" >/dev/null 2>&1; then
    printf "  present: %s\n" "$crd"
  else
    printf "  absent:  %s\n" "$crd"
  fi
done
echo "  (expect the core two + exactly one provider: AWS ec2nodeclasses OR Azure aksnodeclasses)"
echo

echo "== NodePools (Ready condition) =="
kubectl get nodepools \
  -o custom-columns='NAME:.metadata.name,NODECLASS:.spec.template.spec.nodeClassRef.name,READY:.status.conditions[?(@.type=="Ready")].status,WEIGHT:.spec.weight' \
  2>/dev/null || echo "  (none)"
echo

echo "== NodeClasses (Ready condition) =="
kubectl get ec2nodeclasses \
  -o custom-columns='NAME:.metadata.name,KIND:.kind,READY:.status.conditions[?(@.type=="Ready")].status' \
  2>/dev/null || true
kubectl get aksnodeclasses \
  -o custom-columns='NAME:.metadata.name,KIND:.kind,READY:.status.conditions[?(@.type=="Ready")].status' \
  2>/dev/null || true
echo

echo "== NodeClaims (default printer columns: TYPE/CAPACITY/ZONE/NODE/READY/AGE) =="
kubectl get nodeclaims 2>/dev/null || echo "  (none)"
echo
echo "Goal: core CRDs + one provider CRD present, every NodePool and NodeClass Ready=True,"
echo "and NodeClaims reaching READY=True. On self-hosted (EKS or Azure) also expect the"
echo "controller READY == DESIRED. A False/blank Ready or a missing CRD is where to dig"
echo "next (kubectl describe the offending object; on AKS NAP, check control-plane logs:"
echo 'AKSControlPlane | where Category == "karpenter-events").'
