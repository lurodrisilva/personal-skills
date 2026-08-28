#!/usr/bin/env bash
# hermes-env-audit.sh — READ-ONLY Hermes Agent installation & config-split audit.
#
# Answers "is Hermes installed correctly, and is the config split intact?" using
# only file reads and `hermes --version`. It NEVER installs, edits config, writes
# .env, or starts any process.
#
# Checks: binary + version, the ~/.hermes directory contract (code dir, state.db,
# config.yaml, .env), .env permissions (must be 600), and the config-split
# invariant — key-shaped values (API keys / tokens / secrets) do NOT belong in
# config.yaml, only in ~/.hermes/.env.
#
# Review this script before running. Fixing anything it reports is a separate,
# human-approved change (`hermes config set`, chmod, re-install).
#
# Usage:
#   bash hermes-env-audit.sh
#   HERMES_HOME=~/.hermes/profiles/research bash hermes-env-audit.sh
set -euo pipefail

HOME_DIR="${HERMES_HOME:-$HOME/.hermes}"
warn=0

say()  { printf '%s\n' "$*"; }
ok()   { say "  [ok]   $*"; }
bad()  { say "  [WARN] $*"; warn=$((warn + 1)); }

say "== Hermes Agent environment audit (read-only) =="
say "Hermes home: $HOME_DIR"
say ""

say "-- Binary --"
if command -v hermes >/dev/null 2>&1; then
  ok "hermes on PATH: $(command -v hermes)"
  ok "version: $(hermes --version 2>/dev/null || echo 'unknown (hermes --version failed)')"
else
  bad "hermes not on PATH (expected symlink at ~/.local/bin/hermes; install via the official install.sh — pip/brew/AUR are unsupported)"
fi

say ""
say "-- Directory contract --"
[[ -d "$HOME_DIR" ]] && ok "data home exists" || bad "data home missing: $HOME_DIR"
[[ -d "$HOME_DIR/hermes-agent" || -d "$HOME/.hermes/hermes-agent" ]] \
  && ok "code dir present (hermes-agent/)" \
  || bad "code dir not found (expected ~/.hermes/hermes-agent/)"
[[ -f "$HOME_DIR/config.yaml" ]] && ok "config.yaml present" || bad "config.yaml missing"
[[ -f "$HOME_DIR/state.db"    ]] && ok "state.db present (SQLite sessions)" || say "  [info] state.db absent (no sessions yet)"
[[ -d "$HOME_DIR/skills"      ]] && ok "skills/ present" || say "  [info] skills/ absent"

say ""
say "-- Secrets file --"
if [[ -f "$HOME_DIR/.env" ]]; then
  perms=$(stat -f '%Lp' "$HOME_DIR/.env" 2>/dev/null || stat -c '%a' "$HOME_DIR/.env" 2>/dev/null || echo '?')
  if [[ "$perms" == "600" ]]; then
    ok ".env permissions are 600"
  else
    bad ".env permissions are $perms — expected 600 (chmod 600 is a separate manual step)"
  fi
else
  say "  [info] .env absent (no local secrets; may be fine with a secrets source or OAuth)"
fi

say ""
say "-- Config-split invariant (no secrets in config.yaml) --"
if [[ -f "$HOME_DIR/config.yaml" ]]; then
  # Key-shaped values: assignments whose key names look credential-like.
  hits=$(grep -inE '^[^#]*(api_key|_token|_secret|password)[[:space:]]*:[[:space:]]*["'"'"']?[A-Za-z0-9_\-]{12,}' \
          "$HOME_DIR/config.yaml" | grep -viE ':[[:space:]]*(""|'"''"'|null|true|false|~)[[:space:]]*$' || true)
  if [[ -n "$hits" ]]; then
    bad "possible secret material inside config.yaml (secrets belong in .env):"
    printf '%s\n' "$hits" | sed 's/^/         /'
  else
    ok "no key-shaped values detected in config.yaml"
  fi
fi

say ""
if (( warn > 0 )); then
  say "RESULT: $warn warning(s). Every fix is a separate, human-approved action."
else
  say "RESULT: all checks passed."
fi
exit 0
