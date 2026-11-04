#!/usr/bin/env python3
"""cnab444_mcp_server.py — dependency-free MCP stdio server for CNAB 444.

Transport: newline-delimited JSON-RPC 2.0 on stdin/stdout (MCP stdio).
stdout carries protocol messages only; diagnostics go to stderr.

Register:
  claude mcp add cnab444 -- python3 /abs/path/file-exchange/cnab-444/tools/cnab444_mcp_server.py

Tools
  cnab444_layout    field table (header/detail/trailer)
  cnab444_validate  validate a .REM given by path or inline content
  cnab444_inspect   decode a .REM into the JSON spec shape
  cnab444_generate  JSON spec -> .REM content (writes only when output_dir is given)
  cnab444_filename  canonical CB file name
  cnab444_codes     espécie / ocorrência code tables
"""
from __future__ import annotations

import json
import os
import sys
from dataclasses import asdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import cnab444 as C  # noqa: E402

PROTOCOL_VERSION = "2025-06-18"
SUPPORTED_PROTOCOL_VERSIONS = {"2024-11-05", "2025-03-26", "2025-06-18"}
SERVER_INFO = {"name": "cnab444", "version": "1.0.0"}

_STR = {"type": "string"}
TOOLS = [
    {
        "name": "cnab444_layout",
        "description": "Return the CNAB 444 field table (1-based positions, size, kind, required, constant/default, doc).",
        "inputSchema": {"type": "object", "properties": {
            "record": {"type": "string", "enum": ["header", "detail", "trailer"]}}},
    },
    {
        "name": "cnab444_validate",
        "description": "Validate a CNAB 444 remessa. Pass `path` (local file) or `content` (file text). Returns errors/warnings by line and field.",
        "inputSchema": {"type": "object", "properties": {
            "path": _STR, "content": _STR, "filename": {**_STR, "description": "name to check against CBDDMMxx when using content"}}},
    },
    {
        "name": "cnab444_inspect",
        "description": "Decode a CNAB 444 remessa (path or content) into the JSON spec shape used by cnab444_generate, plus a summary.",
        "inputSchema": {"type": "object", "properties": {"path": _STR, "content": _STR, "summary_only": {"type": "boolean"}}},
    },
    {
        "name": "cnab444_generate",
        "description": ("Generate a CNAB 444 remessa from a spec {header, defaults?, titulos[]}. Returns the file name, "
                        "validation findings and the content. Writes to disk only when `output_dir` is given; never overwrites."),
        "inputSchema": {"type": "object", "required": ["spec"], "properties": {
            "spec": {"type": "object"},
            "output_dir": _STR,
            "style": {"type": "string", "enum": ["observed", "manual"]},
            "ext": {"type": "string", "enum": ["REM", "TXT"]},
            "include_content": {"type": "boolean", "description": "default true"}}},
    },
    {
        "name": "cnab444_filename",
        "description": "Build the canonical file name CB+DDMM+suffix(.REM|.TXT). style observed = last 4 digits of seq_arquivo; manual = 2-char suffix.",
        "inputSchema": {"type": "object", "required": ["data_gravacao"], "properties": {
            "data_gravacao": _STR, "seq_arquivo": _STR, "suffix": _STR,
            "style": {"type": "string", "enum": ["observed", "manual"]},
            "ext": {"type": "string", "enum": ["REM", "TXT"]}}},
    },
    {
        "name": "cnab444_codes",
        "description": "Return the espécie and ocorrência code tables from the manual.",
        "inputSchema": {"type": "object", "properties": {}},
    },
]


MAX_INPUT_BYTES = 50 * 1024 * 1024  # ~110k records; far above any real remessa
ALLOWED_SUFFIXES = {".rem", ".txt"}


def _allowed_root() -> Path | None:
    root = os.environ.get("CNAB444_ROOT")
    return Path(root).expanduser().resolve() if root else None


