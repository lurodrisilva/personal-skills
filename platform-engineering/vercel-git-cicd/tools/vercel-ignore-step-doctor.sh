#!/usr/bin/env bash
# vercel-ignore-step-doctor.sh — READ-ONLY, LOCAL dry-run of a Vercel
# Ignored Build Step.
#
# Answers "would this commit build or be skipped?" by running the same kind
# of check Vercel runs (against your local git checkout — no network, no
# token, nothing mutated). Remember the inverted contract:
#   exit 0  => Vercel SKIPS the build   (deployment shows as 'ignored')
#   exit 1  => Vercel BUILDS
#
# Vercel clones with --depth=10, so any heuristic that walks further back
# than ten commits will behave differently in CI than it does here.
#
# Usage:
#   bash vercel-ignore-step-doctor.sh                          # diff HEAD^..HEAD on repo root
#   ROOT_DIR=apps/web bash vercel-ignore-step-doctor.sh        # scope to a monorepo app
#   IGNORE_COMMAND='npx turbo-ignore' bash vercel-ignore-step-doctor.sh
set -euo pipefail

ROOT_DIR="${ROOT_DIR:-.}"

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  echo "not a git repository" >&2; exit 2; }

echo "== Ignored Build Step dry-run =="
echo "root directory : ${ROOT_DIR}"
echo "HEAD           : $(git log -1 --format='%h %s' 2>/dev/null || echo '?')"

if ! git rev-parse HEAD^ >/dev/null 2>&1; then
  echo "HEAD has no parent (first commit / shallow edge) — Vercel would BUILD."
  exit 0
fi

if [ -n "${IGNORE_COMMAND:-}" ]; then
  echo "command        : ${IGNORE_COMMAND}"
  set +e
  ( eval "${IGNORE_COMMAND}" )
  rc=$?
  set -e
else
  echo "command        : git diff HEAD^ HEAD --quiet -- ${ROOT_DIR}"
  set +e
  git diff HEAD^ HEAD --quiet -- "${ROOT_DIR}"
  rc=$?
  set -e
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "exit ${rc} -> Vercel would SKIP this build (deployment 'ignored')."
else
  echo "exit ${rc} -> Vercel would BUILD."
fi

depth="$(git rev-list --count HEAD 2>/dev/null || echo '?')"
if [ "$depth" != "?" ] && [ "$depth" -lt 10 ]; then
  echo "note: local history has only ${depth} commit(s); results near the"
  echo "      shallow edge may differ from Vercel's --depth=10 clone."
fi
if command -v npx >/dev/null 2>&1 && [ -f turbo.json ]; then
  echo "hint: turbo.json detected — 'npx turbo-ignore' is graph-aware and"
  echo "      usually beats a path diff in a monorepo."
fi
echo "Nothing was modified; configuring the real Ignored Build Step in"
echo "Project Settings -> Git is a separate, human-approved action."
