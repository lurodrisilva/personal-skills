#!/usr/bin/env bash
# cnab444-selftest.sh — offline regression suite for the cnab-444 toolkit.
# Read-only with respect to the repo: all output goes to a temp dir.
# Usage: ./cnab444-selftest.sh [extra .REM files to round-trip ...]
# Exit code = number of failed checks.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
PY=(python3 -I)
CLI=("${PY[@]}" "$HERE/cnab444.py")
MCP=("${PY[@]}" "$HERE/cnab444_mcp_server.py")
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
fail=0
ok()  { echo "  ✓ $1"; }
bad() { echo "  ✗ $1" >&2; fail=$((fail + 1)); }
check() { local name="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$name"; else bad "$name"; fi; }
refuse() { local name="$1"; shift; if "$@" >/dev/null 2>&1; then bad "$name (was accepted)"; else ok "$name"; fi; }

echo "==> layout"
check "layout tiles 1..444 for header/detail/trailer" "${PY[@]}" -c "import sys; sys.path.insert(0, sys.argv[1]); import cnab444" "$HERE"

echo "==> generate + validate synthetic example"
check "generate example" "${CLI[@]}" generate "$HERE/examples/remessa-duplicata.json" --outdir "$TMP"
REM="$TMP/CB15100001.REM"
check "example validates with zero errors" "${CLI[@]}" validate "$REM"
check "every record is 444 bytes + CRLF" bash -c "LC_ALL=C awk '{ if (length(\$0) != 445 || substr(\$0,445,1) != \"\r\") exit 1 }' '$REM'"
check "file is pure ASCII" bash -c "! LC_ALL=C grep -q '[^ -~[:cntrl:]]' '$REM'"
check "accents stripped + uppercased (COMERCIO)" grep -q "SACADO EXEMPLO COMERCIO S.A." "$REM"
check "trailer sequence = record count" bash -c "tail -1 '$REM' | cut -c439-444 | grep -qx 000004"
check "byte-identical to committed example" cmp "$REM" "$HERE/examples/CB15100001.REM"

echo "==> round-trip (inspect -> generate)"
roundtrip() {
  "${CLI[@]}" inspect "$1" > "$TMP/rt.json" && "${CLI[@]}" generate "$TMP/rt.json" --dry-run > "$TMP/rt.rem" 2>/dev/null && cmp -s "$TMP/rt.rem" "$1"
}
check "example round-trips byte-identically" roundtrip "$REM"
for extra in "$@"; do  # valid files must round-trip; invalid ones must be refused, never "repaired"
  if "${CLI[@]}" validate "$extra" >/dev/null 2>&1; then
    check "round-trip $(basename "$extra")" roundtrip "$extra"
  else
    refuse "invalid $(basename "$extra") is not regenerated" roundtrip "$extra"
  fi
done

echo "==> generator refusals"
mutate() { # $1 = python expression applied to spec dict `s`
  "${PY[@]}" -c "import json,sys; s=json.load(open(sys.argv[1])); $1; json.dump(s,sys.stdout)" "$HERE/examples/remessa-duplicata.json" > "$TMP/bad.json"
  "${CLI[@]}" generate "$TMP/bad.json" --dry-run
}
refuse "negative money"            mutate "s['titulos'][0]['valor_presente']='-10.00'"
refuse "3 decimal places"          mutate "s['titulos'][0]['valor_face']='1.005'"
refuse "alfa overflow (no silent truncation)" mutate "s['titulos'][0]['nome_sacado']='X'*41"
refuse "numeric overflow"          mutate "s['titulos'][0]['cep_sacado']='123456789'"
refuse "missing required field"    mutate "del s['titulos'][0]['seu_numero']"
refuse "forbidden char @"          mutate "s['titulos'][0]['endereco_sacado']='RUA @ 1'"
refuse "invalid date"              mutate "s['titulos'][0]['vencimento']='2026-02-30'"
refuse "unknown field"             mutate "s['titulos'][0]['foo']='bar'"
refuse "duplicata without chave NF-e" mutate "s['titulos'][0]['chave_nfe']=''"
refuse "liquidation without data_liquidacao" mutate "s['titulos'][0]['ocorrencia']='14'"
refuse "prorrogacao with seu_numero != numero_documento" mutate "s['titulos'][0]['ocorrencia']='20'"

