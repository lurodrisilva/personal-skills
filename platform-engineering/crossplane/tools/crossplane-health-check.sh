#!/usr/bin/env bash
# crossplane-health-check.sh — READ-ONLY control-plane health surface.
#
# Reports the core control plane and installed packages: pods in crossplane-system,
# Providers (INSTALLED/HEALTHY), Functions, Configurations, ProviderRevisions (there
# should be exactly one Active per package), and the dependency Lock. Only runs
# `kubectl get` (reads); it never installs, patches, activates, or deletes anything.
# Needs read access to pkg.crossplane.io resources + pods in crossplane-system.
#
# Review this script before running. Starting point, not a certified audit. Installing
# a package, activating a revision, or scaling the control plane is a separate,
# human-approved action.
#
# Usage: bash crossplane-health-check.sh
set -euo pipefail

command -v kubectl >/dev/null 2>&1 || { echo "kubectl not found on PATH" >&2; exit 2; }

NS="${CROSSPLANE_NAMESPACE:-crossplane-system}"

echo "== Core pods ($NS) =="
kubectl get pods -n "$NS" -o custom-columns='NAME:.metadata.name,READY:.status.containerStatuses[*].ready,PHASE:.status.phase' 2>/dev/null \
  || echo "  (namespace $NS not found / no access)"
echo

echo "== Providers (want INSTALLED=True + HEALTHY=True) =="
kubectl get providers.pkg.crossplane.io -o custom-columns='NAME:.metadata.name,INSTALLED:.status.conditions[?(@.type=="Installed")].status,HEALTHY:.status.conditions[?(@.type=="Healthy")].status,PACKAGE:.spec.package' 2>/dev/null \
  || echo "  (no providers / CRD not installed / no access)"
echo

echo "== Functions =="
kubectl get functions.pkg.crossplane.io -o custom-columns='NAME:.metadata.name,INSTALLED:.status.conditions[?(@.type=="Installed")].status,HEALTHY:.status.conditions[?(@.type=="Healthy")].status,PACKAGE:.spec.package' 2>/dev/null \
  || echo "  (none / CRD not installed / no access)"
echo

echo "== Configurations =="
kubectl get configurations.pkg.crossplane.io -o custom-columns='NAME:.metadata.name,INSTALLED:.status.conditions[?(@.type=="Installed")].status,HEALTHY:.status.conditions[?(@.type=="Healthy")].status,PACKAGE:.spec.package' 2>/dev/null \
  || echo "  (none / CRD not installed / no access)"
echo

echo "== ProviderRevisions (exactly one STATE=Active per package) =="
kubectl get providerrevisions.pkg.crossplane.io -o custom-columns='NAME:.metadata.name,STATE:.spec.desiredState,HEALTHY:.status.conditions[?(@.type=="Healthy")].status,REVISION:.spec.revision,IMAGE:.spec.image' 2>/dev/null \
  || echo "  (none / CRD not installed / no access)"
echo

echo "== Dependency Lock =="
kubectl get lock.pkg.crossplane.io -o custom-columns='NAME:.metadata.name,PACKAGES:.packages[*].name' 2>/dev/null \
  || echo "  (no lock / CRD not installed / no access)"
echo

echo "Goal: every Provider/Function/Configuration INSTALLED=True + HEALTHY=True, one"
echo "Active ProviderRevision each. INSTALLED but not HEALTHY often = missing pull secret"
echo "or ImagePullBackOff on the controller pod (check the pod above + provider logs)."
echo "This script only reads — installs/activations are separate, human-approved actions."
