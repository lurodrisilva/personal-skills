#!/usr/bin/env bash
# gh-auth-check.sh — READ-ONLY GitHub CLI identity / host / token-source snapshot.
#
# The "first command in every script" analogue: confirms WHO you are authenticated as,
# WHICH host is active (github.com vs a GitHub Enterprise Server), and WHERE the effective
# credential comes from (a GH_TOKEN/GITHUB_TOKEN env var vs the stored keyring/hosts.yml),
# before any real work runs. Only calls `gh auth status` and read-only `gh api` GETs — it
# never logs in, refreshes, switches, or mutates anything.
#
# It deliberately prints NO token. It NEVER calls `gh auth token` (which emits a live
# credential). It reports only the token SOURCE and the redacted `gh auth status` output.
#
# Needs a valid `gh auth login` (or a GH_TOKEN/GITHUB_TOKEN env var). Review this script
# before running. Any login / refresh / switch is a separate, deliberate action.
#
# Usage:
#   bash gh-auth-check.sh
#   GH_HOST=ghe.example.com bash gh-auth-check.sh    # inspect a GitHub Enterprise Server host
set -euo pipefail

command -v gh >/dev/null 2>&1 || { echo "gh CLI not found on PATH" >&2; exit 2; }

HOST="${GH_HOST:-github.com}"
HOST_ARGS=()
[[ -n "${GH_HOST:-}" ]] && HOST_ARGS=(--hostname "${GH_HOST}")

echo "== Active account / host (token redacted) =="
if ! gh auth status "${HOST_ARGS[@]}" 2>&1; then
  echo "  Not authenticated for ${HOST}. Run 'gh auth login' first." >&2
  exit 4
fi

echo
echo "== Who am I (github.com/GHES user login) =="
gh api user --jq '"login: \(.login)   name: \(.name // "-")   id: \(.id)"' 2>/dev/null \
  || echo "  (could not read /user — token may lack read:user, or GHES host unreachable)"

echo
echo "== Effective token SOURCE (value never printed) =="
if [[ "${HOST}" == "github.com" || "${HOST}" == *.ghe.com ]]; then
  if [[ -n "${GH_TOKEN:-}" ]]; then
    echo "  GH_TOKEN env var is set → env token wins over any stored credential"
  elif [[ -n "${GITHUB_TOKEN:-}" ]]; then
    echo "  GITHUB_TOKEN env var is set → env token wins over any stored credential"
  else
    echo "  No GH_TOKEN/GITHUB_TOKEN env → using the stored credential (keyring or hosts.yml)"
  fi
else
  if [[ -n "${GH_ENTERPRISE_TOKEN:-}" ]]; then
    echo "  GH_ENTERPRISE_TOKEN env var is set → env token wins for this GHES host"
  elif [[ -n "${GITHUB_ENTERPRISE_TOKEN:-}" ]]; then
    echo "  GITHUB_ENTERPRISE_TOKEN env var is set → env token wins for this GHES host"
  else
    echo "  No GH_ENTERPRISE_TOKEN env → using the stored credential for ${HOST}"
  fi
fi

echo
echo "== API rate-limit headroom (confirms the token authenticates) =="
gh api rate_limit --jq '.resources.core | "core: \(.remaining)/\(.limit) remaining (resets \(.reset))"' 2>/dev/null \
  || echo "  (could not read /rate_limit)"
