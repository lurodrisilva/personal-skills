   1 <!-- Parent: ../AGENTS.md -->
   2 <!-- Generated: 2026-11-04 -->
   3 
   4 # tools
   5 
   6 ## Purpose
   7 Stdlib-only Python toolkit for the `cnab-444` skill. Unlike the read-only
   8 triage scripts elsewhere in this repo, these tools **produce files** — but
   9 only local files, only on request, never overwriting, and never submitting
  10 anything to a custodian or portal.
  11 
  12 ## Key Files
  13 | File | Surfaces |
  14 |------|----------|
  15 | `cnab444.py` | Layout tables `HEADER`/`DETAIL`/`TRAILER` (import-time tiling assertion 1..444) + CLI: `generate SPEC.json [--outdir/-o/--dry-run/--style observed\|manual/--ext REM\|TXT/--force]` (self-validates, refuses on ERROR, refuses to overwrite without `--force`), `validate FILE... [--json/-q]` (exit 1 on ERROR), `inspect FILE [--summary]` (spec JSON; round-trips byte-identically), `filename --date --seq/--suffix`, `layout [--record/--json]` |
  16 | `cnab444_mcp_server.py` | MCP stdio server (newline-delimited JSON-RPC 2.0, protocol-only stdout): `cnab444_layout`, `cnab444_codes`, `cnab444_filename`, `cnab444_inspect`, `cnab444_validate`, `cnab444_generate` (writes only with `output_dir`, never overwrites) |
  17 | `cnab444-selftest.sh` | Offline suite: tiling, example generation + byte-identity, CRLF/ASCII/accents, round-trip, 11 generator refusals, 5 validator corruption catches, filename styles, MCP protocol smoke test. Extra args = real `.REM` files to round-trip locally. Exit code = failures |
  18 | `examples/remessa-duplicata.json` | Synthetic spec (fake CNPJs with valid DVs, valid-DV NF-e keys) |
  19 | `examples/CB15100001.REM` | Its generated output — the selftest asserts byte-identity |
  20 
  21 ## For AI Agents
  22 
  23 ### Working In This Directory
  24 - Change the layout **only** in the tables in `cnab444.py`; every other
  25   tool imports them. Re-run `cnab444-selftest.sh` after any change and
  26   regenerate `examples/CB15100001.REM` only when the change is intended.
  27 - Keep stdlib-only (no `pip install`) so the tools run anywhere `python3`
  28   does; run with `python3 -I` when pointing at untrusted input dirs.
  29 - MCP server: nothing but JSON-RPC on stdout; errors become
  30   `isError: true` tool results, not crashes.
  31 
  32 <!-- MANUAL: -->
