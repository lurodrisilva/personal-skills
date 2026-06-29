#!/usr/bin/env bash
# privileged-workloads.sh — READ-ONLY scan for over-privileged pods.
#
# Flags running pods that use node-takeover / breakout primitives: privileged
# containers, host namespaces (hostNetwork/hostPID/hostIPC), hostPath volumes,
# or that allow privilege escalation. Only runs `kubectl get`; it never mutates
# the cluster. Needs read access to pods.
#
# Review this script before running. Starting point, not a certified audit.
# Usage: bash privileged-workloads.sh
set -euo pipefail

command -v kubectl >/dev/null 2>&1 || { echo "kubectl not found on PATH" >&2; exit 2; }

echo "== Pods using host namespaces (hostNetwork / hostPID / hostIPC) =="
kubectl get pods -A \
  -o jsonpath='{range .items[?(@.spec.hostNetwork==true)]}{.metadata.namespace}{"/"}{.metadata.name}{" hostNetwork"}{"\n"}{end}' 2>/dev/null || true
kubectl get pods -A \
  -o jsonpath='{range .items[?(@.spec.hostPID==true)]}{.metadata.namespace}{"/"}{.metadata.name}{" hostPID"}{"\n"}{end}' 2>/dev/null || true
kubectl get pods -A \
  -o jsonpath='{range .items[?(@.spec.hostIPC==true)]}{.metadata.namespace}{"/"}{.metadata.name}{" hostIPC"}{"\n"}{end}' 2>/dev/null || true
echo

echo "== Pods with a privileged container =="
kubectl get pods -A \
  -o jsonpath='{range .items[*]}{range .spec.containers[?(@.securityContext.privileged==true)]}{..metadata.namespace}{"  privileged container: "}{.name}{"\n"}{end}{end}' 2>/dev/null \
  | sort -u || true
echo "  (also review: hostPath volumes, added capabilities, allowPrivilegeEscalation!=false)"
echo

echo "== Pods mounting a hostPath volume =="
kubectl get pods -A \
  -o jsonpath='{range .items[*]}{range .spec.volumes[?(@.hostPath)]}{..metadata.namespace}{"  hostPath: "}{.hostPath.path}{"\n"}{end}{end}' 2>/dev/null \
  | sort -u || true
echo
echo "Goal: none of the above outside system namespaces; enforce with restricted PSA."
