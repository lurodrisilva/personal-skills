   1 <!-- Parent: ../AGENTS.md -->
   2 <!-- Generated: 2026-11-04 | DEEPINIT: 2026-11-04 -->
   3 
   4 # file-exchange
   5 
   6 ## Purpose
   7 File-format / interchange-layout skills — guidance and tooling for
   8 **generating and validating files exchanged with banks, custodians and
   9 other counterparties** (fixed-width remessas, EDI-style layouts). Each
  10 subdirectory contains exactly one `SKILL.md`; skills here typically ship a
  11 stdlib generator/validator and an MCP stdio server under `tools/`, because
  12 fixed-width layouts are precisely where hand-formatting goes wrong.
  13 
  14 ## Key Files
  15 None at this level — all content lives in subdirectories.
  16 
  17 ## Subdirectories
  18 | Directory | Purpose |
  19 |-----------|---------|
  20 | `cnab-444/` | CNAB 444 remessa files for FIDC custody (ID Serviços Financeiros manual) — 444-byte header/detail/trailer layout, ocorrência/espécie tables, CB file naming, prorrogação/baixa instructions, manual-vs-production discrepancies; `tools/cnab444.py` (generate/validate/inspect/filename/layout), `tools/cnab444_mcp_server.py`, `tools/cnab444-selftest.sh`; three `cnab-444-*` subagents (see `cnab-444/AGENTS.md`) |
  21 
  22 ## For AI Agents
  23 
  24 ### Working In This Directory
  25 - Every immediate subdirectory must contain a `SKILL.md` matching the
  26   contract in the root `CLAUDE.md`; `scripts/validate-skills.sh` walks this
  27   domain (it is in `DOMAIN_DIRS`).
  28 - Naming: the layout/standard name in kebab-case (e.g. `cnab-444`).
  29 - **Never commit real exchange files.** Remessas, retornos and EDI files
  30   carry CNPJs/CPFs, names, addresses and fiscal keys of real parties —
  31   fixtures must be synthetic (valid check digits, fake identities).
  32 - One layout table per skill, imported by every tool; prove record tiling
  33   at import time.
  34 
  35 ### Testing Requirements
  36 - `./scripts/validate-skills.sh` from the repo root.
  37 - Each skill's own self-test (e.g. `cnab-444/tools/cnab444-selftest.sh`).
  38 
  39 ## Dependencies
  40 
  41 ### Internal
  42 - `../.claude/agents/cnab-444-*.md` — the CNAB-444 team (generator,
  43   auditor, instructions operator).
  44 
  45 <!-- MANUAL: -->
