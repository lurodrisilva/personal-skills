#!/usr/bin/env python3
"""op_mcp_server.py — dependency-free MCP stdio server: value-free 1Password metadata for agents.

Purpose: let a coding agent DISCOVER what exists in 1Password (vaults, items, field
labels, secret references, Environment secret names) and AUDIT local files for plaintext
credentials — without a secret value ever entering the model context. To USE a secret,
the agent runs the real command under `op run` / `op inject`; this server has no tool
that returns, reveals, writes or runs anything with a value.

READ-ONLY: it never signs in, never creates/edits/deletes anything in 1Password and
never writes a file. It complements — does not replace — the official 1Password
Environments MCP server (`1password-mcp`, shipped with the desktop app), which is the
one that CREATES Environments and mounts local `.env` files.

Transport: newline-delimited JSON-RPC 2.0 on stdin/stdout (MCP stdio).
stdout carries protocol messages only; diagnostics go to stderr.

Register (user scope = every local Claude Code session):
  claude mcp add --scope user 1password-guard -- python3 /abs/path/security/1password/tools/op_mcp_server.py

Optional: OP_GUARD_ROOT=/abs/dir restricts the file-scanning tools to that tree.

Tools
  op_status             CLI/app/auth posture (presence booleans, never a token)
  op_vault_list         vault ids + names
  op_item_list          item ids/titles/categories (no usernames, no values)
  op_item_fields        field labels/types + `op://` references of one item (no values)
  op_reference_check    does each `op://` reference resolve? (value discarded)
  op_environment_names  secret NAMES of a 1Password Environment (never `--reveal`)
  op_scan_env_file      classify the keys of a dotenv file (names only; skips 1Password mounts)
  op_scan_mcp_config    plaintext credentials in an MCP config + the `op run` rewrite
  op_scan_tree          walk a project for both of the above
"""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import op_guard as G  # noqa: E402

PROTOCOL_VERSION = "2025-06-18"
SUPPORTED_PROTOCOL_VERSIONS = {"2024-11-05", "2025-03-26", "2025-06-18"}
SERVER_INFO = {"name": "1password-guard", "version": "1.0.0"}
INSTRUCTIONS = (
    "Value-free 1Password metadata. Nothing here returns a secret value. To use a secret, "
    "run the command under `op run --environment <ID> -- <cmd>` or `op run --env-file <file> -- <cmd>` "
    "so the value goes to the subprocess, not to the conversation. Never ask the user to paste a secret."
)

_STR = {"type": "string"}
_RO = {"readOnlyHint": True, "destructiveHint": False, "idempotentHint": True}
TOOLS = [
    {"name": "op_status",
     "description": "1Password posture on this machine: CLI path/version, signed-in accounts, auth mode "
                    "(desktop app / service account / Connect), whether the desktop app, the Environments MCP "
                    "binary and the SSH agent socket exist. Tokens are reported as present/absent only.",
     "inputSchema": {"type": "object", "properties": {}}},
    {"name": "op_vault_list",
     "description": "List the vaults the current identity can read (id, name). May raise a 1Password authorization prompt.",
     "inputSchema": {"type": "object", "properties": {}}},
    {"name": "op_item_list",
     "description": "List items (id, title, category, vault, tags, updated_at). No usernames, no field values.",
     "inputSchema": {"type": "object", "properties": {
         "vault": {**_STR, "description": "vault name or id; required when a service account sees several vaults"},
         "categories": {**_STR, "description": "comma-separated, e.g. `API Credential,Login,SSH Key`"},
         "tags": {**_STR, "description": "comma-separated tags"}}}},
    {"name": "op_item_fields",
     "description": "Field map of one item: label, type, section and the `op://vault/item/field` secret reference "
                    "of every field. Values are never returned — put the reference in config and resolve it with `op run`.",
     "inputSchema": {"type": "object", "required": ["item"], "properties": {
         "item": {**_STR, "description": "item name, id or share link"}, "vault": _STR}}},
    {"name": "op_reference_check",
     "description": "Check that `op://` secret references resolve for the current identity. Returns resolves true/false "
                    "and op's error text. The resolved value is discarded and never returned.",
     "inputSchema": {"type": "object", "required": ["references"], "properties": {
         "references": {"type": "array", "items": _STR, "minItems": 1, "maxItems": 50}}}},
    {"name": "op_environment_names",
     "description": "Names of the secrets stored in a 1Password Environment (by name or id). Values are never requested "
                    "with --reveal and never returned.",
     "inputSchema": {"type": "object", "required": ["environment"], "properties": {"environment": _STR}}},
    {"name": "op_scan_env_file",
     "description": "Classify every key of a dotenv file as secret-reference / plaintext-secret / placeholder / plain / "
                    "empty. Returns key names only. A 1Password-mounted .env (named pipe) is detected and NOT read.",
     "inputSchema": {"type": "object", "required": ["path"], "properties": {"path": _STR}}},
    {"name": "op_scan_mcp_config",
     "description": "Find plaintext credentials in an MCP config file (.mcp.json, claude_desktop_config.json…) and "
                    "return, per server, the names at fault and a suggested `op run --environment` entry. No values.",
     "inputSchema": {"type": "object", "required": ["path"], "properties": {"path": _STR}}},
    {"name": "op_scan_tree",
     "description": "Walk a project directory for dotenv files and MCP configs and summarise which hold plaintext "
                    "secrets (names only). Skips .git, node_modules, virtualenvs and build output.",
     "inputSchema": {"type": "object", "required": ["path"], "properties": {
         "path": _STR, "max_files": {"type": "integer", "minimum": 1, "maximum": 2000}}}},
]
for _t in TOOLS:
    _t["annotations"] = dict(_RO)


