#!/usr/bin/env bash
# vercel-git-connection-audit.sh — READ-ONLY audit of a project's Git wiring.
#
# Answers "which repo / provider / production branch is this Vercel project
# connected to, and are automatic Git deployments enabled?" using only GET
# requests against the Vercel REST API. It NEVER connects, disconnects,
# deploys, or edits anything. Needs a Vercel access token with read access
# (VERCEL_TOKEN, from the environment — never passed as an argument so it
# stays out of process lists and shell history). The token is never printed.
#
# Endpoint versions move independently on Vercel — if a call 404s, re-check
# the path against https://openapi.vercel.sh/.
#
# Review this script before running. Connecting/disconnecting a repository or
# changing branch tracking is always a separate, human-approved action.
#
# Usage:
#   VERCEL_TOKEN=… VERCEL_PROJECT=my-app bash vercel-git-connection-audit.sh
#   VERCEL_TOKEN=… VERCEL_TEAM_ID=team_… VERCEL_PROJECT=my-app bash vercel-git-connection-audit.sh
set -euo pipefail

: "${VERCEL_TOKEN:?Set VERCEL_TOKEN in the environment (read-scope token)}"
: "${VERCEL_PROJECT:?Set VERCEL_PROJECT to the project name or prj_… id}"
API="https://api.vercel.com"
TEAM_QS=""
[ -n "${VERCEL_TEAM_ID:-}" ] && TEAM_QS="?teamId=${VERCEL_TEAM_ID}"

command -v jq >/dev/null || { echo "jq is required" >&2; exit 2; }

get() { curl -fsS -H "Authorization: Bearer ${VERCEL_TOKEN}" "${API}${1}"; }

project_json="$(get "/v9/projects/${VERCEL_PROJECT}${TEAM_QS}")"

echo "== Git connection audit: $(jq -r '.name' <<<"$project_json") =="
jq -r '
  def na: if . == null or . == "" then "(not set)" else . end;
  "provider:            \(.link.type // "NOT CONNECTED (external-CI posture?)")",
  "repo:                \((.link.org // .link.projectNamespace // .link.owner // "?") + "/" + (.link.repo // .link.projectName // "?") | na)",
  "repo id:             \(.link.repoId // .link.projectId // "" | tostring | na)",
  "production branch:   \(.link.productionBranch // .targets.production.meta.githubCommitRef // "" | na)",
  "connected at:        \(.link.createdAt // "" | tostring | na)",
  "git fork protection: \(.gitForkProtection // "" | tostring | na)",
  "git LFS:             \(.gitLFS // "" | tostring | na)",
  "auto-assign domains: \(.autoAssignCustomDomains // "" | tostring | na)"
' <<<"$project_json"

echo
echo "== vercel.json git config seen by Vercel (if any) =="
jq -r '
  if .gitComments then "gitComments:          \(.gitComments | tostring)" else empty end,
  if .connectConfigurationId then "connectConfiguration: \(.connectConfigurationId)" else empty end
' <<<"$project_json"
echo "note: git.deploymentEnabled / github.autoJobCancelation live in the"
echo "      repo's vercel.json — inspect the working tree, not the API."

echo
echo "== Latest deployments with Git metadata (sanity: is Git driving deploys?) =="
get "/v6/deployments${TEAM_QS:-?}${TEAM_QS:+&}projectId=$(jq -r '.id' <<<"$project_json")&limit=5" |
  jq -r '.deployments[]? |
    "\(.created // .createdAt) \(.state // .readyState) target=\(.target // "preview") " +
    "ref=\(.meta.githubCommitRef // .meta.gitlabCommitRef // .meta.bitbucketCommitRef // "-") " +
    "sha=\((.meta.githubCommitSha // .meta.gitlabCommitSha // .meta.bitbucketCommitSha // "-")[0:10])"'

echo
echo "Read-only audit complete. Any change is a separate, human-approved action."
