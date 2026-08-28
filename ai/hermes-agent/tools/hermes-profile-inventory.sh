#!/usr/bin/env bash
# hermes-profile-inventory.sh — READ-ONLY inventory of a Hermes Agent home.
#
# Answers "what exists in this Hermes install?": profiles, skills, cron jobs,
# MCP servers, plugins, and memory-file sizes vs their documented caps
# (MEMORY.md 2,200 chars / USER.md 1,375 chars). Uses only file reads —
# it NEVER creates, edits, enables, schedules, or deletes anything.
#
# Usage:
#   bash hermes-profile-inventory.sh
#   HERMES_HOME=~/.hermes/profiles/research bash hermes-profile-inventory.sh
set -euo pipefail

HOME_DIR="${HERMES_HOME:-$HOME/.hermes}"

say() { printf '%s\n' "$*"; }

say "== Hermes Agent inventory (read-only) =="
say "Hermes home: $HOME_DIR"
say ""

say "-- Profiles --"
if [[ -d "$HOME_DIR/profiles" ]]; then
  found=0
  for p in "$HOME_DIR"/profiles/*/; do
    [[ -d "$p" ]] || continue
    found=1
    say "  $(basename "$p")  (skills: $(find "$p/skills" -name SKILL.md 2>/dev/null | wc -l | tr -d ' '))"
  done
  (( found )) || say "  (none)"
else
  say "  (default profile only — no profiles/ dir)"
fi

say ""
say "-- Skills --"
if [[ -d "$HOME_DIR/skills" ]]; then
  say "  SKILL.md files: $(find "$HOME_DIR/skills" -name SKILL.md 2>/dev/null | wc -l | tr -d ' ')"
  [[ -d "$HOME_DIR/skills/.archive" ]] && \
    say "  archived (curator): $(find "$HOME_DIR/skills/.archive" -name SKILL.md 2>/dev/null | wc -l | tr -d ' ')"
else
  say "  (no skills dir)"
fi

say ""
say "-- Cron jobs (~/.hermes/cron/jobs.json) --"
jobs="$HOME_DIR/cron/jobs.json"
if [[ -f "$jobs" ]]; then
  if command -v jq >/dev/null 2>&1; then
    jq -r '(.jobs? // .) | if type == "array" then .[] else empty end
           | "  [\(.state // "?")] \(.name // .id): \(.schedule.display // .schedule.expr // "?") -> \(.deliver // "origin")"' \
      "$jobs" 2>/dev/null || say "  (jobs.json present but not in a recognized shape)"
  else
    say "  present ($(wc -c < "$jobs" | tr -d ' ') bytes) — install jq for a per-job listing"
  fi
else
  say "  (no cron jobs)"
fi

say ""
say "-- MCP servers (config.yaml mcp_servers:) --"
cfg="$HOME_DIR/config.yaml"
if [[ -f "$cfg" ]] && grep -q '^mcp_servers:' "$cfg"; then
  # Top-level server names are indented exactly one level under mcp_servers.
  awk '/^mcp_servers:/{f=1; next} f && /^[^[:space:]]/{f=0} f && /^  [A-Za-z0-9._-]+:/{gsub(/[: ]/,"",$1); print "  " $1}' "$cfg"
else
  say "  (none configured)"
fi

say ""
say "-- Plugins --"
if [[ -d "$HOME_DIR/plugins" ]]; then
  for d in "$HOME_DIR"/plugins/*/; do
    [[ -d "$d" ]] || continue
    say "  $(basename "$d")"
  done
else
  say "  (no user plugins dir)"
fi
if [[ -f "$cfg" ]] && grep -q '^plugins:' "$cfg"; then
  say "  (see 'plugins:' block in config.yaml for enabled/disabled state)"
fi

say ""
say "-- Memory files vs caps --"
for f in MEMORY.md USER.md; do
  path="$HOME_DIR/memories/$f"
  cap=2200; [[ "$f" == "USER.md" ]] && cap=1375
  if [[ -f "$path" ]]; then
    n=$(wc -c < "$path" | tr -d ' ')
    say "  $f: ${n} chars (cap ~${cap})"
  else
    say "  $f: absent"
  fi
done

say ""
say "Done. Inventory only — changing any of the above is a separate, human-approved action."
exit 0
