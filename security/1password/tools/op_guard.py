#!/usr/bin/env python3
"""op_guard.py — READ-ONLY, value-free helpers around 1Password CLI (`op`) for coding agents.

Every function here returns METADATA ONLY: names, ids, labels, types, secret
references (`op://vault/item/field`), booleans. No function returns, prints or
logs a secret VALUE. Values that `op` hands back are dropped inside this process
before anything is serialised.

It never signs in, never creates/edits/deletes an item, vault, Environment or
service account, and never writes a file. `op` calls are reads only:
`op --version`, `op account list`, `op whoami`, `op vault list`, `op item list`,
`op item get`, `op read` (output discarded), `op environment secret list`
(without `--reveal`).

Stdlib only. Review before running. Used by `op_mcp_server.py` and as a CLI:

  python3 op_guard.py status
  python3 op_guard.py scan-env  path/to/.env
  python3 op_guard.py scan-mcp  path/to/.mcp.json
  python3 op_guard.py scan-tree path/to/project
  python3 op_guard.py vaults
  python3 op_guard.py items  [--vault V] [--categories "API Credential,Login"] [--tags t1,t2]
  python3 op_guard.py fields ITEM [--vault V]
  python3 op_guard.py check  op://vault/item/field [more refs…]
  python3 op_guard.py env-names ENVIRONMENT_NAME_OR_ID
"""
from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import stat
import subprocess
import sys
from pathlib import Path

OP_TIMEOUT = int(os.environ.get("OP_GUARD_TIMEOUT", "60"))

# Environment variables whose PRESENCE matters. Values are never read out.
PRESENCE_VARS = (
    "OP_SERVICE_ACCOUNT_TOKEN", "OP_CONNECT_HOST", "OP_CONNECT_TOKEN",
    "OP_ACCOUNT", "OP_SESSION", "OP_BIOMETRIC_UNLOCK_ENABLED", "SSH_AUTH_SOCK",
)

SECRET_NAME_RE = re.compile(
    r"(SECRET|TOKEN|PASSWORD|PASSWD|PASSPHRASE|PWD|CREDENTIAL|PRIVATE|API[_-]?KEY|ACCESS[_-]?KEY|"
    r"AUTH|BEARER|SESSION|COOKIE|SIGNING|ENCRYPTION|DSN|DATABASE_URL|CONNECTION_STRING|"
    r"CONN_STR|WEBHOOK|LICENSE|_KEY$|_PAT$|^PAT$)", re.I)

