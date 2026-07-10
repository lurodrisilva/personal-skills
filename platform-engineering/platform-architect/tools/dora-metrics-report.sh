#!/usr/bin/env bash
# dora-metrics-report.sh — READ-ONLY DORA four-key proxy report from git history.
#
# Prints coarse proxies for the DORA four keys using ONLY git read commands:
#   - Deploy frequency  (proxy: release tags, or merges to the default branch, per week)
#   - Lead time for changes (proxy: median commit-authored -> merge/tag age)
#   - Change-fail rate  (proxy: share of commits/tags whose subject looks like a
#                        revert/hotfix/rollback — a heuristic, NOT incident data)
#   - Recovery time     (reported as "needs incident data" — git cannot know MTTR)
#
# These are STARTING-POINT proxies to spark the real measurement conversation, not
# audited DORA numbers. The authoritative signal is your CI/CD + incident systems;
# wire those in for real figures. This script ONLY reads git (`log`, `tag`,
# `rev-list`, `for-each-ref`, `merge-base`) — it never commits, pushes, tags,
# checks out, resets, or mutates the repo or any remote in any way.
#
# Review this script before running. Recording/acting on metrics is a separate,
# human-owned decision.
#
# Usage:
#   bash dora-metrics-report.sh                     # last 90 days, auto default branch
#   SINCE_DAYS=30 bash dora-metrics-report.sh
#   BRANCH=main TAG_GLOB='v*' bash dora-metrics-report.sh
set -euo pipefail

command -v git >/dev/null 2>&1 || { echo "git not found on PATH" >&2; exit 2; }
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  echo "not inside a git work tree" >&2; exit 2; }

SINCE_DAYS="${SINCE_DAYS:-90}"
TAG_GLOB="${TAG_GLOB:-v*}"
# Auto-detect the default branch (origin/HEAD) unless BRANCH is set.
if [ -n "${BRANCH:-}" ]; then
  DEF_BRANCH="$BRANCH"
else
  DEF_BRANCH="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@^origin/@@' || true)"
  [ -n "$DEF_BRANCH" ] || DEF_BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo HEAD)"
fi

echo "== DORA four-key PROXY report  ·  branch: ${DEF_BRANCH}  ·  window: ${SINCE_DAYS}d  ·  read-only =="
echo "   (proxies from git history — real DORA needs CI/CD + incident data)"
echo

WEEKS=$(( SINCE_DAYS / 7 )); [ "$WEEKS" -ge 1 ] || WEEKS=1

echo "== Deploy frequency (proxy) =="
TAG_COUNT="$(git tag --list "$TAG_GLOB" --sort=-creatordate \
  --format='%(creatordate:unix)' 2>/dev/null \
  | awk -v cutoff="$(( $(date +%s) - SINCE_DAYS*86400 ))" '$1>=cutoff' | wc -l | tr -d ' ')"
MERGE_COUNT="$(git log "$DEF_BRANCH" --merges --since="${SINCE_DAYS} days ago" \
  --pretty=oneline 2>/dev/null | wc -l | tr -d ' ')"
echo "  release tags ('${TAG_GLOB}') in window: ${TAG_COUNT}   (~$(( TAG_COUNT / WEEKS ))/wk)"
echo "  merges to ${DEF_BRANCH} in window:      ${MERGE_COUNT}   (~$(( MERGE_COUNT / WEEKS ))/wk)"
echo "  -> pick whichever maps to a real deploy in your pipeline."
echo

echo "== Lead time for changes (proxy: commit age across the window, days) =="
# Portable median: emit ages, `sort -n`, then index — no gawk-only asort().
AGES="$(git log "$DEF_BRANCH" --since="${SINCE_DAYS} days ago" --pretty='%at' 2>/dev/null \
  | awk -v now="$(date +%s)" '{ printf "%.4f\n", (now-$1)/86400 }' | sort -n)"
if [ -n "$AGES" ]; then
  printf '%s\n' "$AGES" | awk '
    { a[NR]=$1; sum+=$1 }
    END {
      n=NR;
      if (n%2) med=a[(n+1)/2]; else med=(a[n/2]+a[n/2+1])/2;
      printf "  commits: %d   mean age: %.1fd   p50 age: %.1fd\n", n, sum/n, med;
      print "  -> approximate; true lead time = first-commit -> prod-deploy from CI."
    }'
else
  echo "  no commits in window"
fi
echo

echo "== Change-fail rate (proxy: revert/hotfix/rollback share of subjects) =="
TOTAL="$(git log "$DEF_BRANCH" --since="${SINCE_DAYS} days ago" --pretty='%s' 2>/dev/null | wc -l | tr -d ' ')"
FAILY="$(git log "$DEF_BRANCH" --since="${SINCE_DAYS} days ago" --pretty='%s' 2>/dev/null \
  | grep -ciE '\b(revert|hotfix|rollback|roll back|emergency)\b' || true)"
if [ "${TOTAL:-0}" -gt 0 ]; then
  echo "  ${FAILY}/${TOTAL} commit subjects look corrective (~$(( FAILY * 100 / TOTAL ))%)"
else
  echo "  no commits in window"
fi
echo "  -> HEURISTIC only. Real change-fail rate joins deploys to incidents."
echo

echo "== Failed-deployment recovery time (MTTR) =="
echo "  git cannot compute this. Source it from your incident tracker"
echo "  (time from failed deploy / incident open -> restore)."
echo
echo "Goal: use these proxies to start the DORA baseline conversation, then wire the"
echo "authoritative numbers from CI/CD + incident data. Acting on them is a separate,"
echo "human-owned decision."
