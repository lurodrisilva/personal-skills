#!/usr/bin/env bash
# tf-plan-summary.sh — READ-ONLY Terraform/OpenTofu plan summary.
#
# Validates the config, then runs `terraform plan -detailed-exitcode -no-color` and
# summarizes how many resources the plan would ADD / CHANGE / DESTROY. Only runs
# `validate` and `plan` (reads/diffs); it NEVER applies, destroys, imports, taints,
# or mutates state. A plan does not change infrastructure — apply is always a
# separate, human-approved change. Needs the same provider read access an apply
# would (to refresh + diff); run it AFTER a human has run `terraform init`.
#
# Exit codes from `plan -detailed-exitcode`: 0 = no changes · 1 = error · 2 = changes.
# This script surfaces that code so CI can gate on "changes need review".
#
# Review this script before running. Apply is always a separate, human-approved
# change (read the plan, never blind-apply).
#
# Usage:
#   TF_DIR=. bash tf-plan-summary.sh
#   TF_DIR=envs/prod bash tf-plan-summary.sh
set -euo pipefail

# Prefer terraform; tolerate OpenTofu's `tofu`.
TF_BIN=""
if command -v terraform >/dev/null 2>&1; then TF_BIN="terraform"
elif command -v tofu >/dev/null 2>&1; then TF_BIN="tofu"
else echo "neither 'terraform' nor 'tofu' found on PATH" >&2; exit 2; fi

TF_DIR="${TF_DIR:-.}"
echo "== ${TF_BIN} plan summary  ·  dir: ${TF_DIR}  ·  read-only (plan does NOT apply) =="
echo

echo "== validate (config is internally consistent) =="
"${TF_BIN}" -chdir="${TF_DIR}" validate -no-color 2>/dev/null \
  || echo "  (validate failed or not initialized — run '${TF_BIN} init' first)"
echo

echo "== plan (add / change / destroy counts; exit 0=no-change 1=error 2=changes) =="
set +e
PLAN_OUT="$("${TF_BIN}" -chdir="${TF_DIR}" plan -detailed-exitcode -no-color 2>&1)"
CODE=$?
set -e

# Surface the plan's own summary line (e.g. "Plan: N to add, M to change, K to destroy.")
echo "${PLAN_OUT}" | grep -E '^(Plan:|No changes|Changes to|Error:)' || echo "  (no plan summary line — see output below)"
echo
# Count resource action lines defensively (works even when the summary line is absent).
ADD="$(printf '%s\n' "${PLAN_OUT}"    | grep -cE '^[[:space:]]*# .* will be created' || true)"
CHANGE="$(printf '%s\n' "${PLAN_OUT}" | grep -cE '^[[:space:]]*# .* will be updated in place' || true)"
DESTROY="$(printf '%s\n' "${PLAN_OUT}" | grep -cE '^[[:space:]]*# .* will be destroyed' || true)"
REPLACE="$(printf '%s\n' "${PLAN_OUT}" | grep -cE '^[[:space:]]*# .* must be replaced' || true)"
echo "  parsed action lines →  create: ${ADD}   update: ${CHANGE}   destroy: ${DESTROY}   replace: ${REPLACE}"
echo "  detailed-exitcode: ${CODE}  (0 = no changes · 1 = error · 2 = changes present)"
echo

if [[ "${DESTROY}" -gt 0 || "${REPLACE}" -gt 0 ]]; then
  echo "  !! This plan would DESTROY or REPLACE resources — stop-the-line: read every"
  echo "     destroy/replace and confirm it is intended before any gated apply."
  echo
fi

echo "Goal: read the diff BEFORE applying. A plan showing an unexpected destroy or"
echo "replacement is a stop-the-line event. Apply only the reviewed, saved plan"
echo "through a PR/pipeline gate — this script only validates and plans, it never applies."
