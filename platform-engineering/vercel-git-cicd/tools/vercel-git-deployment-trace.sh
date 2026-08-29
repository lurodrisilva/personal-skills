#!/usr/bin/env bash
# vercel-git-deployment-trace.sh — READ-ONLY trace from a Git ref to its
# Vercel deployments.
#
# Answers "which deployment did this branch (or commit SHA) produce, in which
# state, targeting which environment?" using only GET requests against the
# Vercel REST API. It NEVER deploys, redeploys, promotes, or cancels.
# Needs VERCEL_TOKEN in the environment (never as an argument); the token is
# never printed. If a call 404s, re-check the path against
# https://openapi.vercel.sh/ — endpoint versions move independently.
#
# Usage:
#   VERCEL_TOKEN=… VERCEL_PROJECT=my-app bash vercel-git-deployment-trace.sh
#   … BRANCH=feature-x bash vercel-git-deployment-trace.sh    # filter by branch
#   … SHA=fa1eade bash vercel-git-deployment-trace.sh         # filter by SHA prefix
#   … LIMIT=50 bash vercel-git-deployment-trace.sh            # default 20
set -euo pipefail

: "${VERCEL_TOKEN:?Set VERCEL_TOKEN in the environment (read-scope token)}"
: "${VERCEL_PROJECT:?Set VERCEL_PROJECT to the project name or prj_… id}"
LIMIT="${LIMIT:-20}"
API="https://api.vercel.com"
TEAM_QS=""
[ -n "${VERCEL_TEAM_ID:-}" ] && TEAM_QS="&teamId=${VERCEL_TEAM_ID}"

command -v jq >/dev/null || { echo "jq is required" >&2; exit 2; }

get() { curl -fsS -H "Authorization: Bearer ${VERCEL_TOKEN}" "${API}${1}"; }

project_id="$(get "/v9/projects/${VERCEL_PROJECT}?${TEAM_QS#&}" | jq -r '.id')"

echo "== Deployment trace: ${VERCEL_PROJECT} (branch=${BRANCH:-any} sha=${SHA:-any}) =="
get "/v6/deployments?projectId=${project_id}&limit=${LIMIT}${TEAM_QS}" |
  BRANCH="${BRANCH:-}" SHA="${SHA:-}" jq -r '
    .deployments[]?
    | . as $d
    | (.meta.githubCommitRef // .meta.gitlabCommitRef // .meta.bitbucketCommitRef // "-") as $ref
    | (.meta.githubCommitSha // .meta.gitlabCommitSha // .meta.bitbucketCommitSha // "-") as $sha
    | select((env.BRANCH == "") or ($ref == env.BRANCH))
    | select((env.SHA == "") or ($sha | startswith(env.SHA)))
    | [
        ($d.created // $d.createdAt | tostring),
        ($d.state // $d.readyState // "?"),
        ("target=" + ($d.target // "preview")),
        ("ref=" + $ref),
        ("sha=" + $sha[0:10]),
        ("url=" + ($d.url // "-")),
        ("author=" + ($d.meta.githubCommitAuthorLogin // $d.meta.gitlabCommitAuthorLogin // $d.meta.bitbucketCommitAuthorLogin // "-"))
      ] | join("  ")'

echo
echo "States: QUEUED/BUILDING/READY/ERROR/CANCELED — a CANCELED entry right"
echo "after a newer push is usually auto-job-cancellation; one on an unverified"
echo "commit may be the Require Verified Commits setting; 'ignored'/'skipped'"
echo "dispatch events mean the Ignored Build Step or monorepo auto-skip fired."
echo "Read-only trace complete. Redeploy/promote is a human-approved action."
