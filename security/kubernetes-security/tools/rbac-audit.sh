#!/usr/bin/env bash
# rbac-audit.sh — READ-ONLY Kubernetes RBAC risk audit.
#
# Surfaces the highest-risk RBAC grants: cluster-admin bindings, wildcard
# rules, and the privilege-escalation verbs (escalate / bind / impersonate).
# Only runs `kubectl get` — it never mutates the cluster. Needs read access to
# (cluster)roles and (cluster)rolebindings (a cluster-reader is enough).
#
# Review this script before running. Starting point, not a certified audit.
# Usage: bash rbac-audit.sh            (uses the current kube-context)
set -euo pipefail

command -v kubectl >/dev/null 2>&1 || { echo "kubectl not found on PATH" >&2; exit 2; }

echo "== ClusterRoleBindings granting cluster-admin =="
kubectl get clusterrolebindings \
  -o jsonpath='{range .items[?(@.roleRef.name=="cluster-admin")]}{.metadata.name}{" -> "}{range .subjects[*]}{.kind}{"/"}{.name}{" "}{end}{"\n"}{end}' \
  2>/dev/null || true
echo

echo "== ClusterRoles with wildcard verbs/resources/apiGroups (excludes built-in admin/edit/cluster-admin) =="
kubectl get clusterroles -o json 2>/dev/null \
  | grep -E '"name": "|"\*"' \
  | grep -B1 '"\*"' \
  | grep '"name":' \
  | grep -viE 'cluster-admin|"name": "(admin|edit|system:)' \
  | sort -u || true
echo "  (review each above; a wildcard rule grants everything on that scope)"
echo

echo "== Roles/ClusterRoles granting privilege-escalation verbs (escalate / bind / impersonate) =="
for kind in clusterroles roles; do
  scope="(cluster-scoped)"; [ "$kind" = roles ] && scope="-A"
  # shellcheck disable=SC2086
  kubectl get "$kind" ${scope/(cluster-scoped)/} -o json 2>/dev/null \
    | grep -E '"name": "|escalate|impersonate|"bind"' \
    | grep -B1 -E 'escalate|impersonate|"bind"' \
    | grep '"name":' | sort -u || true
done
echo "  (these verbs let a subject grant itself or assume other identities)"
echo
echo "Done. Verify specific grants with: kubectl auth can-i <verb> <resource> --as=<subject>"
