#!/usr/bin/env bash
# tf-state-inventory.sh — READ-ONLY Terraform/OpenTofu state & config inventory.
#
# Reports the tool version, the provider dependency tree, the workspaces, and every
# managed resource address in state (optionally the outputs). Only runs read verbs
# (`version`, `providers`, `workspace list`, `state list`, `output`); it NEVER
# mutates state — the `state` subcommand is never used to move/remove/push, and
# there is no `import`, no `apply`, no `force-unlock`. Reading state can surface
# secret values in outputs — handle the output accordingly. Needs read access to the
# configured backend/state; run it AFTER a human has run `terraform init`.
#
# Review this script before running. Rewriting state (mv/rm/push, force-unlock) is
# always a separate, human-approved, backup-first change. Apply is always a separate,
# human-approved change.
#
# Usage:
#   TF_DIR=. bash tf-state-inventory.sh
#   TF_DIR=envs/prod SHOW_OUTPUTS=1 bash tf-state-inventory.sh
set -euo pipefail

# Prefer terraform; tolerate OpenTofu's `tofu`.
TF_BIN=""
if command -v terraform >/dev/null 2>&1; then TF_BIN="terraform"
elif command -v tofu >/dev/null 2>&1; then TF_BIN="tofu"
else echo "neither 'terraform' nor 'tofu' found on PATH" >&2; exit 2; fi

TF_DIR="${TF_DIR:-.}"
SHOW_OUTPUTS="${SHOW_OUTPUTS:-0}"
echo "== ${TF_BIN} state inventory  ·  dir: ${TF_DIR}  ·  read-only (no state mutation) =="
echo

echo "== version =="
"${TF_BIN}" -chdir="${TF_DIR}" version 2>/dev/null || echo "  (version query failed)"
echo

echo "== providers (dependency tree; exact versions are pinned in .terraform.lock.hcl) =="
"${TF_BIN}" -chdir="${TF_DIR}" providers 2>/dev/null \
  || echo "  (providers query failed — run '${TF_BIN} init' first)"
echo

echo "== workspaces (* = current) =="
"${TF_BIN}" -chdir="${TF_DIR}" workspace list 2>/dev/null \
  || echo "  (no workspaces / not initialized)"
echo

echo "== managed resource addresses (state list) =="
"${TF_BIN}" -chdir="${TF_DIR}" state list 2>/dev/null \
  || echo "  (empty state / not initialized)"
echo

if [[ "${SHOW_OUTPUTS}" == "1" ]]; then
  echo "== outputs (may include SENSITIVE values — handle with care) =="
  "${TF_BIN}" -chdir="${TF_DIR}" output 2>/dev/null || echo "  (no outputs)"
  echo
fi

echo "Goal: a read-only picture of what this config manages — version, providers,"
echo "workspaces, and every resource address in state. Reshaping state (mv/rm/push,"
echo "import, force-unlock) is a separate, backup-first, human-approved change;"
echo "this script only reads."
