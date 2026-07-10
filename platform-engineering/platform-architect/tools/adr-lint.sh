#!/usr/bin/env bash
# adr-lint.sh — READ-ONLY linter for an ADR / RFC directory (MADR shape).
#
# Walks a directory of Architecture Decision Records and checks each file for the
# structural conventions the platform-architect skill expects (MADR-style):
#   - a filename that starts with a 3-4 digit number (NNNN-title.md)
#   - a top-level "# ADR-NNNN: ..." or "# NNNN. ..." title line
#   - a "Status:" field with a recognised value (Proposed/Accepted/Deprecated/Superseded)
#   - a "## Context" (or "Context and problem statement") section
#   - a "## Decision" (or "Decision outcome") section
#   - a "## Consequences" section
# It also flags duplicate ADR numbers and any "Superseded by" that points nowhere.
#
# This ONLY reads files (find/grep/awk on Markdown). It NEVER creates, edits,
# renames, moves, or deletes anything. Fixing a flagged record is a separate,
# human-owned edit.
#
# Review this script before running.
#
# Usage:
#   ADR_DIR=docs/adr bash adr-lint.sh
#   bash adr-lint.sh            # defaults to docs/adr, then adr/
set -euo pipefail

ADR_DIR="${ADR_DIR:-}"
if [ -z "$ADR_DIR" ]; then
  for d in docs/adr adr docs/decisions docs/rfc; do
    [ -d "$d" ] && { ADR_DIR="$d"; break; }
  done
fi
[ -n "$ADR_DIR" ] && [ -d "$ADR_DIR" ] || {
  echo "no ADR directory found (tried docs/adr, adr, docs/decisions, docs/rfc)." >&2
  echo "set ADR_DIR=<path> explicitly." >&2; exit 2; }

echo "== ADR / RFC lint  ·  dir: ${ADR_DIR}  ·  read-only (MADR shape) =="
echo

FILES="$(find "$ADR_DIR" -type f -name '*.md' 2>/dev/null | sort)"
[ -n "$FILES" ] || { echo "no *.md records in ${ADR_DIR}"; exit 0; }

WARN=0
NUMS_SEEN=""
while IFS= read -r f; do
  base="$(basename "$f")"
  issues=""

  echo "$base" | grep -qE '^[0-9]{3,4}[-_.]' \
    || issues="${issues}\n    - filename should start with a NNNN number (MADR: NNNN-title.md)"

  grep -qiE '^#[[:space:]]+(ADR[- ]?[0-9]+|[0-9]{3,4}[.)])' "$f" \
    || issues="${issues}\n    - missing a '# ADR-NNNN: ...' (or '# NNNN. ...') title line"

  if grep -qiE '^[-*]?[[:space:]]*status[[:space:]]*:' "$f"; then
    grep -qiE 'status[[:space:]]*:[[:space:]]*(proposed|accepted|deprecated|superseded|rejected)' "$f" \
      || issues="${issues}\n    - Status: present but not a known value (Proposed/Accepted/Deprecated/Superseded/Rejected)"
  else
    issues="${issues}\n    - missing a 'Status:' field"
  fi

  grep -qiE '^#+[[:space:]]*context' "$f" \
    || issues="${issues}\n    - missing a '## Context' section"
  grep -qiE '^#+[[:space:]]*decision' "$f" \
    || issues="${issues}\n    - missing a '## Decision' (outcome) section"
  grep -qiE '^#+[[:space:]]*consequence' "$f" \
    || issues="${issues}\n    - missing a '## Consequences' section"

  # Duplicate-number detection from the filename prefix.
  num="$(echo "$base" | grep -oE '^[0-9]{3,4}' || true)"
  if [ -n "$num" ]; then
    case " $NUMS_SEEN " in
      *" $num "*) issues="${issues}\n    - DUPLICATE ADR number ${num} (already used by another file)";;
    esac
    NUMS_SEEN="$NUMS_SEEN $num"
  fi

  # Superseded-by should reference an existing record number.
  if grep -qiE 'superseded[[:space:]]+by' "$f"; then
    ref="$(grep -ioE 'superseded[[:space:]]+by[[:space:]]+(ADR[- ]?)?[0-9]{3,4}' "$f" | grep -oE '[0-9]{3,4}' | head -1 || true)"
    if [ -n "$ref" ] && ! find "$ADR_DIR" -type f -name "${ref}*" 2>/dev/null | grep -q .; then
      issues="${issues}\n    - 'Superseded by' points to ${ref}, which has no matching record"
    fi
  fi

  if [ -n "$issues" ]; then
    printf '  [WARN] %s%b\n' "$base" "$issues"
    WARN=$((WARN+1))
  else
    printf '  [ok]   %s\n' "$base"
  fi
done <<< "$FILES"

echo
echo "== ${WARN} record(s) flagged =="
echo "Goal: flagged records are a starting point — fixing/authoring an ADR is a"
echo "separate, human-owned edit. This linter never modifies files."
