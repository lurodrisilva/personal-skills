#!/usr/bin/env bash
# op-doctor.sh — READ-ONLY 1Password readiness snapshot for local Claude Code sessions.
#
# Answers "can this machine hand secrets to an agent without exposing them?":
#   1. 1Password CLI present + version          (op --version)
#   2. accounts known to the CLI + identity     (op account list, op whoami)
#   3. which auth mode is in effect             (desktop app / service account / Connect)
#   4. desktop app, Environments MCP binary     (path checks only)
#   5. Claude Code wiring                       (claude plugin list / claude mcp list)
#   6. SSH agent socket                         (path check only)
#
# It deliberately prints NO secret and NO token: token variables are reported as
# present/absent, never by value. It never runs `op signin`, `op read`, `op item get`,
# `op run`, `op inject`, and never creates, edits or deletes anything. With the desktop
# app integration on, `op whoami` reports "account is not signed in" until a command has
# been authorized in this terminal session, so when it fails and accounts are known the
# script falls back to `op vault list` as the probe; that call may raise one authorization
# prompt in the app. Vault names are printed only with --vaults.
#
# Review this script before running. Signing in, turning on the app integration,
# installing a plugin or registering an MCP server is a separate, deliberate action.
#
# Usage:
#   bash op-doctor.sh            # snapshot
#   bash op-doctor.sh --vaults   # also list vault names (may raise an authorization prompt)
# Exit: 0 ready · 2 op CLI missing · 4 no usable authentication
set -euo pipefail

WANT_VAULTS=0
[[ "${1:-}" == "--vaults" ]] && WANT_VAULTS=1

present() { if [[ -n "${!1:-}" ]]; then echo "set (value not shown)"; else echo "unset"; fi; }

echo "== 1Password CLI =="
if ! command -v op >/dev/null 2>&1; then
  echo "  op: NOT FOUND — install: https://www.1password.dev/cli/get-started" >&2
  exit 2
fi
echo "  path:    $(command -v op)"
echo "  version: $(op --version 2>/dev/null || echo unknown)"

echo
echo "== Authentication inputs (presence only) =="
for v in OP_SERVICE_ACCOUNT_TOKEN OP_CONNECT_HOST OP_CONNECT_TOKEN OP_ACCOUNT; do
  printf '  %-26s %s\n' "$v" "$(present "$v")"
done
if [[ -n "${OP_CONNECT_HOST:-}" && -n "${OP_CONNECT_TOKEN:-}" ]]; then
  MODE="connect-server (takes precedence over a service account)"
elif [[ -n "${OP_SERVICE_ACCOUNT_TOKEN:-}" ]]; then
  MODE="service-account"
else
  MODE="desktop-app integration or manual sign-in"
fi
echo "  effective mode:            ${MODE}"

echo
echo "== Accounts known to the CLI =="
ACCOUNTS="$(op account list 2>/dev/null || true)"
if [[ -n "${ACCOUNTS}" ]]; then echo "${ACCOUNTS}" | sed 's/^/  /'; else echo "  none"; fi

echo
echo "== Current identity (op whoami) =="
AUTH_OK=0
if WHO="$(op whoami 2>&1)"; then
  echo "${WHO}" | sed 's/^/  /'
  AUTH_OK=1
elif [[ -n "${ACCOUNTS}" ]] && op vault list --format json >/dev/null 2>&1; then
  echo "  op whoami: $(echo "${WHO}" | tail -1)"
  echo "  op vault list succeeded: desktop-app integration is authorizing this session"
  AUTH_OK=1
else
  echo "  not signed in: $(echo "${WHO}" | tail -1)"
fi

echo
echo "== Desktop app + agent surfaces =="
APP="not found"
for p in "/Applications/1Password.app" "${HOME}/Applications/1Password.app" "/opt/1Password/1password" "/usr/bin/1password"; do
  [[ -e "$p" ]] && { APP="$p"; break; }
done
echo "  desktop app:               ${APP}"
echo "  1password-mcp (Environments MCP server): $(command -v 1password-mcp 2>/dev/null || echo 'not on PATH')"
SOCK="not found"
for s in "${HOME}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock" "${HOME}/.1password/agent.sock"; do
  [[ -S "$s" ]] && { SOCK="$s"; break; }
done
echo "  SSH agent socket:          ${SOCK}"

echo
echo "== Claude Code wiring =="
if command -v claude >/dev/null 2>&1; then
  echo "  claude: $(claude --version 2>/dev/null | head -1)"
  if PLUG="$(claude plugin list 2>/dev/null | grep -i '1password' || true)" && [[ -n "${PLUG}" ]]; then
    echo "  plugin: ${PLUG}"
  else
    echo "  plugin: 1Password Developer Tools plugin not installed"
  fi
  if MCP="$(claude mcp list 2>/dev/null | grep -i '1password' || true)" && [[ -n "${MCP}" ]]; then
    echo "${MCP}" | sed 's/^/  mcp:    /'
  else
    echo "  mcp:    no 1Password MCP server registered"
  fi
else
  echo "  claude CLI not on PATH"
fi

if [[ "${WANT_VAULTS}" -eq 1 && "${AUTH_OK}" -eq 1 ]]; then
  echo
  echo "== Vaults readable by this identity =="
  op vault list 2>&1 | sed 's/^/  /' || true
fi

echo
if [[ "${AUTH_OK}" -ne 1 ]]; then
  echo "RESULT: op is installed but not authenticated."
  echo "  Local:      1Password app > Settings > Developer > 'Integrate with 1Password CLI', then run: op vault list"
  echo "  Automation: export OP_SERVICE_ACCOUNT_TOKEN from a secure source (never paste it into a chat)."
  exit 4
fi
echo "RESULT: ready. Use 'op run' / 'op inject' so values reach the process, not the conversation."