# Shape of well-known credentials. Only the LABEL is ever reported.
VALUE_SHAPES = (
    ("1password-service-account-token", re.compile(r"^ops_[A-Za-z0-9_\-]{40,}")),
    ("github-token", re.compile(r"^(ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{30,}|^github_pat_[A-Za-z0-9_]{40,}")),
    ("aws-access-key-id", re.compile(r"^(AKIA|ASIA)[A-Z0-9]{16}$")),
    ("slack-token", re.compile(r"^xox[abposr]-")),
    ("llm-api-key", re.compile(r"^sk-[A-Za-z0-9_\-]{20,}")),
    ("google-api-key", re.compile(r"^AIza[0-9A-Za-z_\-]{30,}")),
    ("stripe-key", re.compile(r"^(sk|rk|pk)_(live|test)_[A-Za-z0-9]{16,}")),
    ("private-key-block", re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----")),
    ("jwt", re.compile(r"^eyJ[A-Za-z0-9_\-]{10,}\.[A-Za-z0-9_\-]{10,}\.")),
    ("url-with-password", re.compile(r"^[a-z][a-z0-9+.\-]*://[^/\s:@]+:[^/\s@]+@")),
)

REF_RE = re.compile(r"op://[^\s\"'`}<>]+")
PLACEHOLDER_RE = re.compile(r"^(\$\{?[A-Za-z_][A-Za-z0-9_]*\}?|<[^>]*>|changeme|change-me|xxx+|your[-_ ].*|todo|\*+)$", re.I)
ENV_LINE_RE = re.compile(r"^\s*(?:export\s+)?([A-Za-z_][A-Za-z0-9_.\-]*)\s*=\s*(.*)$")

SKIP_DIRS = {".git", "node_modules", ".venv", "venv", "__pycache__", "vendor", "dist", "build",
             "target", ".terraform", ".next", ".cache", ".tox", ".idea", ".gradle"}
MCP_CONFIG_NAMES = {".mcp.json", "mcp.json", "claude_desktop_config.json", "mcp_config.json"}
MAX_SCAN_BYTES = 2 * 1024 * 1024


class OpError(RuntimeError):
    """`op` failed. The message is op's stderr; op never puts a secret value there."""


# --------------------------------------------------------------------------- op

def op_path() -> str | None:
    return shutil.which("op")


def _run_op(args: list[str], *, want_stdout: bool = True) -> str:
    exe = op_path()
    if not exe:
        raise OpError("1Password CLI (`op`) is not on PATH — see https://www.1password.dev/cli/get-started")
    try:
        p = subprocess.run([exe, *args], stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                           stderr=subprocess.PIPE, timeout=OP_TIMEOUT, check=False)
    except subprocess.TimeoutExpired:
        raise OpError(f"`op {args[0]}` timed out after {OP_TIMEOUT}s — an authorization prompt may be "
                      "waiting in the 1Password app") from None
    if p.returncode != 0:
        err = p.stderr.decode("utf-8", "replace").strip().splitlines()
        raise OpError(err[-1] if err else f"op exited {p.returncode}")
    return p.stdout.decode("utf-8", "replace") if want_stdout else ""


def _op_json(args: list[str]) -> object:
    out = _run_op([*args, "--format", "json"])
    try:
        return json.loads(out) if out.strip() else []
    except json.JSONDecodeError:
        raise OpError("op returned output that is not JSON") from None


def status() -> dict:
    """Local 1Password posture. Presence booleans only for anything sensitive."""
    exe = op_path()
    res: dict = {"op_cli": {"path": exe, "version": None}}
    if exe:
        try:
            res["op_cli"]["version"] = _run_op(["--version"]).strip()
        except OpError as e:
            res["op_cli"]["error"] = str(e)
    accounts: list = []
    if exe:
        try:
            raw = _op_json(["account", "list"])
            accounts = [{"url": a.get("url"), "email": a.get("email"), "user_uuid": a.get("user_uuid"),
                         "shorthand": a.get("shorthand")} for a in raw if isinstance(a, dict)]
        except OpError as e:
            res["accounts_error"] = str(e)
    res["accounts"] = accounts
    env = {k: (k in os.environ and os.environ[k] != "") for k in PRESENCE_VARS}
    res["env_present"] = env
    if env["OP_CONNECT_HOST"] and env["OP_CONNECT_TOKEN"]:
        res["auth_mode"] = "connect-server"
    elif env["OP_SERVICE_ACCOUNT_TOKEN"]:
        res["auth_mode"] = "service-account"
    elif accounts:
        res["auth_mode"] = "desktop-app-or-manual-signin"
    else:
        res["auth_mode"] = "none"
    home = Path.home()
    app_candidates = [Path("/Applications/1Password.app"), home / "Applications/1Password.app",
                      Path("/opt/1Password/1password"), Path("/usr/bin/1password")]
    res["desktop_app_found"] = any(p.exists() for p in app_candidates)
    res["environments_mcp_binary"] = shutil.which("1password-mcp")
    socks = [home / "Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock", home / ".1password/agent.sock"]
    res["ssh_agent_socket"] = next((str(s) for s in socks if s.exists()), None)
    res["ssh_agent_config"] = (home / ".config/1Password/ssh/agent.toml").exists()
    notes = []
    if not exe:
        notes.append("Install 1Password CLI: https://www.1password.dev/cli/get-started")
    if res["auth_mode"] == "none":
        notes.append("No account and no service-account/Connect variables: turn on the desktop app "
                     "integration (Settings > Developer > Integrate with 1Password CLI) or export "
                     "OP_SERVICE_ACCOUNT_TOKEN from a secure source.")
    if not res["desktop_app_found"]:
        notes.append("1Password desktop app not found: biometric unlock, Environments mounts, the "
                     "Environments MCP server and the SSH agent all need it.")
    res["notes"] = notes
    return res


def whoami() -> dict:
    d = _op_json(["whoami"])
    if not isinstance(d, dict):
        return {}
    return {k: d.get(k) for k in ("url", "email", "user_uuid", "account_uuid", "user_type") if k in d}


def vault_list() -> list[dict]:
    raw = _op_json(["vault", "list"])
    return [{"id": v.get("id"), "name": v.get("name")} for v in raw if isinstance(v, dict)]


def item_list(vault: str | None = None, categories: str | None = None, tags: str | None = None) -> list[dict]:
    args = ["item", "list"]
    if vault:
        args += ["--vault", vault]
    if categories:
        args += ["--categories", categories]
    if tags:
        args += ["--tags", tags]
    raw = _op_json(args)
    out = []
    for it in raw:
        if not isinstance(it, dict):
            continue
        # `additional_information` usually carries the username — dropped on purpose.
        out.append({"id": it.get("id"), "title": it.get("title"), "category": it.get("category"),
                    "vault": (it.get("vault") or {}).get("name"), "tags": it.get("tags", []),
                    "updated_at": it.get("updated_at")})
    return out


def item_fields(item: str, vault: str | None = None) -> dict:
    """Field map of one item: labels, types, secret references. Never a value."""
    args = ["item", "get", item]
    if vault:
        args += ["--vault", vault]
    raw = _op_json(args)
    if not isinstance(raw, dict):
        raise OpError("unexpected item payload")
    fields = []
    for f in raw.get("fields", []) or []:
        if not isinstance(f, dict):
            continue
        fields.append({"id": f.get("id"), "label": f.get("label"), "type": f.get("type"),
                       "purpose": f.get("purpose"), "section": (f.get("section") or {}).get("label"),
                       "reference": f.get("reference"), "has_value": bool(f.get("value")),
                       "has_totp": f.get("type") == "OTP"})
    return {"id": raw.get("id"), "title": raw.get("title"), "category": raw.get("category"),
            "vault": (raw.get("vault") or {}).get("name"), "fields": fields,
            "files": [{"name": x.get("name")} for x in raw.get("files", []) or [] if isinstance(x, dict)]}


def check_references(refs: list[str]) -> list[dict]:
    """Does each `op://` reference resolve? The resolved value is discarded unread."""
    out = []
    for r in refs:
        if not isinstance(r, str) or not r.startswith("op://") or any(c in r for c in "\n\r\0"):
            out.append({"reference": str(r)[:200], "resolves": False, "error": "not an op:// secret reference"})
            continue
        try:
            _run_op(["read", "--no-newline", r], want_stdout=False)
            out.append({"reference": r, "resolves": True})
        except OpError as e:
            out.append({"reference": r, "resolves": False, "error": str(e)})
    return out


def environment_secret_names(environment: str) -> list[dict]:
    """Names of the secrets in a 1Password Environment. `--reveal` is never passed and any
    value op returns for a non-concealed secret is dropped here."""
    raw = _op_json(["environment", "secret", "list", environment])
    rows = raw if isinstance(raw, list) else (raw.get("secrets") or raw.get("variables") or []) \
        if isinstance(raw, dict) else []
    out = []
    for s in rows:
        if isinstance(s, dict):
            out.append({"name": s.get("name"), "concealed": s.get("concealed", s.get("masked"))})
    return out


# ------------------------------------------------------------------- scanning

def _strip_value(raw: str) -> str:
    v = raw.strip()
    if len(v) >= 2 and v[0] == v[-1] and v[0] in "\"'":
        return v[1:-1]
    return re.sub(r"\s+#.*$", "", v).strip()


def classify_value(name: str, value: str) -> tuple[str, str | None]:
    """→ (kind, reason). kind ∈ empty | secret-reference | placeholder | plaintext-secret | plain.
    `reason` names the rule that fired; it never contains the value."""
    v = value.strip()
    if not v:
        return "empty", None
    if v.startswith("op://") or REF_RE.search(v):
        return "secret-reference", None
    if PLACEHOLDER_RE.match(v):
        return "placeholder", None
    for label, rx in VALUE_SHAPES:
        if rx.search(v):
            return "plaintext-secret", f"value-shape:{label}"
    if SECRET_NAME_RE.search(name) and len(v) >= 8 and v.lower() not in {"true", "false", "none", "null"}:
        return "plaintext-secret", "name-suggests-secret"
    return "plain", None


def _is_fifo(p: Path) -> bool:
    try:
        return stat.S_ISFIFO(p.stat().st_mode)
    except OSError:
        return False


def scan_env_file(path: str) -> dict:
    """Classify each KEY of a dotenv-style file. Returns key NAMES and a verdict — no values.

    A FIFO is a 1Password-mounted `.env`: reading it would pull every secret of the
    Environment into this process (and raise an authorization prompt), so it is reported
    as mounted and NOT opened.
    """
    p = Path(path).expanduser()
    res: dict = {"path": str(p)}
    if not p.exists():
        return {**res, "error": "file not found"}
    if _is_fifo(p):
        return {**res, "mounted_by_1password": True, "keys": [],
                "note": "Named pipe — a locally mounted 1Password Environment. Not read. Nothing to migrate."}
    if not p.is_file():
        return {**res, "error": "not a regular file"}
    if p.stat().st_size > MAX_SCAN_BYTES:
        return {**res, "error": "file larger than 2 MiB — skipped"}
    keys = []
    for n, line in enumerate(p.read_text("utf-8", "replace").splitlines(), 1):
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        m = ENV_LINE_RE.match(line)
        if not m:
            continue
        kind, reason = classify_value(m.group(1), _strip_value(m.group(2)))
        row = {"line": n, "name": m.group(1), "kind": kind}
        if reason:
            row["reason"] = reason
        keys.append(row)
    plain = [k["name"] for k in keys if k["kind"] == "plaintext-secret"]
    return {**res, "mounted_by_1password": False, "keys": keys, "plaintext_secret_count": len(plain),
            "plaintext_secret_names": plain,
            "verdict": "MIGRATE: plaintext secrets on disk — import into a 1Password Environment, then rotate them"
            if plain else "ok: no plaintext secret detected (heuristic — review the names yourself)"}


def scan_mcp_config(path: str) -> dict:
    """Find plaintext credentials in an MCP config (`.mcp.json`, `claude_desktop_config.json`…)
    and propose the `op run --environment <ID> -- <original command>` rewrite. No values returned."""
    p = Path(path).expanduser()
    res: dict = {"path": str(p)}
    if not p.is_file():
        return {**res, "error": "file not found"}
    if p.stat().st_size > MAX_SCAN_BYTES:
        return {**res, "error": "file larger than 2 MiB — skipped"}
    try:
        doc = json.loads(p.read_text("utf-8", "replace"))
    except json.JSONDecodeError as e:
        return {**res, "error": f"not valid JSON: {e.msg} (line {e.lineno})"}
    servers = doc.get("mcpServers") if isinstance(doc, dict) else None
    if not isinstance(servers, dict):
        return {**res, "servers": [], "note": "no `mcpServers` object"}
    out = []
    for name, cfg in servers.items():
        if not isinstance(cfg, dict):
            continue
        cmd = cfg.get("command")
        args = [a for a in (cfg.get("args") or []) if isinstance(a, str)]
        wrapped = isinstance(cmd, str) and os.path.basename(cmd) == "op" and "run" in args[:2]
        findings = []
        for k, v in (cfg.get("env") or {}).items():
            kind, reason = classify_value(str(k), v if isinstance(v, str) else "")
            if kind == "plaintext-secret":
                findings.append({"where": "env", "name": k, "reason": reason})
        for k, v in (cfg.get("headers") or {}).items():
            kind, reason = classify_value(str(k), v if isinstance(v, str) else "")
            if kind == "plaintext-secret" or (isinstance(v, str) and re.match(r"(?i)^(bearer|basic|token)\s+\S{8,}", v)):
                findings.append({"where": "headers", "name": k, "reason": reason or "authorization-header-literal"})
        for i, a in enumerate(args):
            kind, reason = classify_value("", a)
            if kind == "plaintext-secret":
                findings.append({"where": "args", "index": i, "reason": reason})
        row: dict = {"server": name, "transport": "stdio" if cmd else cfg.get("type", "remote"),
                     "wrapped_with_op_run": bool(wrapped), "plaintext_findings": findings}
        if findings and cmd and not wrapped:
            keep = {k: v for k, v in (cfg.get("env") or {}).items()
                    if classify_value(str(k), v if isinstance(v, str) else "")[0] != "plaintext-secret"}
            fix = {"command": op_path() or "op",
                   "args": ["run", "--environment", "<ENVIRONMENT_ID>", "--", cmd,
                            *["<MOVED_TO_1PASSWORD>" if classify_value("", a)[0] == "plaintext-secret" else a
                              for a in args]]}
            if keep:
                fix["env"] = keep
            row["suggested_entry"] = fix
            row["next_steps"] = [
                "Create a 1Password Environment holding: " + ", ".join(sorted({str(f.get('name')) for f in findings if f.get('name')})),
                "Manage environment > Copy environment ID, put it in place of <ENVIRONMENT_ID>",
                "Delete the plaintext values from this file, then ROTATE them — they were on disk",
            ]
        out.append(row)
    return {**res, "servers": out, "servers_with_plaintext": [r["server"] for r in out if r["plaintext_findings"]]}


def scan_tree(root: str, max_files: int = 400) -> dict:
    """Walk a project for dotenv files and MCP configs; summarise each (names only)."""
    base = Path(root).expanduser()
    if not base.is_dir():
        return {"root": str(base), "error": "not a directory"}
    envs, mcps, seen = [], [], 0
    for dirpath, dirnames, filenames in os.walk(base):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for fn in sorted(filenames):
            full = Path(dirpath) / fn
            is_env = fn == ".env" or fn.startswith(".env.") or fn.endswith(".env")
            is_mcp = fn in MCP_CONFIG_NAMES
            if not (is_env or is_mcp):
                continue
            seen += 1
            if seen > max_files:
                break
            if is_env:
                r = scan_env_file(str(full))
                envs.append({"path": r["path"], "mounted_by_1password": r.get("mounted_by_1password"),
                             "plaintext_secret_names": r.get("plaintext_secret_names", []),
                             **({"error": r["error"]} if "error" in r else {})})
            else:
                r = scan_mcp_config(str(full))
                mcps.append({"path": r["path"], "servers_with_plaintext": r.get("servers_with_plaintext", []),
                             **({"error": r["error"]} if "error" in r else {})})
    return {"root": str(base), "env_files": envs, "mcp_configs": mcps,
            "files_with_plaintext": [e["path"] for e in envs if e["plaintext_secret_names"]]
            + [m["path"] for m in mcps if m["servers_with_plaintext"]],
            "truncated": seen > max_files}


# ------------------------------------------------------------------------ CLI

def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="Read-only, value-free 1Password helpers (metadata only).")
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("status")
    sub.add_parser("whoami")
    sub.add_parser("vaults")
    s = sub.add_parser("items")
    s.add_argument("--vault")
    s.add_argument("--categories")
    s.add_argument("--tags")
    s = sub.add_parser("fields")
    s.add_argument("item")
    s.add_argument("--vault")
    s = sub.add_parser("check")
    s.add_argument("refs", nargs="+")
    s = sub.add_parser("env-names")
    s.add_argument("environment")
    for name in ("scan-env", "scan-mcp", "scan-tree"):
        s = sub.add_parser(name)
        s.add_argument("path")
    a = ap.parse_args(argv)
    try:
        if a.cmd == "status":
            out: object = status()
        elif a.cmd == "whoami":
            out = whoami()
        elif a.cmd == "vaults":
            out = vault_list()
        elif a.cmd == "items":
            out = item_list(a.vault, a.categories, a.tags)
        elif a.cmd == "fields":
            out = item_fields(a.item, a.vault)
        elif a.cmd == "check":
            out = check_references(a.refs)
        elif a.cmd == "env-names":
            out = environment_secret_names(a.environment)
        elif a.cmd == "scan-env":
            out = scan_env_file(a.path)
        elif a.cmd == "scan-mcp":
            out = scan_mcp_config(a.path)
        else:
            out = scan_tree(a.path)
    except OpError as e:
        print(f"op error: {e}", file=sys.stderr)
        return 4
    print(json.dumps(out, ensure_ascii=False, indent=2))
    if a.cmd in ("scan-env",) and isinstance(out, dict) and out.get("plaintext_secret_count"):
        return 1
    if a.cmd in ("scan-mcp",) and isinstance(out, dict) and out.get("servers_with_plaintext"):
        return 1
    if a.cmd == "scan-tree" and isinstance(out, dict) and out.get("files_with_plaintext"):
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
