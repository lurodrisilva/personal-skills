#!/usr/bin/env bash
# platform-maturity-scan.sh — READ-ONLY heuristic scan for IDP maturity signals.
#
# Scans a repository (or a platform monorepo) for the presence of the building
# blocks a maturing Internal Developer Platform tends to have, and prints a coarse
# scorecard mapped to the CNCF Platform Engineering Maturity Model aspects
# (Interfaces / Operations / Measurement / Adoption signals). It looks for FILES,
# it does not judge quality — a present signal means "this exists", not "this is
# good". Use the output to start a maturity conversation, not to grade anyone.
#
# This ONLY reads the filesystem (find/grep). It NEVER creates, edits, or deletes
# anything. Advancing a maturity level is a separate, human-owned decision.
#
# Review this script before running.
#
# Usage:
#   bash platform-maturity-scan.sh            # scans .
#   ROOT=../platform bash platform-maturity-scan.sh
set -euo pipefail

ROOT="${ROOT:-.}"
[ -d "$ROOT" ] || { echo "ROOT '$ROOT' is not a directory" >&2; exit 2; }

echo "== IDP maturity SIGNAL scan  ·  root: ${ROOT}  ·  read-only (presence, not quality) =="
echo "   (heuristic — a signal means 'exists', not 'is good')"
echo

# hit <label> <find-expression...> : print [found]/[----] for a signal.
found=0; total=0
hit() {
  local label="$1"; shift
  total=$((total+1))
  if find "$ROOT" -not -path '*/.git/*' \( "$@" \) 2>/dev/null | grep -q .; then
    printf '  [found] %s\n' "$label"; found=$((found+1))
  else
    printf '  [ ---- ] %s\n' "$label"
  fi
}

echo "-- Interfaces (Developer Control Plane: self-service surface) --"
hit "Backstage / portal catalog (catalog-info.yaml)"      -name 'catalog-info.yaml'
hit "Scaffolder / cookiecutter / template skeletons"      -iname 'template.yaml' -o -iname 'cookiecutter.json' -o -path '*scaffold*'
hit "Reusable IaC modules (terraform modules/ or crossplane XRDs)"  -path '*modules/*.tf' -o -iname 'definition.yaml' -o -iname '*compositeresourcedefinition*'
hit "Helm charts (packaged capability)"                   -name 'Chart.yaml'
echo

echo "-- Integration & Delivery --"
hit "CI pipelines (.github/workflows, .gitlab-ci, etc.)"  -path '*.github/workflows/*.y*ml' -o -name '.gitlab-ci.yml' -o -name 'azure-pipelines.yml'
hit "GitOps delivery (Argo CD / Flux manifests)"          -iname '*application.yaml' -o -path '*argocd*' -o -path '*flux*' -o -iname 'kustomization.yaml'
echo

echo "-- Security (safe by default) --"
hit "Policy-as-code (OPA/Rego, Kyverno, Gatekeeper, conftest)"  -name '*.rego' -o -iname '*clusterpolicy*' -o -iname '*constrainttemplate*'
hit "Secrets management (external-secrets, sealed-secrets, vault)"  -iname '*externalsecret*' -o -iname '*sealedsecret*' -o -path '*vault*'
echo

echo "-- Operations (Monitoring & Logging plane + SLOs) --"
hit "Observability config (Prometheus rules / ServiceMonitor / OTel)"  -iname '*servicemonitor*' -o -iname 'prometheusrule*' -o -iname '*otel*collector*'
hit "SLO / error-budget definitions (Sloth / OpenSLO)"    -iname '*slo*.y*ml' -o -iname '*openslo*'
echo

echo "-- Measurement & Governance --"
hit "Architecture Decision Records (docs/adr, adr/)"      -path '*adr*/*.md' -o -path '*decisions*/*.md'
hit "RFC process (docs/rfc)"                              -path '*rfc*/*.md'
hit "Technology radar data file"                          -iname '*radar*.json' -o -iname '*radar*.csv' -o -iname '*tech-radar*'
echo

echo "== ${found}/${total} maturity signals present =="
echo
echo "Reading (rough CNCF-model framing):"
echo "  - Interfaces signals low  -> self-service is thin: teams likely file tickets."
echo "  - Measurement signals low -> no ADRs/radar: decisions aren't recorded; FIX FIRST."
echo "  - Operations signals low  -> the platform itself may lack SLOs/observability."
echo
echo "Goal: presence != maturity. Use this to seed the maturity assessment"
echo "(platform-maturity-assessor, Phase F). Advancing a level is a human decision."
