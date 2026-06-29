#!/usr/bin/env bash
# netpol-coverage.sh — READ-ONLY default-deny NetworkPolicy coverage check.
#
# Lists namespaces that contain running pods but have NO NetworkPolicy at all
# (so traffic is unrestricted / flat). Only runs `kubectl get`; it never
# mutates the cluster. Needs read access to namespaces, pods, networkpolicies.
#
# Note: presence of a NetworkPolicy is necessary but not sufficient for a true
# default-deny — review the policies it flags as "present" by hand too.
# Review this script before running. Starting point, not a certified audit.
# Usage: bash netpol-coverage.sh
set -euo pipefail

command -v kubectl >/dev/null 2>&1 || { echo "kubectl not found on PATH" >&2; exit 2; }

echo "== Namespaces with pods but NO NetworkPolicy (unrestricted / flat network) =="
for ns in $(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}' 2>/dev/null); do
  pods="$(kubectl get pods -n "$ns" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || true)"
  [ -z "$pods" ] && continue
  nps="$(kubectl get networkpolicies -n "$ns" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || true)"
  [ -z "$nps" ] && printf "  %s\n" "$ns"
done
echo
echo "Goal: each workload namespace has a default-deny (ingress AND egress) policy,"
echo "then explicit allows. A namespace listed above has no policy enforcing isolation."