echo "==> validator catches corruption"
corrupt() { # replace bytes at 1-based column $1 on line 2 with $2
  LC_ALL=C awk -v c="$1" -v r="$2" 'NR==2{ $0 = substr($0,1,c-1) r substr($0,c+length(r)) } {print}' "$REM" > "$TMP/c.rem"
  "${CLI[@]}" validate "$TMP/c.rem"
}
refuse "minus sign inside valor_presente (193-205)" corrupt 193 "000000-202897"
refuse "bad sequence number"   corrupt 439 "000009"
refuse "bad coobrigação domain (21-22)" corrupt 21 "07"
LC_ALL=C sed $'2s/.\r$/\r/' "$REM" > "$TMP/short.rem"
LC_ALL=C sed $'2s/\r$//' "$REM" > "$TMP/mixed.rem"
refuse "mixed CRLF/LF line endings" "${CLI[@]}" validate "$TMP/mixed.rem"
refuse "short record" "${CLI[@]}" validate "$TMP/short.rem"

echo "==> filename"
check "observed style CB15104321.REM" test "$("${CLI[@]}" filename --date 2026-10-15 --seq 1004321)" = CB15104321.REM
check "manual style CB230501.REM"     test "$("${CLI[@]}" filename --date 230526 --suffix 01 --style manual)" = CB230501.REM

echo "==> MCP stdio server"
mcp_out="$(printf '%s\n' \
  '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"t","version":"0"}}}' \
  '{"jsonrpc":"2.0","method":"notifications/initialized"}' \
  '{"jsonrpc":"2.0","id":2,"method":"tools/list"}' \
  "{\"jsonrpc\":\"2.0\",\"id\":3,\"method\":\"tools/call\",\"params\":{\"name\":\"cnab444_validate\",\"arguments\":{\"path\":\"$REM\"}}}" \
  '{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"cnab444_generate","arguments":{"spec":{"header":{},"titulos":[]}}}}' \
  | "${MCP[@]}")"
check "4 responses (notification gets none)" test "$(printf '%s\n' "$mcp_out" | wc -l | tr -d ' ')" -eq 4
check "every stdout line is JSON-RPC" "${PY[@]}" -c "import json,sys; [json.loads(l)['jsonrpc'] for l in sys.argv[1].splitlines()]" "$mcp_out"
check "tools/list exposes 6 tools" "${PY[@]}" -c "import json,sys; r=[json.loads(l) for l in sys.argv[1].splitlines()]; assert len(r[1]['result']['tools'])==6" "$mcp_out"
check "validate tool returns ok" "${PY[@]}" -c "import json,sys; r=[json.loads(l) for l in sys.argv[1].splitlines()]; assert json.loads(r[2]['result']['content'][0]['text'])['ok']" "$mcp_out"
check "bad spec -> isError, not a crash" "${PY[@]}" -c "import json,sys; r=[json.loads(l) for l in sys.argv[1].splitlines()]; assert r[3]['result']['isError']" "$mcp_out"

echo "==> MCP path hardening"
mcp_call() { # $1 = tool name, $2 = arguments JSON; prints the tool result line
  printf '%s\n' "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/call\",\"params\":{\"name\":\"$1\",\"arguments\":$2}}" | "${MCP[@]}"
}
is_error() { "${PY[@]}" -c "import json,sys; assert json.loads(sys.stdin.read())['result'].get('isError')"; }
echo secret > "$TMP/notes.env"
refuse_err() { local name="$1"; shift; if "$@" | is_error; then ok "$name"; else bad "$name (was accepted)"; fi; }
refuse_err "inspect refuses non-.REM path" mcp_call cnab444_inspect "{\"path\":\"$TMP/notes.env\"}"
refuse_err "inspect refuses a directory"   mcp_call cnab444_inspect "{\"path\":\"$TMP/dir.REM\"}"
ln -s "$TMP/target-missing" "$TMP/out/CB15100001.REM" 2>/dev/null || { mkdir -p "$TMP/out"; ln -s "$TMP/target-missing" "$TMP/out/CB15100001.REM"; }
SPEC="$("${PY[@]}" -c "import json,sys; print(json.dumps(json.load(open(sys.argv[1]))))" "$HERE/examples/remessa-duplicata.json")"
refuse_err "generate refuses dangling-symlink target" mcp_call cnab444_generate "{\"spec\":$SPEC,\"output_dir\":\"$TMP/out\"}"
check "dangling symlink target was not created" test ! -e "$TMP/target-missing"

echo ""
if [ "$fail" -eq 0 ]; then echo "ALL SELFTESTS PASSED"; else echo "FAILED: $fail check(s)"; fi
exit "$fail"
