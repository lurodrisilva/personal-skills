<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-11-18 | Updated: 2026-11-18 -->

# tools

## Purpose
The executable half of the `1password` skill: a stdlib Python library and CLI that asks
1Password CLI (`op`) for **metadata only**, an MCP stdio server that exposes the same functions
to an agent, two read-only audit scripts, and an offline self-test. Together they let an agent
answer "what secrets exist, what are they called, where is plaintext hiding, is this machine
wired correctly" **without a secret value ever being printed or returned**.

## Key Files
| File | Surfaces |
|------|----------|
| `op_guard.py` | Library + CLI. `status`, `whoami`, `vaults`, `items`, `fields` (labels, types and `op://` references), `check` (does a reference resolve — value discarded), `env-names` (Environment variable names), `scan-env`, `scan-mcp`, `scan-tree` (plaintext by key name). Exit `1` when plaintext is found, `4` on an `op` error |
| `op_mcp_server.py` | MCP stdio server `1password-guard`: `op_status`, `op_vault_list`, `op_item_list`, `op_item_fields`, `op_reference_check`, `op_environment_names`, `op_scan_env_file`, `op_scan_mcp_config`, `op_scan_tree`. `OP_GUARD_ROOT` confines the file tools to one tree |
| `op-doctor.sh` | Readiness snapshot — CLI version, accounts, auth mode, desktop app, SSH socket, plugin and MCP wiring. Exit `0` ready / `2` no CLI / `4` unauthenticated; `--vaults` also lists vault names |
| `op-ssh-audit.sh` | SSH agent socket, client routing, `agent.toml`, private keys still on disk (by filename), Git signing config — public material only |
| `op-selftest.sh` | Offline self-test with synthetic fixtures: runs the scanners and the MCP server and fails if any fixture value appears in the output |

## For AI Agents

### Working In This Directory
- **Value-free is a hard invariant.** No function may return, print or log a secret value.
  Concretely: never pass `--reveal`; never call `op read` except inside `check_references`,
  which discards stdout; never include a field's `value`, a username, or a file's content in a
  result. The scanners report key names, a classification and a length bucket at most.
- **Read-only is a hard invariant.** No `op item create|edit|delete`, no `op vault` or
  `op service-account` mutation, no `op signin`, no writes outside a temp dir in the self-test.
  Creating, editing and rotating are human-approved actions described in `SKILL.md`, not tools.
- **No execution tool.** The MCP server must not grow an "`op run` this command" tool: that
  would turn a discovery server into an arbitrary-command runner with secrets attached.
- **Arguments are data.** Reject any vault, item or reference argument that begins with `-`, and
  always pass arguments as an argv list, never through a shell.
- **A mounted `.env` is not a file.** `scan_env_file` detects a FIFO and reports
  `mounted_by_1password` without opening it — opening it would trigger an authorization prompt
  and read real values.
- **Stdlib only**, no third-party imports; the server must start on a bare `python3`.
- Shell scripts start with `set -euo pipefail` (or handle failure explicitly), carry a
  read-only header, and test for presence (`[ -n "${VAR:-}" ]`) rather than printing variables.

### Testing Requirements
- `bash op-selftest.sh` → `SELFTEST PASSED`. Add a fixture and an assertion for every new
  scanner rule or MCP tool; the leak assertion (no fixture value in any output) must cover it.
- `bash -n *.sh` and `python3 -m py_compile *.py`.
- Manual, with a signed-in `op`: `python3 op_guard.py status`, `vaults`, `fields <item>` — and
  read the output for anything that looks like a value.

### Common Patterns
- Every `op` call goes through one helper that sets `--format json`, a timeout and
  `OP_FORMAT`-independent parsing, and maps failures to a structured error instead of raising
  raw stderr (which can echo arguments).
- MCP tool results are JSON objects with stable keys; errors come back as `isError` results,
  not exceptions.

## Dependencies

### External
- `op` ≥ the version that provides `op environment secret list` for `env-names`; everything
  else works on older 2.x releases.
- Python 3 standard library; `bash`; optional `git`, `ssh-add`, `claude` for the audit scripts.

<!-- MANUAL: -->