def _checked_path(raw: object) -> str:
    if not isinstance(raw, str) or not raw.strip():
        raise ValueError("`path` must be a non-empty string")
    p = Path(raw).expanduser()
    p = p if p.is_absolute() else Path.cwd() / p
    root = os.environ.get("OP_GUARD_ROOT")
    if root:
        base = Path(root).expanduser().resolve()
        # resolve the parent only: resolving a FIFO path itself is harmless, but keep it lexical for the leaf
        parent = p.parent.resolve()
        if parent != base and base not in parent.parents:
            raise PermissionError(f"path is outside OP_GUARD_ROOT ({base})")
    return str(p)


def _s(args: dict, key: str, required: bool = False) -> str | None:
    v = args.get(key)
    if v is None or v == "":
        if required:
            raise ValueError(f"`{key}` is required")
        return None
    if not isinstance(v, str) or v.startswith("-") or any(c in v for c in "\n\r\0"):
        raise ValueError(f"`{key}` must be a plain string that does not start with '-'")
    return v


def call_tool(name: str, args: dict) -> object:
    if name == "op_status":
        return G.status()
    if name == "op_vault_list":
        return G.vault_list()
    if name == "op_item_list":
        return G.item_list(_s(args, "vault"), _s(args, "categories"), _s(args, "tags"))
    if name == "op_item_fields":
        return G.item_fields(_s(args, "item", True), _s(args, "vault"))
    if name == "op_reference_check":
        refs = args.get("references")
        if not isinstance(refs, list) or not refs or len(refs) > 50:
            raise ValueError("`references` must be a list of 1–50 op:// strings")
        return G.check_references(refs)
    if name == "op_environment_names":
        return G.environment_secret_names(_s(args, "environment", True))
    if name == "op_scan_env_file":
        return G.scan_env_file(_checked_path(args.get("path")))
    if name == "op_scan_mcp_config":
        return G.scan_mcp_config(_checked_path(args.get("path")))
    if name == "op_scan_tree":
        mf = args.get("max_files", 400)
        if not isinstance(mf, int) or isinstance(mf, bool) or not 1 <= mf <= 2000:
            raise ValueError("`max_files` must be an integer 1–2000")
        return G.scan_tree(_checked_path(args.get("path")), mf)
    raise ValueError(f"unknown tool {name}")


def handle(msg: dict) -> dict | None:
    method, mid = msg.get("method"), msg.get("id")
    params = msg.get("params", {})
    if mid is not None and not isinstance(params, dict):
        return {"jsonrpc": "2.0", "id": mid, "error": {"code": -32602, "message": "params must be an object"}}
    if mid is None:  # notification (e.g. notifications/initialized)
        return None
    if method == "initialize":
        pv = params.get("protocolVersion")
        result = {"protocolVersion": pv if pv in SUPPORTED_PROTOCOL_VERSIONS else PROTOCOL_VERSION,
                  "capabilities": {"tools": {}}, "serverInfo": SERVER_INFO, "instructions": INSTRUCTIONS}
    elif method == "ping":
        result = {}
    elif method == "tools/list":
        result = {"tools": TOOLS}
    elif method == "tools/call":
        name = params.get("name", "")
        arguments = params.get("arguments") or {}
        if not isinstance(arguments, dict):
            return {"jsonrpc": "2.0", "id": mid, "error": {"code": -32602, "message": "arguments must be an object"}}
        if name not in {t["name"] for t in TOOLS}:
            return {"jsonrpc": "2.0", "id": mid, "error": {"code": -32602, "message": f"unknown tool {name}"}}
        try:
            payload = call_tool(name, arguments)
            result = {"content": [{"type": "text", "text": json.dumps(payload, ensure_ascii=False, indent=2)}],
                      "isError": False}
        except Exception as e:  # any tool failure is a tool result, never a server crash
            result = {"content": [{"type": "text", "text": f"{type(e).__name__}: {e}"}], "isError": True}
    else:
        return {"jsonrpc": "2.0", "id": mid, "error": {"code": -32601, "message": f"method not found: {method}"}}
    return {"jsonrpc": "2.0", "id": mid, "result": result}


def main() -> None:
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            msg = json.loads(line)
        except json.JSONDecodeError as e:
            resp = {"jsonrpc": "2.0", "id": None, "error": {"code": -32700, "message": str(e)}}
        else:
            if not isinstance(msg, dict):
                resp = {"jsonrpc": "2.0", "id": None, "error": {"code": -32600, "message": "batch not supported"}}
            else:
                try:
                    resp = handle(msg)
                except Exception as e:  # keep the stdio loop alive
                    resp = {"jsonrpc": "2.0", "id": msg.get("id"),
                            "error": {"code": -32603, "message": f"{type(e).__name__}: {e}"}}
        if resp is not None:
            sys.stdout.write(json.dumps(resp, ensure_ascii=False) + "\n")
            sys.stdout.flush()


if __name__ == "__main__":
    main()
