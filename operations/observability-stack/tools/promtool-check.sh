#!/usr/bin/env bash
# promtool-check.sh — READ-ONLY Prometheus config + rule validation (local files).
#
# Validates a Prometheus config and rule file(s) with `promtool`, and — only if a
# PROM_URL + PROM_QUERY are set — runs a single read-only `promtool query instant`.
# It only runs `promtool check config`, `promtool check rules`, and (optional)
# `promtool query instant` — all reads/validators; it never reloads, applies, pushes,
# or edits anything. Needs `promtool` on PATH (ships with Prometheus). No live cluster
# is required for the config/rule checks.
#
# Review this script before running. Validation is a starting point, not an approval:
# changing a recording/alerting rule or scrape config is a separate, gated Git change
# (PR + CI). This script only reads/validates.
#
# Env:
#   PROM_CONFIG   path to prometheus.yml           (default ./prometheus.yml)
#   RULES_GLOB    glob for rule files              (default ./rules/*.y*ml)
#   PROM_URL      optional Prometheus base URL for a read-only instant query
#   PROM_QUERY    optional PromQL for the instant query (needs PROM_URL)
#
# Usage:
#   bash promtool-check.sh
#   PROM_CONFIG=prometheus.yaml RULES_GLOB='alerts/*.yml' bash promtool-check.sh
#   PROM_URL=http://localhost:9090 PROM_QUERY='up' bash promtool-check.sh
set -euo pipefail

command -v promtool >/dev/null 2>&1 || {
  echo "promtool not found on PATH — install Prometheus (ships promtool) to validate. Skipping." >&2
  exit 0
}

PROM_CONFIG="${PROM_CONFIG:-./prometheus.yml}"
RULES_GLOB="${RULES_GLOB:-./rules/*.y*ml}"
echo "== promtool $(promtool --version 2>&1 | head -1)  ·  read-only validation =="
echo

echo "== check config: ${PROM_CONFIG} =="
if [[ -f "${PROM_CONFIG}" ]]; then
  promtool check config "${PROM_CONFIG}" || echo "  (config check reported issues — review above)"
else
  echo "  (no config at ${PROM_CONFIG} — set PROM_CONFIG; skipping)"
fi
echo

echo "== check rules: ${RULES_GLOB} =="
shopt -s nullglob
rule_files=( ${RULES_GLOB} )
shopt -u nullglob
if (( ${#rule_files[@]} > 0 )); then
  promtool check rules "${rule_files[@]}" || echo "  (rule check reported issues — review above)"
else
  echo "  (no rule files matched ${RULES_GLOB} — set RULES_GLOB; skipping)"
fi
echo

if [[ -n "${PROM_URL:-}" && -n "${PROM_QUERY:-}" ]]; then
  echo "== instant query (read-only): ${PROM_QUERY} @ ${PROM_URL} =="
  promtool query instant "${PROM_URL}" "${PROM_QUERY}" \
    || echo "  (query failed — is ${PROM_URL} reachable and read-only?)"
  echo
else
  echo "== instant query skipped (set PROM_URL + PROM_QUERY for a read-only query) =="
  echo
fi

echo "Goal: rules and config parse and are semantically valid BEFORE they reach CI/Git."
echo "promtool only validates/queries — nothing is reloaded or applied. Changing a rule or"
echo "scrape config is a separate, human-approved Git change (PR + CI)."
