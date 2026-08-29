#!/usr/bin/env bash
# vercel-env-audit.sh — READ-ONLY audit of a Vercel project's environment
# variable NAMES, targets, and types. VALUES ARE NEVER PRINTED.
#
# Answers "what env vars exist, where do they apply, and are production values
# sensitive?" using a single GET against the Vercel REST API. It NEVER creates,
# edits, or deletes a variable, and it never calls the decrypted-value
# endpoint. jq is REQUIRED here (not optional): raw API output can carry
# values for non-sensitive vars, so this script refuses to run without jq
# rather than risk dumping a secret to stdout.
#
# Needs: VERCEL_TOKEN (env), VERCEL_PROJECT (project name or id). Optional:
# VERCEL_TEAM_ID. The token is never printed.
#
# Review this script before running. Creating or changing env vars is always a
# separate, human-approved action (and requires a redeploy to take effect).
#
# Usage:
#   VERCEL_TOKEN=… VERCEL_PROJECT=my-app bash vercel-env-audit.sh
#   VERCEL_TOKEN=… VERCEL_TEAM_ID=team_… VERCEL_PROJECT=prj_… bash vercel-env-audit.sh
set -euo pipefail

command -v curl >/dev/null 2>&1 || { echo "curl not found on PATH" >&2; exit 2; }
command -v jq  >/dev/null 2>&1 || { echo "jq is REQUIRED for this script (it guarantees no env value is ever printed)" >&2; exit 2; }
[[ -n "${VERCEL_TOKEN:-}" ]]   || { echo "VERCEL_TOKEN is not set (export it; do not pass tokens as arguments)" >&2; exit 2; }
[[ -n "${VERCEL_PROJECT:-}" ]] || { echo "VERCEL_PROJECT is not set (project name or prj_… id)" >&2; exit 2; }

API="https://api.vercel.com"
QS=""
[[ -n "${VERCEL_TEAM_ID:-}" ]] && QS="?teamId=${VERCEL_TEAM_ID}"

echo "== Vercel env audit  ·  project: ${VERCEL_PROJECT}  ·  names/targets/types only — never values =="
echo

# On ANY failure the response body is withheld: a truncated 200 body could carry
# plaintext values of non-sensitive vars, so only jq-extracted error fields are
# ever printed — never the raw body.
BODY="$(curl -sS --fail-with-body -H "Authorization: Bearer ${VERCEL_TOKEN}" \
  "${API}/v10/projects/${VERCEL_PROJECT}/env${QS}")" || {
  echo "FAILED — token invalid, wrong team scope, project not found, or transport error." >&2
  printf '%s' "${BODY}" | jq -r '
    if (type == "object" and has("error"))
    then "  error.code: \(.error.code // "?")\n  error.message: \(.error.message // "?")"
    else "  (response withheld — it is not a recognizable API error object)"
    end' >&2 2>/dev/null \
    || echo "  (response withheld — unparseable)" >&2
  exit 1
}

echo "== Variables (key · type · targets · branch) =="
printf '%s' "${BODY}" | jq -r '
  .envs[]? |
  "  \(.key)  ·  \(.type)  ·  \((.target // []) | if type == "array" then join(",") else tostring end)\(if .gitBranch then "  ·  branch:" + .gitBranch else "" end)"'
echo

echo "== Findings =="
printf '%s' "${BODY}" | jq -r '
  [.envs[]? | select((.target // []) | index("production")) | select(.type != "sensitive")] |
  if length == 0
  then "  All production-targeted variables are type \"sensitive\". Good."
  else "  NON-SENSITIVE variables targeting PRODUCTION (values readable in the dashboard/API):",
       (.[] | "    - \(.key) (type: \(.type))")
  end'
printf '%s' "${BODY}" | jq -r '
  [.envs[]? | .key] | group_by(.) | map(select(length > 1) | .[0]) |
  if length == 0 then empty
  else "  Keys defined multiple times (check target overlap):", (.[] | "    - " + .)
  end'
TOTAL="$(printf '%s' "${BODY}" | jq -r '[.envs[]?] | length')"
echo "  Total variables: ${TOTAL} (deployment cap is ~100 keys / 64 KB total — verify per plan)."
echo

echo "Goal: confirm every production secret is type \"sensitive\", targets are"
echo "deliberate, and nothing is duplicated. Values were never fetched or printed."
echo "Changing a variable is a separate, human-approved action + redeploy."
