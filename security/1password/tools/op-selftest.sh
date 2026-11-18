#!/usr/bin/env bash
# op-selftest.sh — offline self-test for op_guard.py + op_mcp_server.py. READ-ONLY outside a temp dir.
#
# Needs NO 1Password account and makes NO `op` call that touches a vault: it builds
# synthetic fixtures (fake, obviously-invalid credentials) in a `mktemp -d` directory,
# removes it on exit, and asserts that:
#   - the scanners flag the plaintext keys by NAME,
#   - a named pipe (the shape of a 1Password-mounted .env) is detected and not read,
#   - NO fixture value appears anywhere in CLI or MCP output,
#   - the MCP server completes initialize / tools/list / tools/call over stdio.
#
# Usage:  bash op-selftest.sh
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY="${PYTHON:-python3}"
command -v "${PY}" >/dev/null 2>&1 || { echo "python3 not found on PATH" >&2; exit 2; }

T="$(mktemp -d)"
trap 'rm -rf "${T}"' EXIT
FAIL=0
ok()  { echo "  ok   $1"; }
bad() { echo "  FAIL $1"; FAIL=1; }

# Synthetic, non-working values. Assembled at runtime so no credential-shaped literal lives in this file.
V_GH="ghp_$(printf 'A%.0s' {1..36})"
V_PW="correct-horse-battery-staple-000"
V_SK="sk-$(printf 'b%.0s' {1..40})"

{
  echo "# fixture"
  echo "APP_NAME=demo"
  echo "GITHUB_TOKEN=${V_GH}"
  echo "DB_PASSWORD=\"${V_PW}\""
  echo "API_KEY=op://dev/api/credential"
  echo "EMPTY_SECRET="
  echo "STRIPE_KEY=\${STRIPE_KEY}"
} > "${T}/.env"

cat > "${T}/.mcp.json" <<JSON
{"mcpServers":{
  "leaky":{"command":"npx","args":["-y","some-mcp"],"env":{"SOME_API_KEY":"${V_SK}","LOG_LEVEL":"error"}},
  "clean":{"command":"op","args":["run","--environment","abc","--","npx","-y","other-mcp"]}
}}
JSON
mkfifo "${T}/mounted.env"

echo "== op_guard.py scan-env =="
OUT="$("${PY}" "${HERE}/op_guard.py" scan-env "${T}/.env" || true)"
echo "${OUT}" | grep -q '"GITHUB_TOKEN"' && echo "${OUT}" | grep -q '"DB_PASSWORD"' && ok "plaintext keys named" || bad "plaintext keys not named"
echo "${OUT}" | grep -q '"plaintext_secret_count": 2' && ok "count is 2 (reference/placeholder/empty not flagged)" || bad "wrong plaintext count"
echo "${OUT}" | grep -qF -e "${V_GH}" -e "${V_PW}" && bad "a VALUE leaked into scan-env output" || ok "no value in output"

echo "== op_guard.py scan-env on a named pipe (1Password mount shape) =="
OUT="$("${PY}" "${HERE}/op_guard.py" scan-env "${T}/mounted.env" || true)"
echo "${OUT}" | grep -q '"mounted_by_1password": true' && ok "FIFO detected, not read" || bad "FIFO not detected"

echo "== op_guard.py scan-mcp =="
OUT="$("${PY}" "${HERE}/op_guard.py" scan-mcp "${T}/.mcp.json" || true)"
echo "${OUT}" | grep -q '"SOME_API_KEY"' && ok "plaintext env key named" || bad "plaintext env key not named"
echo "${OUT}" | grep -q '<ENVIRONMENT_ID>' && ok "op run rewrite suggested" || bad "no rewrite suggested"
echo "${OUT}" | grep -q '"wrapped_with_op_run": true' && ok "already-wrapped server recognised" || bad "wrapped server not recognised"
echo "${OUT}" | grep -qF "${V_SK}" && bad "a VALUE leaked into scan-mcp output" || ok "no value in output"

echo "== op_guard.py scan-tree =="
OUT="$("${PY}" "${HERE}/op_guard.py" scan-tree "${T}" || true)"
echo "${OUT}" | grep -q '"files_with_plaintext"' && ok "tree summary produced" || bad "no tree summary"
echo "${OUT}" | grep -qF -e "${V_GH}" -e "${V_PW}" -e "${V_SK}" && bad "a VALUE leaked into scan-tree output" || ok "no value in output"

echo "== op_mcp_server.py (stdio handshake) =="
REQ="$(printf '%s\n' \
  '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"selftest","version":"0"}}}' \
  '{"jsonrpc":"2.0","method":"notifications/initialized"}' \
  '{"jsonrpc":"2.0","id":2,"method":"tools/list"}' \
  "{\"jsonrpc\":\"2.0\",\"id\":3,\"method\":\"tools/call\",\"params\":{\"name\":\"op_scan_env_file\",\"arguments\":{\"path\":\"${T}/.env\"}}}" \
  "{\"jsonrpc\":\"2.0\",\"id\":4,\"method\":\"tools/call\",\"params\":{\"name\":\"op_scan_tree\",\"arguments\":{\"path\":\"/etc\"}}}" \
  '{"jsonrpc":"2.0","id":5,"method":"tools/call","params":{"name":"op_item_fields","arguments":{"item":"--reveal"}}}' \
  '{"jsonrpc":"2.0","id":6,"method":"tools/call","params":{"name":"op_status","arguments":{}}}')"
OUT="$(echo "${REQ}" | OP_GUARD_ROOT="${T}" "${PY}" "${HERE}/op_mcp_server.py")"
[[ "$(echo "${OUT}" | grep -c '"jsonrpc"')" -eq 6 ]] && ok "6 responses for 6 requests (notification unanswered)" || bad "wrong response count"
echo "${OUT}" | sed -n 1p | grep -q '"serverInfo"' && ok "initialize" || bad "initialize"
echo "${OUT}" | sed -n 2p | grep -q 'op_reference_check' && ok "tools/list" || bad "tools/list"
echo "${OUT}" | sed -n 3p | grep -q 'GITHUB_TOKEN' && ok "tools/call op_scan_env_file" || bad "tools/call op_scan_env_file"
echo "${OUT}" | sed -n 4p | grep -q 'outside OP_GUARD_ROOT' && ok "OP_GUARD_ROOT confines file tools" || bad "OP_GUARD_ROOT not enforced"
echo "${OUT}" | sed -n 5p | grep -q "does not start with '-'" && ok "flag-shaped argument rejected" || bad "flag injection not rejected"
echo "${OUT}" | sed -n 6p | grep -q 'auth_mode' && ok "tools/call op_status" || bad "tools/call op_status"
echo "${OUT}" | grep -qF -e "${V_GH}" -e "${V_PW}" -e "${V_SK}" && bad "a VALUE leaked into MCP output" || ok "no value in MCP output"

echo
if [[ "${FAIL}" -eq 0 ]]; then echo "SELFTEST PASSED"; else echo "SELFTEST FAILED"; exit 1; fi
