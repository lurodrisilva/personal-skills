#!/usr/bin/env bash
# supermemory-config-audit.sh — READ-ONLY audit of a project's Supermemory wiring.
#
# Answers "how is THIS repo wired to Supermemory?" using only local file reads:
# SDK dependencies, tools-package version, env-var usage, hardcoded keys
# (warned, never printed), MCP config entries, and local self-hosted state.
# It NEVER edits files, installs packages, or calls any network endpoint.
#
# Usage:
#   bash supermemory-config-audit.sh              # audit current directory
#   bash supermemory-config-audit.sh /path/repo   # audit another project
set -euo pipefail

ROOT="${1:-.}"
warn=0

say()  { printf '%s\n' "$*"; }
ok()   { say "  [ok]   $*"; }
info() { say "  [info] $*"; }
bad()  { say "  [WARN] $*"; warn=$((warn + 1)); }

say "== Supermemory project config audit (read-only) =="
say "Project root: $ROOT"
say ""

say "-- SDK dependencies --"
found_dep=0
for pj in "$ROOT/package.json" "$ROOT"/*/package.json; do
  [[ -f "$pj" ]] || continue
  if grep -q '"supermemory"' "$pj" 2>/dev/null; then
    found_dep=1
    ok "TS SDK 'supermemory' in ${pj#"$ROOT"/}: $(grep -o '"supermemory"[^,}]*' "$pj" | head -1)"
  fi
  if grep -q '"@supermemory/tools"' "$pj" 2>/dev/null; then
    found_dep=1
    ver=$(grep -o '"@supermemory/tools"[^,}]*' "$pj" | head -1)
    ok "'@supermemory/tools' in ${pj#"$ROOT"/}: $ver"
    printf '%s' "$ver" | grep -qE '[\^~]?2\.' \
      || bad "@supermemory/tools not pinned to v2 — v2.0.0 changed signatures (config object, required customId, addMemory default)"
  fi
done
for py in "$ROOT/requirements.txt" "$ROOT/pyproject.toml"; do
  [[ -f "$py" ]] || continue
  if grep -qE '(^|["'"'"' ])supermemory([=<>~ "'"'"']|$)' "$py" 2>/dev/null; then
    found_dep=1
    ok "Python SDK 'supermemory' referenced in ${py#"$ROOT"/}"
  fi
  grep -q 'supermemory-openai-sdk' "$py" 2>/dev/null && { found_dep=1; ok "'supermemory-openai-sdk' in ${py#"$ROOT"/}"; }
  grep -q 'supermemory-agent-framework' "$py" 2>/dev/null && { found_dep=1; ok "'supermemory-agent-framework' in ${py#"$ROOT"/}"; }
done
(( found_dep )) || info "no Supermemory SDK dependency found (API/MCP-only project, or wrong root?)"

say ""
say "-- Env-var wiring vs hardcoded keys --"
if grep -rn --include='*.ts' --include='*.tsx' --include='*.js' --include='*.mjs' --include='*.py' \
     -l -E 'SUPERMEMORY_(API_KEY|BASE_URL|CC_API_KEY)' "$ROOT" 2>/dev/null | head -5 | grep -q .; then
  ok "code reads SUPERMEMORY_* env vars"
else
  info "no SUPERMEMORY_* env-var reference found in code"
fi
# Key-shaped literals: sm_ + long token, in tracked source (never print the match itself).
keyhits=$(grep -rn --include='*.ts' --include='*.tsx' --include='*.js' --include='*.mjs' \
            --include='*.py' --include='*.json' --include='*.yaml' --include='*.yml' \
            --exclude-dir=node_modules --exclude-dir=.git \
            -lE '["'"'"']sm_[A-Za-z0-9_-]{16,}["'"'"']' "$ROOT" 2>/dev/null || true)
if [[ -n "$keyhits" ]]; then
  bad "possible hardcoded sm_ key(s) in:"
  printf '%s\n' "$keyhits" | sed 's/^/         /'
else
  ok "no hardcoded sm_ key literals detected"
fi
[[ -f "$ROOT/.env" ]] && ! grep -q '^\.env$' "$ROOT/.gitignore" 2>/dev/null \
  && bad ".env exists but is not listed in .gitignore"

say ""
say "-- MCP configuration --"
found_mcp=0
for cfg in "$ROOT/.mcp.json" "$ROOT/.cursor/mcp.json" "$HOME/.cursor/mcp.json"; do
  [[ -f "$cfg" ]] || continue
  if grep -q 'mcp\.supermemory\.ai' "$cfg" 2>/dev/null; then
    found_mcp=1; ok "Memory MCP (mcp.supermemory.ai) configured in $cfg"
  fi
  if grep -q 'supermemory\.ai/docs/mcp' "$cfg" 2>/dev/null; then
    found_mcp=1; ok "Docs MCP (supermemory.ai/docs/mcp) configured in $cfg"
  fi
done
(( found_mcp )) || info "no Supermemory MCP entries found (.mcp.json / .cursor/mcp.json)"
[[ -d "$ROOT/.claude/.supermemory-claude" || -d "$HOME/.supermemory-claude" ]] \
  && ok "claude-supermemory plugin config present"

say ""
say "-- Self-hosted state --"
if [[ -d "$ROOT/.supermemory" ]]; then
  ok "local instance data dir ./.supermemory present ($(du -sh "$ROOT/.supermemory" 2>/dev/null | cut -f1 || echo '?'))"
  info "SDK clients must set baseURL (default http://localhost:6767) to use it"
else
  info "no ./.supermemory dir (cloud-only project, or instance lives elsewhere)"
fi

say ""
if (( warn > 0 )); then
  say "RESULT: $warn warning(s). Every fix (rotating keys, pinning versions, editing configs) is a separate, human-approved action."
else
  say "RESULT: no warnings."
fi
exit 0
