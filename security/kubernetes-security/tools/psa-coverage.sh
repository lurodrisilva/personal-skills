#!/usr/bin/env bash
# psa-coverage.sh — READ-ONLY Pod Security Admission coverage check.
#
# Lists namespaces that do NOT enforce a Pod Security Admission level, or that
# enforce only `privileged`. Only runs `kubectl get`; it never mutates the
# cluster. Needs read access to namespaces.
#
# Review this script before running. Starting point, not a certified audit.
# Usage: bash psa-coverage.sh
set -euo pipefail

command -v kubectl >/dev/null 2>&1 || { echo "kubectl not found on PATH" >&2; exit 2; }

enforce_key='pod-security\.kubernetes\.io/enforce'

echo "== Namespaces without a hardened Pod Security Admission enforce level =="
echo "   (no enforce setting, or enforce=privileged)"
kubectl get namespaces \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.labels.pod-security\.kubernetes\.io/enforce}{"\n"}{end}' \
  2>/dev/null \
  | awk -F '\t' '{ lvl=$2; if (lvl=="" || lvl=="privileged") printf "  %-40s enforce=%s\n", $1, (lvl==""?"(none)":lvl) }' \
  || true
echo
echo "Goal: every workload namespace enforces baseline or (preferably) restricted."
echo "Reference key: ${enforce_key}=restricted"
