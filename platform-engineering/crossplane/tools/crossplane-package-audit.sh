#!/usr/bin/env bash
# crossplane-package-audit.sh — READ-ONLY package-supply-chain surface.
#
# Checks every installed package (Provider / Function / Configuration) for a
# fully-qualified, pinned OCI reference: flags packages using a mutable :tag instead of
# an @sha256: digest (drift risk in prod), and lists ImageConfigs (registry auth /
# mirror / Cosign signature verification). Only runs `kubectl get` (reads); it never
# installs, upgrades, signs, or deletes a package. Needs read access to pkg.crossplane.io.
#
# Review this script before running. Starting point, not a certified audit. Pinning a
# digest, adding an ImageConfig, or upgrading a package is a separate, human-approved
# action.
#
# Usage: bash crossplane-package-audit.sh
set -euo pipefail

command -v kubectl >/dev/null 2>&1 || { echo "kubectl not found on PATH" >&2; exit 2; }

report_packages() {
  local kind="$1" label="$2"
  echo "== $label: package references (want @sha256: digest in prod) =="
  kubectl get "$kind" -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.package}{"\n"}{end}' 2>/dev/null \
    | awk -F'\t' '
        NF>=2 {
          pin = ($2 ~ /@sha256:/) ? "digest-pinned" : "TAG-ONLY (not digest-pinned)"
          fq  = ($2 ~ /\//)       ? ""              : "  [NOT fully-qualified]"
          printf "  %-32s %-12s %s%s\n", $1, pin, $2, fq
        }' \
    || echo "  (none / CRD not installed / no access)"
  echo
}

report_packages providers.pkg.crossplane.io      "Providers"
report_packages functions.pkg.crossplane.io      "Functions"
report_packages configurations.pkg.crossplane.io "Configurations"

echo "== ImageConfigs (registry auth / mirror / Cosign verification) =="
kubectl get imageconfigs.pkg.crossplane.io -o custom-columns='NAME:.metadata.name,MATCH:.spec.matchImages[*].prefix,VERIFY:.spec.verification.provider' 2>/dev/null \
  || echo "  (no ImageConfigs / CRD not installed / no access)"
echo

echo "Goal: every package fully-qualified (xpkg.crossplane.io/...) and @sha256-pinned in"
echo "prod, with an ImageConfig enforcing signature verification where required. This"
echo "script only reads — pinning/signing/upgrading is a separate, human-approved action."
