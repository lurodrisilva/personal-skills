#!/usr/bin/env bash
# vercel-project-status.sh — READ-ONLY Vercel project + deployment status.
#
# Answers "who am I, which project, and what shipped lately?" using only GET
# requests against the Vercel REST API. It NEVER deploys, promotes, rolls back,
# edits, or deletes anything. Needs a Vercel access token with read access to
# the team/project (VERCEL_TOKEN, from the environment — never passed as an
# argument so it stays out of process lists and shell history).
#
# The token is never printed. Endpoint versions move independently on Vercel —
# if a call 404s, re-check the path against https://openapi.vercel.sh/.
#
# Review this script before running. Deploying, promoting, or rolling back is
# always a separate, human-approved action.
#
# Usage:
#   VERCEL_TOKEN=… bash vercel-project-status.sh
#   VERCEL_TOKEN=… VERCEL_TEAM_ID=team_… VERCEL_PROJECT=my-app bash vercel-project-status.sh
#   LIMIT=5 …                                # deployments to list (default 10)
set -euo pipefail

command -v curl >/dev/null 2>&1 || { echo "curl not found on PATH" >&2; exit 2; }
[[ -n "${VERCEL_TOKEN:-}" ]] || { echo "VERCEL_TOKEN is not set (export it; do not pass tokens as arguments)" >&2; exit 2; }

API="https://api.vercel.com"
TEAM_QS=""
[[ -n "${VERCEL_TEAM_ID:-}" ]] && TEAM_QS="teamId=${VERCEL_TEAM_ID}"
LIMIT="${LIMIT:-10}"
HAVE_JQ=0
command -v jq >/dev/null 2>&1 && HAVE_JQ=1

vget() { # vget <path-with-optional-query>  — read-only GET
  local path="$1" sep="?"
  [[ "${path}" == *\?* ]] && sep="&"
  [[ -n "${TEAM_QS}" ]] && path="${path}${sep}${TEAM_QS}"
  curl -sS --fail-with-body -H "Authorization: Bearer ${VERCEL_TOKEN}" "${API}${path}"
}

echo "== Vercel status  ·  team: ${VERCEL_TEAM_ID:-<personal scope>}  ·  read-only =="
echo

echo "== Identity (GET /v2/user) =="
if BODY="$(vget /v2/user 2>&1)"; then
  if [[ "${HAVE_JQ}" == "1" ]]; then
    printf '%s' "${BODY}" | jq -r '.user | "  user: \(.username // .email // .uid)"'
  else
    echo "  authenticated OK (install jq for details)"
  fi
else
  echo "  FAILED — token invalid/expired, or wrong team scope:" >&2
  printf '%s\n' "${BODY}" | head -c 300 >&2; echo >&2
  exit 1
fi
echo

if [[ -n "${VERCEL_PROJECT:-}" ]]; then
  echo "== Project (GET /v9/projects/${VERCEL_PROJECT}) =="
  if BODY="$(vget "/v9/projects/${VERCEL_PROJECT}")"; then
    if [[ "${HAVE_JQ}" == "1" ]]; then
      printf '%s' "${BODY}" | jq -r '"  id: \(.id)\n  name: \(.name)\n  framework: \(.framework // "none")\n  nodeVersion: \(.nodeVersion // "n/a")"'
    else
      echo "  project readable (install jq for details)"
    fi
  else
    echo "  (project ${VERCEL_PROJECT} not readable in this scope)"
  fi
  echo
fi

echo "== Latest deployments (GET /v7/deployments?limit=${LIMIT}) =="
DEP_PATH="/v7/deployments?limit=${LIMIT}"
[[ -n "${VERCEL_PROJECT:-}" ]] && DEP_PATH="${DEP_PATH}&app=${VERCEL_PROJECT}"
if BODY="$(vget "${DEP_PATH}")"; then
  if [[ "${HAVE_JQ}" == "1" ]]; then
    printf '%s' "${BODY}" | jq -r '
      .deployments[]? |
      "  \(.created // .createdAt | if . then (./1000 | strftime("%Y-%m-%d %H:%M")) else "?" end)  \(.state // .readyState // "?")\(if .readySubstate then "/" + .readySubstate else "" end)  \(.target // "preview")  \(.url // "?")"'
    NOT_READY="$(printf '%s' "${BODY}" | jq -r '[.deployments[]? | select((.state // .readyState) as $s | $s == "ERROR" or $s == "CANCELED" or $s == "BLOCKED")] | length')"
    [[ "${NOT_READY}" != "0" ]] && echo "  NOTE: ${NOT_READY} of the last ${LIMIT} deployments are ERROR/CANCELED/BLOCKED — inspect those first."
  else
    printf '%s' "${BODY}" | head -c 800; echo
    echo "  (raw JSON head — install jq for a summary)"
  fi
else
  echo "  FAILED to list deployments:" >&2
  printf '%s\n' "${BODY}" | head -c 300 >&2; echo >&2
fi
echo

echo "Goal: confirm who the token is, that the project resolves, and what state the"
echo "latest deployments are in (readyState/readySubstate). This script only reads;"
echo "deploy / promote / rollback are separate, human-approved actions."
