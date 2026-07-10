#!/usr/bin/env bash
# az-config-audit.sh — READ-ONLY audit of the LOCAL Azure CLI setup + environment.
#
# Surfaces the effective CLI version, configuration, installed extensions, and the
# environment-variable surface, then flags common anti-patterns (telemetry left on,
# a long-lived service-principal secret sitting in the environment, no default output
# format, dynamic extension install disabled). Everything here is LOCAL and read-only:
# it runs `az version` / `az config get` / `az extension list` / `az cloud show` and, at
# most, `az account show` — it never sets config, installs, provisions, or deletes.
#
# Needs no Azure RBAC (config/version/extensions are local); the optional identity line
# needs a valid `az login`. Review this script before running. Fixing any flagged smell
# (e.g. disabling telemetry via `az config`, key core.collect_telemetry=no) is a separate,
# deliberate action.
#
# Usage:
#   bash az-config-audit.sh
set -euo pipefail

command -v az >/dev/null 2>&1 || { echo "az CLI not found on PATH" >&2; exit 2; }

echo "== CLI + extension versions =="
az version -o table 2>/dev/null || az version

echo
echo "== Installed extensions =="
az extension list --query "[].{name:name, version:version, preview:preview, experimental:experimental}" -o table 2>/dev/null \
  || echo "  (none installed)"

echo
echo "== Effective configuration (az config get) =="
az config get 2>/dev/null || echo "  (no config set — all defaults)"

echo
echo "== Active cloud =="
az cloud show --query "{cloud:name, isActive:isActive}" -o table 2>/dev/null || echo "  (unavailable)"

echo
echo "== Local hygiene checks =="

TELEMETRY="$(az config get core.collect_telemetry --query value -o tsv 2>/dev/null || true)"
case "${TELEMETRY,,}" in
  0|no|false|off) echo "  [ok]   telemetry disabled" ;;
  "")             echo "  [warn] telemetry not explicitly disabled (default is ON) — disable in CI via 'az config' (key core.collect_telemetry=no)" ;;
  *)              echo "  [warn] telemetry ENABLED (${TELEMETRY}) — disable in CI via 'az config' (key core.collect_telemetry=no)" ;;
esac

OUTPUT="$(az config get core.output --query value -o tsv 2>/dev/null || true)"
if [[ -n "${OUTPUT}" ]]; then
  echo "  [ok]   default output format: ${OUTPUT}"
else
  echo "  [info] no default output format set (falls back to json)"
fi

DYN="$(az config get extension.use_dynamic_install --query value -o tsv 2>/dev/null || true)"
echo "  [info] extension.use_dynamic_install: ${DYN:-yes_prompt (default)}"

if [[ -n "${AZURE_CLIENT_SECRET:-}" ]]; then
  echo "  [ALERT] AZURE_CLIENT_SECRET is set in the environment — a long-lived SP secret."
  echo "          Prefer managed identity / federated OIDC. Never commit or log this value."
else
  echo "  [ok]   no AZURE_CLIENT_SECRET in the environment"
fi

if [[ "${AZURE_CLI_DISABLE_CONNECTION_VERIFICATION:-}" == "1" ]]; then
  echo "  [ALERT] AZURE_CLI_DISABLE_CONNECTION_VERIFICATION=1 — TLS verification is OFF (insecure)."
  echo "          Prefer appending your proxy CA to REQUESTS_CA_BUNDLE."
fi

echo
echo "== Identity (optional — needs a login) =="
az account show --query "{subscription:name, tenantId:tenantId, user:user.name}" -o table 2>/dev/null \
  || echo "  (not logged in — run 'az login')"
