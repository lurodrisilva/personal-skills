#!/usr/bin/env bash
# op-ssh-audit.sh — READ-ONLY audit of the 1Password SSH agent + Git commit-signing wiring.
#
# Reports:
#   1. 1Password SSH agent socket               (path check)
#   2. ~/.ssh/config IdentityAgent / SSH_AUTH_SOCK routing
#   3. ~/.config/1Password/ssh/agent.toml       (which vaults/items the agent may offer)
#   4. keys the agent currently offers          (ssh-add -l → fingerprints + comments only)
#   5. private keys still on disk in ~/.ssh     (file NAMES only, never contents)
#   6. Git signing config                       (gpg.format, user.signingkey, gpg.ssh.program…)
#
# It prints PUBLIC material only (fingerprints, public-key config values, file names).
# It never opens a private key, never runs ssh-add with a key file, never edits
# ~/.ssh/config, agent.toml or git config, and never connects to a remote host.
# `ssh-add -l` against the 1Password agent lists public keys and may ask 1Password to unlock.
#
# Review this script before running. Any change to SSH or Git config is a separate,
# deliberate action.
#
# Usage:  bash op-ssh-audit.sh
set -euo pipefail

MAC_SOCK="${HOME}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
LINUX_SOCK="${HOME}/.1password/agent.sock"
SSH_CONFIG="${HOME}/.ssh/config"
AGENT_TOML="${HOME}/.config/1Password/ssh/agent.toml"

echo "== 1Password SSH agent socket =="
SOCK=""
for s in "${MAC_SOCK}" "${LINUX_SOCK}"; do [[ -S "$s" ]] && { SOCK="$s"; break; }; done
if [[ -n "${SOCK}" ]]; then
  echo "  found: ${SOCK}"
else
  echo "  not found — turn it on: 1Password app > Settings > Developer > 'Use the SSH Agent'"
fi

echo
echo "== Client routing =="
if [[ -f "${SSH_CONFIG}" ]]; then
  if grep -inE '^\s*IdentityAgent' "${SSH_CONFIG}" | sed 's/^/  ssh config: /'; then :; else
    echo "  ssh config: no IdentityAgent line in ${SSH_CONFIG}"
  fi
  if grep -iqE '^\s*IdentityFile' "${SSH_CONFIG}"; then
    echo "  ssh config: $(grep -icE '^\s*IdentityFile' "${SSH_CONFIG}") IdentityFile line(s) — these still point at keys on disk"
  fi
else
  echo "  ssh config: ${SSH_CONFIG} does not exist"
fi
if [[ -n "${SSH_AUTH_SOCK:-}" ]]; then
  case "${SSH_AUTH_SOCK}" in
    *1password*|*1Password*) echo "  SSH_AUTH_SOCK: points at the 1Password agent" ;;
    *) echo "  SSH_AUTH_SOCK: set, NOT the 1Password agent (${SSH_AUTH_SOCK})" ;;
  esac
else
  echo "  SSH_AUTH_SOCK: unset"
fi

echo
echo "== SSH agent config file (agent.toml) =="
if [[ -f "${AGENT_TOML}" ]]; then
  echo "  ${AGENT_TOML}:"
  grep -vE '^\s*(#|$)' "${AGENT_TOML}" | sed 's/^/    /'
else
  echo "  none — default behaviour: every SSH key in the Personal/Private/Employee vault is offered"
fi

echo
echo "== Keys offered by the 1Password agent (fingerprints) =="
if [[ -n "${SOCK}" ]] && command -v ssh-add >/dev/null 2>&1; then
  if OUT="$(SSH_AUTH_SOCK="${SOCK}" ssh-add -l 2>&1)"; then
    echo "${OUT}" | sed 's/^/  /'
    N="$(echo "${OUT}" | grep -c . || true)"
    [[ "${N}" -gt 6 ]] && echo "  WARNING: ${N} keys — servers reject after ~6 attempts; pin keys per host (agent.toml order or IdentityFile <pubkey>)"
  else
    echo "  ${OUT}"
  fi
else
  echo "  skipped (no socket or no ssh-add)"
fi

echo
echo "== Private keys still on disk in ~/.ssh (names only) =="
FOUND=0
if [[ -d "${HOME}/.ssh" ]]; then
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    if head -c 40 "$f" 2>/dev/null | grep -q 'PRIVATE KEY'; then
      echo "  $(basename "$f")"
      FOUND=1
    fi
  done < <(find "${HOME}/.ssh" -maxdepth 1 -type f ! -name '*.pub' ! -name 'known_hosts*' ! -name 'config' ! -name 'authorized_keys' ! -name 'allowed_signers' 2>/dev/null)
fi
[[ "${FOUND}" -eq 0 ]] && echo "  none"
[[ "${FOUND}" -eq 1 ]] && echo "  → import each into 1Password (New Item > SSH Key > Import), verify, then delete the file"

echo
echo "== Git commit signing =="
if command -v git >/dev/null 2>&1; then
  for k in gpg.format user.signingkey commit.gpgsign tag.gpgsign gpg.ssh.program gpg.ssh.allowedSignersFile; do
    V="$(git config --global --get "$k" 2>/dev/null || true)"
    if [[ "$k" == "user.signingkey" && -n "${V}" ]]; then
      case "${V}" in
        ssh-*|ecdsa-*|sk-*) V="$(echo "${V}" | awk '{print $1" "substr($2,1,16)"…"}') (public key)" ;;
        *) V="set (${#V} chars; not an inline SSH public key)" ;;
      esac
    fi
    printf '  %-28s %s\n' "$k" "${V:-unset}"
  done
  FMT="$(git config --global --get gpg.format 2>/dev/null || true)"
  PROG="$(git config --global --get gpg.ssh.program 2>/dev/null || true)"
  if [[ "${FMT}" == "ssh" && "${PROG}" == *op-ssh-sign* ]]; then
    echo "  → signing goes through 1Password (op-ssh-sign)"
  else
    echo "  → not wired to 1Password: in the app open the SSH key item > ⋮ > 'Configure Commit Signing'"
  fi
else
  echo "  git not on PATH"
fi
