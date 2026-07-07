#!/usr/bin/env bash
# otel-config-validate.sh — READ-ONLY OpenTelemetry Collector config validation.
#
# Validates a Collector config with `otelcol validate --config <file>` (trying the
# contrib distribution `otelcol-contrib` first, then `otelcol`), and lists available
# components if the binary exposes a `components` subcommand. It only runs `validate`
# and `components` (reads/validators); it never starts the collector, exports data,
# or edits anything. Needs `otelcol-contrib` or `otelcol` on PATH. No running
# collector or backend is required.
#
# Review this script before running. Validation is a starting point, not an approval:
# changing a Collector pipeline is a separate, gated Git change (PR + CI). This script
# only reads/validates.
#
# Env:
#   OTEL_CONFIG   path to the collector config   (default ./otel-collector-config.yaml)
#
# Usage:
#   bash otel-config-validate.sh
#   OTEL_CONFIG=collector.yaml bash otel-config-validate.sh
set -euo pipefail

OTELCOL_BIN=""
for candidate in otelcol-contrib otelcol; do
  if command -v "${candidate}" >/dev/null 2>&1; then
    OTELCOL_BIN="${candidate}"
    break
  fi
done
if [[ -z "${OTELCOL_BIN}" ]]; then
  echo "otelcol-contrib / otelcol not found on PATH — install an OpenTelemetry Collector distribution to validate. Skipping." >&2
  exit 0
fi

OTEL_CONFIG="${OTEL_CONFIG:-./otel-collector-config.yaml}"
echo "== ${OTELCOL_BIN} ($(${OTELCOL_BIN} --version 2>&1 | head -1))  ·  read-only validation =="
echo

echo "== validate config: ${OTEL_CONFIG} =="
if [[ -f "${OTEL_CONFIG}" ]]; then
  "${OTELCOL_BIN}" validate --config "${OTEL_CONFIG}" \
    && echo "  (config is valid)" \
    || echo "  (validate reported issues — review above)"
else
  echo "  (no config at ${OTEL_CONFIG} — set OTEL_CONFIG; skipping)"
fi
echo

echo "== available components (receivers/processors/exporters/connectors) =="
if "${OTELCOL_BIN}" components >/dev/null 2>&1; then
  "${OTELCOL_BIN}" components 2>/dev/null | head -60 \
    || echo "  (components listing failed)"
else
  echo "  (this distribution has no 'components' subcommand — skipping; verify against your distro docs)"
fi
echo

echo "Goal: the Collector config parses and its components exist in THIS distribution"
echo "(core vs contrib differ) BEFORE rollout. otelcol only validates/lists — it is not"
echo "started here. Changing a pipeline is a separate, human-approved Git change (PR + CI)."
