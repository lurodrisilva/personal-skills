#!/usr/bin/env bash
# gh-api-inventory.sh — READ-ONLY GitHub estate snapshot + a `--json`/`--jq` demo.
#
# Shows a small read-only slice of what the current token can see — rate-limit headroom, the
# authenticated user, recent repositories — using only GET-shaped calls (`gh api` default GET,
# `gh repo list`, `gh api repos/{owner}/{repo}`). Doubles as a worked demo of the machine-output
# path: `--json <fields>` + built-in `--jq`. It never creates, edits, deletes, or sets anything,
# and issues no `gh api --method POST|PUT|PATCH|DELETE`.
#
# Review this script before running. Needs a valid token with at least repo read access.
#
# Usage:
#   bash gh-api-inventory.sh
#   GH_REPO=cli/cli bash gh-api-inventory.sh     # also detail one repo
#   LIMIT=20 bash gh-api-inventory.sh            # change the repo-list size
set -euo pipefail

command -v gh >/dev/null 2>&1 || { echo "gh CLI not found on PATH" >&2; exit 2; }

LIMIT="${LIMIT:-10}"

echo "== API rate-limit headroom =="
gh api rate_limit --jq '.resources.core | "core: \(.remaining)/\(.limit) (resets \(.reset))"' 2>/dev/null \
  || { echo "  (could not read /rate_limit — is a token set?)"; exit 4; }

echo
echo "== Authenticated user =="
gh api user --jq '"\(.login)  (\(.name // "-"))  public_repos=\(.public_repos)"' 2>/dev/null \
  || echo "  (could not read /user)"

echo
echo "== Recent repositories (--json + --jq demo) =="
gh repo list --limit "${LIMIT}" \
  --json nameWithOwner,visibility,isFork,updatedAt \
  --jq '.[] | "\(.nameWithOwner)\t\(.visibility)\tfork=\(.isFork)\t\(.updatedAt)"' 2>/dev/null \
  || echo "  (could not list repositories)"

if [[ -n "${GH_REPO:-}" ]]; then
  echo
  echo "== Detail for ${GH_REPO} (gh api repos/{owner}/{repo}) =="
  gh api "repos/${GH_REPO}" \
    --jq '"default_branch: \(.default_branch)   open_issues: \(.open_issues_count)   stars: \(.stargazers_count)   archived: \(.archived)"' 2>/dev/null \
    || echo "  (could not read repos/${GH_REPO})"
fi

echo
echo "inventory complete (read-only)."
