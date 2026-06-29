#!/usr/bin/env bash
# image-provenance.sh — READ-ONLY scan for unpinned container images.
#
# Flags running containers whose image is NOT pinned by digest (@sha256:...),
# including `:latest` and other mutable tags. Only runs `kubectl get`; it never
# mutates the cluster. Needs read access to pods.
#
# Review this script before running. Starting point, not a certified audit.
# Usage: bash image-provenance.sh
set -euo pipefail

command -v kubectl >/dev/null 2>&1 || { echo "kubectl not found on PATH" >&2; exit 2; }

echo "== Containers running images that are NOT digest-pinned (@sha256:) =="
kubectl get pods -A \
  -o jsonpath='{range .items[*]}{range .spec.containers[*]}{.. .metadata.namespace}{"/"}{.. .metadata.name}{"\t"}{.image}{"\n"}{end}{end}' \
  2>/dev/null \
  | awk -F '\t' '$2 !~ /@sha256:/ { tag=$2; sub(/.*:/,":",tag); if ($2 !~ /:/) tag=":(none, implies :latest)"; printf "  %-55s %s\n", $1, $2 }' \
  | sort -u || true
echo
echo "Goal: pin every image by digest (image@sha256:...). Mutable tags drift and"
echo "cannot be verified; enforce digest pinning + signature verification at admission."
