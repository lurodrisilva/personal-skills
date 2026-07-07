#!/usr/bin/env bash
# alert-routing-check.sh — READ-ONLY Alertmanager config + routing validation.
#
# Validates an Alertmanager config with `amtool check-config`, prints the routing tree
# with `amtool config routes show`, and — only if ROUTE_TEST_LABELS is set — simulates
# where a sample label set would route with `amtool config routes test` (a read-only
# simulation; it sends nothing). It only runs `check-config` and `config routes
# show/test` (reads/validators). It NEVER creates silences or alerts (those mutating
# amtool verbs are banned), and never applies, pushes, or edits anything. Needs `amtool`
# on PATH (ships with Alertmanager). No running Alertmanager is required.
#
# Review this script before running. Validation/simulation is a starting point, not an
# approval: changing an Alertmanager route is a separate, gated Git change (PR + CI) —
# a wrong route can silence a real page. This script only reads/validates/simulates.
#
# Env:
#   AM_CONFIG          path to alertmanager.yml   (default ./alertmanager.yml)
#   ROUTE_TEST_LABELS  optional labels for a read-only route simulation,
#                      e.g. 'severity=page namespace=payments'
#
# Usage:
#   bash alert-routing-check.sh
#   AM_CONFIG=alertmanager.yaml bash alert-routing-check.sh
#   ROUTE_TEST_LABELS='severity=page namespace=payments' bash alert-routing-check.sh
set -euo pipefail

command -v amtool >/dev/null 2>&1 || {
  echo "amtool not found on PATH — install Alertmanager (ships amtool) to validate. Skipping." >&2
  exit 0
}

AM_CONFIG="${AM_CONFIG:-./alertmanager.yml}"
echo "== amtool ($(amtool --version 2>&1 | head -1))  ·  read-only validation =="
echo

if [[ ! -f "${AM_CONFIG}" ]]; then
  echo "  (no config at ${AM_CONFIG} — set AM_CONFIG; nothing to validate)"
  exit 0
fi

echo "== check-config: ${AM_CONFIG} =="
amtool check-config "${AM_CONFIG}" || echo "  (check-config reported issues — review above)"
echo

echo "== routing tree: config routes show =="
amtool config routes show --config.file "${AM_CONFIG}" 2>/dev/null \
  || echo "  (routes show failed — review the config)"
echo

if [[ -n "${ROUTE_TEST_LABELS:-}" ]]; then
  echo "== route simulation (read-only): ${ROUTE_TEST_LABELS} =="
  # shellcheck disable=SC2086
  amtool config routes test --config.file "${AM_CONFIG}" ${ROUTE_TEST_LABELS} 2>/dev/null \
    || echo "  (routes test failed — check label syntax 'k=v k=v')"
  echo
else
  echo "== route simulation skipped (set ROUTE_TEST_LABELS='k=v k=v' to simulate) =="
  echo
fi

echo "Goal: the Alertmanager config parses and the routing tree sends page-vs-ticket to"
echo "the intended receivers BEFORE it reaches CI/Git. amtool only validates/simulates"
echo "here — it never adds a silence or an alert. Changing a route is a separate,"
echo "human-approved Git change (PR + CI); a wrong route can silence a real page."
