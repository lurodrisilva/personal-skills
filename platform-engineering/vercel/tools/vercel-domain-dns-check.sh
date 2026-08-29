#!/usr/bin/env bash
# vercel-domain-dns-check.sh — READ-ONLY check of a Vercel project's domains:
# what is attached, whether Vercel reports it misconfigured, and (optionally)
# what the domain actually resolves to right now.
#
# Uses only GET requests against the Vercel REST API plus optional local DNS
# lookups (dig). It NEVER adds, verifies, moves, or removes a domain, DNS
# record, alias, or certificate. Needs: VERCEL_TOKEN (env), VERCEL_PROJECT.
# Optional: VERCEL_TEAM_ID, RESOLVE=0 to skip live DNS lookups.
#
# Remember the skill's rule: the dashboard DOMAIN CARD is the source of truth
# for A/CNAME values — newer projects use pooled anycast IPs and per-project
# CNAME targets (vercel-dns-0NN.com zones). This script reports what IS, and
# flags what Vercel itself marks misconfigured; it does not guess the values.
#
# Usage:
#   VERCEL_TOKEN=… VERCEL_PROJECT=my-app bash vercel-domain-dns-check.sh
#   VERCEL_TOKEN=… VERCEL_TEAM_ID=team_… VERCEL_PROJECT=my-app RESOLVE=0 bash vercel-domain-dns-check.sh
set -euo pipefail

command -v curl >/dev/null 2>&1 || { echo "curl not found on PATH" >&2; exit 2; }
[[ -n "${VERCEL_TOKEN:-}" ]]   || { echo "VERCEL_TOKEN is not set (export it; do not pass tokens as arguments)" >&2; exit 2; }
[[ -n "${VERCEL_PROJECT:-}" ]] || { echo "VERCEL_PROJECT is not set (project name or prj_… id)" >&2; exit 2; }

API="https://api.vercel.com"
QS=""
[[ -n "${VERCEL_TEAM_ID:-}" ]] && QS="?teamId=${VERCEL_TEAM_ID}"
RESOLVE="${RESOLVE:-1}"
HAVE_JQ=0; command -v jq  >/dev/null 2>&1 && HAVE_JQ=1
HAVE_DIG=0; command -v dig >/dev/null 2>&1 && HAVE_DIG=1

echo "== Vercel domain/DNS check  ·  project: ${VERCEL_PROJECT}  ·  read-only =="
echo

BODY="$(curl -sS --fail-with-body -H "Authorization: Bearer ${VERCEL_TOKEN}" \
  "${API}/v9/projects/${VERCEL_PROJECT}/domains${QS}")" || {
  echo "FAILED — token invalid, wrong team scope, or project not found:" >&2
  printf '%s\n' "${BODY}" | head -c 300 >&2; echo >&2
  exit 1
}

if [[ "${HAVE_JQ}" != "1" ]]; then
  echo "== Project domains (raw head — install jq for the full check) =="
  printf '%s' "${BODY}" | head -c 800; echo
  echo "jq not found: skipping the per-domain config check." >&2
  exit 0
fi

DOMAINS="$(printf '%s' "${BODY}" | jq -r '.domains[]?.name')"
if [[ -z "${DOMAINS}" ]]; then
  echo "No custom domains attached to ${VERCEL_PROJECT} (previews still serve on *.vercel.app)."
  exit 0
fi

printf '%s' "${BODY}" | jq -r '.domains[]? |
  "  \(.name)  ·  verified: \(.verified // false)\(if .gitBranch then "  ·  branch:" + .gitBranch else "" end)\(if .redirect then "  ·  redirects → " + .redirect else "" end)"'
echo

echo "== Per-domain config (GET /v6/domains/{domain}/config — Vercel's own verdict) =="
MISCONFIGURED=0
while IFS= read -r d; do
  [[ -n "${d}" ]] || continue
  CFG="$(curl -sS -H "Authorization: Bearer ${VERCEL_TOKEN}" \
    "${API}/v6/domains/${d}/config${QS}" 2>/dev/null || true)"
  MIS="$(printf '%s' "${CFG}" | jq -r '.misconfigured // "unknown"' 2>/dev/null || echo unknown)"
  if [[ "${MIS}" == "true" ]]; then
    echo "  ${d}: MISCONFIGURED — open the project's domain card and set the A/CNAME it shows."
    MISCONFIGURED=1
  else
    echo "  ${d}: misconfigured=${MIS}"
  fi
  if [[ "${RESOLVE}" == "1" && "${HAVE_DIG}" == "1" ]]; then
    A="$(dig +short A "${d}" 2>/dev/null | paste -sd ' ' - || true)"
    CN="$(dig +short CNAME "${d}" 2>/dev/null | paste -sd ' ' - || true)"
    NS="$(dig +short NS "${d}" 2>/dev/null | paste -sd ' ' - || true)"
    CAA="$(dig +short CAA "${d}" 2>/dev/null | paste -sd ' ' - || true)"
    [[ -n "${CN}" ]] && echo "      CNAME: ${CN}"
    [[ -n "${A}"  ]] && echo "      A:     ${A}"
    [[ -n "${NS}" ]] && echo "      NS:    ${NS}"
    if [[ -n "${CAA}" ]] && ! printf '%s' "${CAA}" | grep -qi 'letsencrypt'; then
      echo "      CAA present without letsencrypt.org — cert issuance may be blocked."
    fi
  fi
done <<< "${DOMAINS}"
echo
[[ "${RESOLVE}" == "1" && "${HAVE_DIG}" != "1" ]] && { echo "(dig not found — skipped live DNS resolution)"; echo; }

if [[ "${MISCONFIGURED}" == "1" ]]; then
  echo "At least one domain is misconfigured. Fix = read the exact A/CNAME value off"
  echo "the project's domain card (do NOT use remembered defaults) and set it at the"
  echo "DNS provider — a separate, human-approved change."
fi
echo "Goal: every attached domain verified and not misconfigured, wildcards on Vercel"
echo "nameservers, CAA permitting Let's Encrypt. This script only reads; every domain,"
echo "DNS, or alias change is a separate, human-approved action."
