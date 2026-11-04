   1 <!-- Parent: ../AGENTS.md -->
   2 <!-- Generated: 2026-11-04 | DEEPINIT: 2026-11-04 -->
   3 
   4 # cnab-444
   5 
   6 ## Purpose
   7 Skill for **generating, validating and inspecting CNAB 444 remessa files**
   8 in the layout of the ID Serviços Financeiros FIDC manual (*Manual CNAB ·
   9 Layout 444*): 444-byte header (`0`) / detail (`1`) / trailer (`9`) records,
  10 CRLF, ASCII uppercase, money in cents, `DDMMAA` dates, `CBDDMM…` file names.
  11 Four phases (A intake/mapping, B generation, C validation/triage, D
  12 instructions — prorrogação/baixa/recompra/abatimento) are delegated to
  13 three companion subagents in `../../.claude/agents/` (`cnab-444-*`).
  14 
  15 ## Key Files
  16 | File | Description |
  17 |------|-------------|
  18 | `SKILL.md` | The skill: 6 CORE PRINCIPLES (one layout table, generate→validate→name, refuse-never-truncate, ASCII/444/CRLF, synthetic-data-only, generation≠submission), Phase A–D playbooks, operating windows, anti-patterns, checklist, full field REFERENCE, ocorrência/espécie tables, manual-vs-production discrepancy table, MCP SURFACE, subagent orchestration |
  19 
  20 ## Subdirectories
  21 | Directory | Purpose |
  22 |-----------|---------|
  23 | `tools/` | `cnab444.py` (stdlib CLI + library: generate/validate/inspect/filename/layout), `cnab444_mcp_server.py` (MCP stdio server, 6 tools), `cnab444-selftest.sh` (offline regression suite), `examples/` (synthetic spec + generated `CB15100001.REM`) (see `tools/AGENTS.md`) |
  24 
  25 ## For AI Agents
  26 
  27 ### Working In This Directory
  28 - Every layout claim traces to the manual **or** to the production samples
  29   used to build the toolkit (Oct 2026, kept outside the repo). Where they
  30   disagree, the SKILL.md discrepancy table records the choice — update it
  31   together with `tools/cnab444.py` (`HEADER`/`DETAIL`/`TRAILER`).
  32 - The SKILL.md `description` opens with `MUST USE when …` — keep trigger
  33   phrases exhaustive (Portuguese domain terms included).
  34 - Never add real `.REM` files, CNPJs, names or NF-e keys anywhere here.
  35 
  36 ### Testing Requirements
  37 - `tools/cnab444-selftest.sh [real.REM ...]` — must end `ALL SELFTESTS
  38   PASSED`; real files passed as arguments are round-tripped
  39   (`generate(inspect(x)) == x`) without being copied.
  40 - `./scripts/validate-skills.sh` from the repo root.
  41 
  42 ## Dependencies
  43 
  44 ### Internal
  45 - `../../.claude/agents/cnab-444-remessa-generator.md` (Phases A–B),
  46   `cnab-444-file-auditor.md` (Phase C), `cnab-444-instructions-operator.md`
  47   (Phase D).
  48 
  49 ### External
  50 - `python3` ≥ 3.9 (stdlib only). Optional: Claude Code / opencode MCP
  51   registration of `tools/cnab444_mcp_server.py`.
  52 
  53 <!-- MANUAL: -->