def _read_input(args: dict) -> tuple[bytes, str | None]:
    """Read a remessa by path (regular .REM/.TXT file only, size-capped, optionally
    confined to $CNAB444_ROOT) or from inline `content`. Never reads arbitrary files:
    the result is echoed back to the model, so a secret file must not be reachable."""
    if args.get("path"):
        p = Path(args["path"]).expanduser().resolve()
        if p.suffix.lower() not in ALLOWED_SUFFIXES:
            raise C.CnabError(f"refusing {p.name}: only .REM/.TXT files are read")
        root = _allowed_root()
        if root and not p.is_relative_to(root):
            raise C.CnabError(f"refusing {p}: outside CNAB444_ROOT={root}")
        if not p.is_file():
            raise C.CnabError(f"{p} is not a regular file")
        if p.stat().st_size > MAX_INPUT_BYTES:
            raise C.CnabError(f"{p} exceeds {MAX_INPUT_BYTES} bytes")
        with p.open("rb") as f:
            return f.read(MAX_INPUT_BYTES + 1)[:MAX_INPUT_BYTES], str(p)
    if "content" in args:
        content = str(args["content"])
        if len(content) > MAX_INPUT_BYTES:
            raise C.CnabError(f"content exceeds {MAX_INPUT_BYTES} chars")
        return content.encode("latin-1", errors="replace"), args.get("filename")
    raise C.CnabError("pass `path` or `content`")


def call_tool(name: str, args: dict) -> object:
    if name == "cnab444_layout":
        rows = C.layout_table()
        rec = args.get("record")
        return [r for r in rows if not rec or r["record"] == rec]
    if name == "cnab444_validate":
        data, fname = _read_input(args)
        findings = C.validate_bytes(data, fname)
        errs = sum(f.level == "ERROR" for f in findings)
        return {"ok": errs == 0, "errors": errs, "warnings": len(findings) - errs,
                "findings": [asdict(f) for f in findings]}
    if name == "cnab444_inspect":
        data, _ = _read_input(args)
        doc = C.inspect_bytes(data)
        return doc["_summary"] if args.get("summary_only") else doc
    if name == "cnab444_generate":
        spec = args["spec"]
        records = C.generate_records(spec)
        data = C.render_file(records)
        h = spec["header"]
        fname = C.build_filename(h.get("data_gravacao"), h.get("seq_arquivo"),
                                 style=args.get("style", "observed"), ext=args.get("ext", "REM"))
        findings = C.validate_bytes(data, fname)
        errs = sum(f.level == "ERROR" for f in findings)
        result: dict = {"filename": fname, "records": len(records), "titulos": len(records) - 2,
                        "ok": errs == 0, "findings": [asdict(f) for f in findings]}
        if args.get("output_dir") and errs == 0:
            outdir = Path(args["output_dir"]).expanduser().resolve()
            if not outdir.is_dir():
                raise C.CnabError(f"output_dir {outdir} is not an existing directory")
            root = _allowed_root()
            if root and not outdir.is_relative_to(root):
                raise C.CnabError(f"refusing output_dir {outdir}: outside CNAB444_ROOT={root}")
            out = outdir / fname
            try:  # "xb" refuses any existing path, including a dangling symlink
                with out.open("xb") as f:
                    f.write(data)
            except FileExistsError:
                raise C.CnabError(f"{out} already exists — refusing to overwrite") from None
            result["written"] = str(out)
        if args.get("include_content", True):
            result["content"] = data.decode(C.ENCODING)
        return result
    if name == "cnab444_filename":
        return {"filename": C.build_filename(args["data_gravacao"], args.get("seq_arquivo"),
                                             suffix=args.get("suffix"), style=args.get("style", "observed"),
                                             ext=args.get("ext", "REM"))}
    if name == "cnab444_codes":
        return {"especies": C.ESPECIES, "ocorrencias": C.OCORRENCIAS,
                "liquidacao_exige_data": sorted(C.LIQUIDATION), "aquisicao": sorted(C.ACQUISITION)}
    raise KeyError(name)


def handle(msg: dict) -> dict | None:
    method, mid = msg.get("method"), msg.get("id")
    params = msg.get("params", {})
    if mid is not None and not isinstance(params, dict):
        return {"jsonrpc": "2.0", "id": mid, "error": {"code": -32602, "message": "params must be an object"}}
    if mid is None:  # notification (e.g. notifications/initialized)
        return None
    if method == "initialize":
        result = {"protocolVersion": params.get("protocolVersion") if params.get("protocolVersion")
                  in SUPPORTED_PROTOCOL_VERSIONS else PROTOCOL_VERSION,
                  "capabilities": {"tools": {}}, "serverInfo": SERVER_INFO}
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
                            "error": {"code": -32603, "message": f"internal error: {e}"}}
        if resp is not None:
            sys.stdout.write(json.dumps(resp, ensure_ascii=False) + "\n")
            sys.stdout.flush()


if __name__ == "__main__":
    main()
