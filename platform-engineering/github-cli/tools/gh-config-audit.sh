#!/usr/bin/env bash
# gh-config-audit.sh — READ-ONLY GitHub CLI local-hygiene audit.
#
# Surfaces the local `gh` setup and its common smells: version, effective config, installed
# extensions, and environment anti-patterns (a token pinned in an env var, a PAT sitting in a
# local .env, prompting left on, telemetry on). Only calls `gh --version`, `gh config list/get`,
# and `gh extension list` (reads) plus local `grep`/`printenv` — it never sets config, installs
# or upgrades an extension, or logs in.
#
# It prints NO token value. `printenv` is used only to test PRESENCE of a token env var.
# Review this script before running. Any `gh config set` / `gh extension` change is a
# separate, deliberate action.
#
# Usage:
#   bash gh-config-audit.sh
#   GH_HOST=ghe.example.com bash gh-config-audit.sh   # also show per-host config
set -euo pipefail

command -v gh >/dev/null 2>&1 || { echo "gh CLI not found on PATH" >&2; exit 2; }

echo "== gh version =="
gh --version 2>/dev/null | head -n1 || echo "  (could not read version)"

echo
echo "== Effective config (global) =="
gh config list 2>/dev/null || echo "  (could not read config)"
if [[ -n "${GH_HOST:-}" ]]; then
  echo
  echo "== Per-host config (${GH_HOST}) =="
  gh config list --host "${GH_HOST}" 2>/dev/null || echo "  (none)"
fi

echo
echo "== Installed extensions (unverified third-party code — pin + review) =="
gh extension list 2>/dev/null || echo "  (none installed)"

echo
echo "== Hygiene smells =="
for v in GH_TOKEN GITHUB_TOKEN GH_ENTERPRISE_TOKEN GITHUB_ENTERPRISE_TOKEN; do
  if printenv "$v" >/dev/null 2>&1; then
    echo "  [note] ${v} is set in the environment (value not shown) — fine for CI; avoid in a shared shell profile"
  fi
done

TELEMETRY="$(gh config get telemetry 2>/dev/null || true)"
[[ "${TELEMETRY:-enabled}" != "disabled" ]] && echo "  [note] telemetry is enabled — consider disabling it for CI/shared use"

PROMPT="$(gh config get prompt 2>/dev/null || true)"
[[ "${PROMPT:-enabled}" != "disabled" && -n "${CI:-}" ]] && echo "  [warn] running under CI but interactive prompting is enabled — export GH_PROMPT_DISABLED=1"

if [[ -f .env ]] && grep -qiE '(gh|github)[_-]?(token|pat)|ghp_|github_pat_' .env 2>/dev/null; then
  echo "  [warn] a GitHub token pattern appears in ./.env — move it to a secret manager, never commit it"
fi

echo "  audit complete (read-only)."
