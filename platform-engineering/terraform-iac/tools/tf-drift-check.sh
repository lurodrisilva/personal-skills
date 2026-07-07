#!/usr/bin/env bash
# tf-drift-check.sh — READ-ONLY Terraform/OpenTofu drift detector.
#
# Runs `terraform plan -refresh-only -detailed-exitcode -no-color` to compare the
# REAL infrastructure against recorded state and report which resources have drifted
# (been changed out-of-band, e.g. via a console click). Only refreshes and diffs
# (reads); it NEVER applies, writes state, imports, or mutates anything —
# `-refresh-only` does not change infrastructure. Needs the same provider read
# access an apply would; run it AFTER a human has run `terraform init`.
#
# Exit codes from `-detailed-exitcode`: 0 = no drift · 1 = error · 2 = DRIFT detected.
#
# Review this script before running. Reconcile any drift by updating HCL and
# re-applying through a PR — never by clicking in the console. Apply is always a
# separate, human-approved change.
#
# Usage:
#   TF_DIR=. bash tf-drift-check.sh
#   TF_DIR=envs/prod bash tf-drift-check.sh
set -euo pipefail

# Prefer terraform; tolerate OpenTofu's `tofu`.
TF_BIN=""
if command -v terraform >/dev/null 2>&1; then TF_BIN="terraform"
elif command -v tofu >/dev/null 2>&1; then TF_BIN="tofu"
else echo "neither 'terraform' nor 'tofu' found on PATH" >&2; exit 2; fi

TF_DIR="${TF_DIR:-.}"
echo "== ${TF_BIN} drift check  ·  dir: ${TF_DIR}  ·  read-only (refresh-only, no apply) =="
echo

echo "== plan -refresh-only (real infra vs state; exit 2 == drift detected) =="
set +e
DRIFT_OUT="$("${TF_BIN}" -chdir="${TF_DIR}" plan -refresh-only -detailed-exitcode -no-color 2>&1)"
CODE=$?
set -e

case "${CODE}" in
  0) echo "  No drift: real infrastructure matches recorded state." ;;
  2) echo "  DRIFT DETECTED — resources changed outside Terraform:";
     printf '%s\n' "${DRIFT_OUT}" | grep -E '^[[:space:]]*# .* has (changed|been (deleted|changed))' \
       || printf '%s\n' "${DRIFT_OUT}" | grep -E '^(Note:|.* will be updated|Objects have changed)' \
       || echo "  (see full output below)" ;;
  *) echo "  (plan -refresh-only failed — is it initialized and readable?)" ;;
esac
echo
echo "  detailed-exitcode: ${CODE}  (0 = no drift · 1 = error · 2 = drift)"
echo

echo "Goal: surface out-of-band changes (console clicks, manual edits) as drift."
echo "Reconcile by updating HCL and re-applying through a PR — never by editing the"
echo "console. This script only refreshes and diffs; it never writes state or applies."
