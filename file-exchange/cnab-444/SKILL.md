---
name: cnab-444
description: >-
  MUST USE when generating, validating, inspecting, or debugging **CNAB 444
  remessa files** for FIDC receivables custody — the ID Serviços Financeiros
  "Manual CNAB · Layout 444" (header/detalhe/trailer of 444 bytes). Trigger
  phrases and patterns: "cnab 444", "cnab444", "layout 444", "arquivo
  remessa", "remessa FIDC", "cessão de recebíveis", "arquivo de cessão",
  "termo de cessão", "gerar arquivo CB", "CBDDMMxx", file names matching
  `CB\d{4}\w{2,4}\.(REM|TXT)` or `*.REM` with 444-character lines starting
  `01REMESSA01COBRANCA`, "ID Serviços Financeiros", "IDSF portal", "importação
  de cessão", "arquivos de baixa", "instrução de baixa", "prorrogação de
  vencimento" (ocorrência 20), "recompra", "liquidação parcial", "write-off",
  "duplicata", "nota comercial", "CCB", "chave NF-e" in a remessa, "seu número",
  "valor presente / valor de aquisição", "código do originador", "sacado",
  "cedente", "coobrigação", "espécie do título", "código de ocorrência", and
  any request to turn a spreadsheet/JSON/ERP export of títulos into a
  remessa. Covers the full field layout (positions, picture, padding,
  required), the ocorrência and espécie tables, naming rules, operating
  windows, prorrogação rules, the manual-vs-sample discrepancies, and a
  stdlib-only Python toolkit (generate / validate / inspect / filename) plus
  an MCP stdio server.
license: BSD-3-Clause
compatibility: opencode
metadata:
  domain: file-exchange
  standard: cnab-444
  vendor: id-servicos-financeiros
  category: fidc-receivables-remessa
  runtime: python3-stdlib + mcp-stdio
  source: "Manual CNAB · Layout 444 — ID Serviços Financeiros (FIDC)"
---

# CNAB 444 — FIDC remessa (ID Serviços Financeiros)

## Scope and version gate

This skill encodes **one** layout: the *Manual CNAB · Layout 444* of ID
Serviços Financeiros (custodian/administrator of FIDCs), cross-checked
against two real remessas produced in production (Oct 2026). It is **not**
the FEBRABAN CNAB 240/400 bank-collection layout, and other custodians
publish their own "444" variants whose constants and occurrence codes may
differ — confirm the custodian before reusing it.
If the custodian publishes a new manual revision, re-diff it against
`tools/cnab444.py` (`LAYOUT`) before generating anything.

## CORE PRINCIPLES

1. **The layout lives in one table.** `tools/cnab444.py` → `HEADER`,
   `DETAIL`, `TRAILER`. Generator, validator, inspector and MCP server all
   import it, and an import-time assertion proves each record tiles
   1..444 with no gap/overlap. Never hand-format a record with f-strings
   in a one-off script.
2. **Generate, then validate, then name.** Every file is produced by
   `cnab444.py generate`, which re-validates its own output and refuses to
   write on any ERROR. A file that was not validated is not deliverable.
3. **Refuse, never truncate or coerce.** Overflowing alfa/numeric values,
   negative or >2-decimal amounts, unknown fields, invalid dates and
   forbidden characters are errors. Silent truncation of a sacado name or
   CNPJ is how remessas get rejected — or worse, accepted wrong.
4. **ASCII, uppercase, 444 + CRLF.** Accents are stripped (NFKD), alfa is
   uppercased and left-justified/space-padded, numeric is right-justified/
   zero-padded, money is cents without separator, dates are `DDMMAA`,
   every record ends in CRLF including the trailer.
5. **Synthetic data only in the repo.** Real remessas contain CNPJs, names,
   addresses and NF-e keys of real companies. Never commit them, never
   paste them into examples or issues — use `tools/examples/` (fake CNPJs
   with valid check digits).
6. **Generation is not submission.** Uploading to the IDSF portal,
   prorrogação requests and baixa instructions are financial operations
   with cut-off times and approvals; the skill prepares and validates files,
   a human submits them.

## Capability map

| Phase | Question | Owner agent |
|---|---|---|
| A — Intake & mapping | Which source columns map to which CNAB fields? Which ocorrência/espécie? | `cnab-444-remessa-generator` |
| B — Generation | Build the JSON spec, run `generate`, name the file `CB…` | `cnab-444-remessa-generator` |
| C — Validation & triage | Is this `.REM` valid? Why was it rejected? Diff two files | `cnab-444-file-auditor` |
| D — Instructions (baixa / prorrogação / recompra / abatimento) | Which ocorrência, which fields change, one file per cedente? | `cnab-444-instructions-operator` |

## Phase A — Intake and mapping

Collect per remessa: **originador** (código de 20 dígitos fornecido pelo
custodiante + razão social), **data de gravação**, **nº sequencial do
arquivo** (7 dígitos, controlled by the originador — never reuse one), and
per título the fields marked required below. Decide per file:

- **ocorrência** (109–110): `01` aquisição for new cessões; see the table.
- **espécie** (148–149): `01` duplicata needs `numero_nf` (315–323) **and**
  `chave_nfe` (395–438); `07` nota comercial does not; `51` cheque needs
  `banco_cheque` (63–65).
- **coobrigação** (21–22): `01` com / `02` sem.
- **termo de cessão** (174–192): both production samples carry the remessa
  sequence (`seq_arquivo`) here — confirm with the custodian, then set it
  once in `defaults`.

## Phase B — Generation

Spec shape (`tools/examples/remessa-duplicata.json` is a complete one):

```json
{
  "header":   {"codigo_originador": "00000000000000000123", "nome_originador": "ORIGINADORA EXEMPLO",
               "data_gravacao": "2026-10-15", "seq_arquivo": "1000001"},
  "defaults": {"coobrigacao": "01", "ocorrencia": "01", "especie": "01", "tipo_pessoa_cedente": "02",
               "termo_cessao": "1000001", "tipo_inscricao_sacado": "02",
               "nome_cedente": "CEDENTE EXEMPLO INDUSTRIA LTDA", "cnpj_cedente": "11222333000181"},
  "titulos":  [{"seu_numero": "EX0001", "numero_documento": "1234-01", "vencimento": "2026-11-14",
                "valor_face": "2470.56", "valor_presente": "2401.10", "data_emissao": "2026-10-15",
                "inscricao_sacado": "44455566000183", "nome_sacado": "Sacado Exemplo Comércio S.A.",
                "endereco_sacado": "Rua das Flores, 100", "cep_sacado": "01001000",
                "numero_nf": "1234", "chave_nfe": "35261011222333000181550010000012341000012341"}]
}
```

- Field names are the `name` column of `cnab444.py layout`; `defaults` are
  merged under every título; `seq_registro` and the trailer are computed.
- Money: decimal strings (`"2470.56"`, `"2.470,56"`) or `{"cents": 247056}`.
  Integers mean whole reais. Dates: `YYYY-MM-DD`, `DD/MM/YYYY` or `DDMMAA`.
- Header defaults mirror production: `numero_banco` `439`, `nome_banco`
  `ID G. Ad.Ltda` (mixed case preserved — it is what the custodian's own
  files carry).

```bash
python3 tools/cnab444.py generate spec.json --outdir out/           # -> out/CB15100001.REM
python3 tools/cnab444.py generate spec.json --dry-run | head -2       # preview, writes nothing
python3 tools/cnab444.py generate spec.json --style manual --ext TXT  # CBDDMMxx.TXT naming
```

### File naming

Manual: `CBDDMMxx.REM` (or `.TXT`) — `CB` fixed, `DD`/`MM` day/month of
generation, `xx` two alphanumerics (`01`, `AE`, `E1`), e.g. `CB230501.REM`.
Production files use **four** trailing digits = last 4 of `seq_arquivo`
(header 111–117): `CB15104321.REM` for seq `1004321`. The toolkit defaults
to the observed form (`--style observed`); use `--style manual` when the
custodian enforces 8 characters. Humans often prefix a description
(`ORIGINADOR - CEDENTE - espécie - DD-MM-YY - CB….REM`); the validator only
checks the trailing `CB…` part.

## Phase C — Validation and triage

```bash
python3 tools/cnab444.py validate file.REM            # ERROR/WARN per line + field; exit 1 on ERROR
python3 tools/cnab444.py validate --json *.REM
python3 tools/cnab444.py inspect file.REM --summary   # totals, ocorrências, espécies, cedentes
python3 tools/cnab444.py inspect file.REM > spec.json # editable spec; generate(inspect(x)) == x for valid files
```

Checks: 444-byte records, CRLF consistency, ASCII only, constants, blanks
and zeros where fixed, digits in every numeric field, real `DDMMAA` dates,
sequence 000001..N with trailer = N, domain codes (coobrigação, tipo
pessoa, tipo inscrição, ocorrência, espécie), CPF/CNPJ and NF-e key check
digits (WARN), duplicata NF + chave, cheque bank, valor presente ≤ face,
prorrogação rules, filename vs header date/sequence.

To diff two remessas, `inspect` both and diff the JSON — never diff raw
444-byte lines by eye.

## Phase D — Instructions (baixa, prorrogação, recompra, abatimento)

Instructions use the **same layout**; the ocorrência code drives meaning.

- **Prorrogação** (ocorrência `20`): imported in the IDSF portal under
  *Arquivos de baixa*; requires consultoria **and** gestora approval;
  `seu_numero` (38–62) **and** `numero_documento` (111–120) must both equal
  the stock code of the título; `vencimento` (121–126) carries the **new**
  date; **one file per cedente** (validator enforces).
- **Liquidação parcial / baixas / recompra** (`14`, `72`, `74`–`78`, `07`,
  `66`, `68`): fill `valor_pago` (83–92) — if absent the system uses the
  valor presente — and `data_liquidacao` (95–100; required for liquidação).
- **Abatimento** (`04`): fill `valor_abatimento` (206–218).

### Operating windows (manual)

| Activity | Window |
|---|---|
| Instrução de baixa | 08h00–18h00 |
| Importação de cessão (portal IDSF) | 09h00–16h45, liquidação até 18h00 |
| 1º dia útil — liberação de estoques | a partir de 09h30 |
| Baixas D-1 | até 08h30 |

## Anti-patterns

| Anti-pattern | Why it fails | Do instead |
|---|---|---|
| f-string records in a throwaway script | One off-by-one shifts every later field | `generate` from a spec |
| `str(value)[:40]` to "fit" a name | Silent data loss, wrong sacado | Abbreviate deliberately, re-run |
| Writing `COBRANÇA` / `Comércio` | Non-ASCII byte, rejected | Let NFKD normalization strip it |
| Money as float (`2470.56 * 100`) | 247055.99999 → off by a cent | Decimal strings / `{"cents": N}` |
| Negative amounts (`000000-202897`) | Non-numeric field — seen in a real file | Validator flags it; fix the source |
| Reusing `seq_arquivo` | Custodian treats it as duplicate | Monotonic per originador |
| Mixing cedentes in a prorrogação | Rejected by the manual's rule | One file per cedente |
| LF-only or mixed line endings | Importers split records wrong | CRLF everywhere |
| Committing a real `.REM` as a fixture | Leaks CNPJs/NF-e keys of real firms | Synthetic fixtures only |

## Pre-done checklist

- [ ] `cnab444.py validate` → `OK (0 error(s))`; every WARN read and either fixed or explained.
- [ ] `inspect --summary` totals match the source (count, Σ face, Σ presente).
- [ ] File name `CB` + header DDMM + suffix; header `seq_arquivo` never used before.
- [ ] Duplicatas carry NF + 44-digit chave; prorrogação is single-cedente.
- [ ] Generated inside the operating window for the intended import day.
- [ ] No real remessa or personal data was added to the repo.

## REFERENCE

### Header (registro 0)

| Pos | Pic | Field | Content |
|---|---|---|---|
| 1 | 9(1) | Identificação do registro | `0` |
| 2 | 9(1) | Identificação do arquivo remessa | `1` |
| 3–9 | X(7) | Literal remessa | `REMESSA` |
| 10–11 | 9(2) | Código de serviço | `01` |
| 12–26 | X(15) | Literal serviço | `COBRANCA` |
| 27–46 | 9(20) | Código do originador | given by the custodian |
| 47–76 | X(30) | Nome do originador | razão social |
| 77–79 | 9(3) | Número do banco | `439` in production |
| 80–94 | X(15) | Nome do banco | `ID G. Ad.Ltda` in production |
| 95–100 | 9(6) | Data de gravação | DDMMAA (day of the operation) |
| 101–108 | X(8) | Brancos | |
| 109–110 | X(2) | Identificação do sistema | `MX` |
| 111–117 | 9(7) | Nº sequencial do arquivo | |
| 118–438 | X(321) | Brancos | |
| 439–444 | 9(6) | Nº sequencial do registro | `000001` |

### Detalhe (registro 1) — `*` = required

| Pos | Pic | Field |
|---|---|---|
| 1 | 9(1) | `1` |
| 2–20 | X(19) | Débito automático — brancos |
| 21–22 | 9(2) | Coobrigação `01` com / `02` sem * |
| 23–24 | 9(2) | Característica especial (Anexo 8 SCR 3040) |
| 25–28 | 9(4) | Modalidade da operação (Anexo 3) |
| 29–30 | 9(2) | Natureza da operação (Anexo 2) |
| 31–34 | 9(4) | Origem do recurso (Anexo 4) |
| 35–36 | X(2) | Classe de risco (Anexo 17) |
| 37 | 9(1) | `0` |
| 38–62 | X(25) | Nº de controle do participante (seu número), left-aligned * |
| 63–65 | 9(3) | Banco do cheque (required for espécie 51, else `000`) |
| 66–70 | 9(5) | Zeros |
| 71–82 | X(12) | Identificação no banco + dígito — brancos |
| 83–92 | 9(10)v2 | Valor pago (liquidação/baixa/recompra parcial) |
| 93 | 9(1) | Condição papeleta — `0` in production |
| 94 | X(1) | Branco |
| 95–100 | 9(6) | Data da liquidação DDMMAA (liquidação only) |
| 101–108 | X(8) | Brancos |
| 109–110 | 9(2) | Código de ocorrência * |
| 111–120 | X(10) | Nº do documento * |
| 121–126 | 9(6) | Vencimento DDMMAA * |
| 127–139 | 9(11)v2 | Valor de face * |
| 140–142 | 9(3) | Banco encarregado da cobrança / `000` |
| 143–147 | 9(5) | Agência depositária / `00000` |
| 148–149 | 9(2) | Espécie * |
| 150 | X(1) | Branco |
| 151–156 | 9(6) | Data de emissão DDMMAA * |
| 157–158 | 9(2) | 1ª instrução `00` |
| 159 | 9(1) | 2ª instrução `0` |
| 160–161 | 9(2) | Tipo de pessoa do cedente `01` PF / `02` PJ * |
| 162–173 | 9(12) | Zeros |
| 174–192 | X(19) | Nº do termo de cessão * |
| 193–205 | 9(11)v2 | Valor presente / de aquisição * |
| 206–218 | 9(11)v2 | Valor do abatimento |
| 219–220 | 9(2) | Tipo de inscrição do sacado `01` CPF / `02` CNPJ * |
| 221–234 | 9(14) | CPF/CNPJ do sacado, right-aligned * |
| 235–274 | X(40) | Nome do sacado * |
| 275–314 | X(40) | Endereço do sacado * |
| 315–323 | X(9) | Nº da nota fiscal (duplicata *) |
| 324–326 | X(3) | Série da NF |
| 327–334 | 9(8) | CEP * |
| 335–380 | X(46) | Cedente — nome * |
| 381–394 | 9(14) | Cedente — CNPJ * |
| 395–438 | X(44) | Chave NF-e (duplicata *) |
| 439–444 | 9(6) | Nº sequencial do registro |

### Trailer (registro 9)

`9` at 1, blanks 2–438, sequential (= total records) at 439–444.

### Ocorrências

| Code | Movement |
|---|---|
| 01 | Aquisição |
| 11 | Aquisição de contratos futuros |
| 61 | Aquisição de contrato físico |
| 84 | Entrada por recompra (troca de títulos) |
| 12 | Cancelamento de cessão |
| 04 | Abatimento concedido |
| 14 | Liquidação parcial |
| 72 | Recompra parcial sem adiantamento |
| 74 | Baixa por recompra |
| 75 / 76 / 77 | Baixa por depósito do cedente / consultoria / sacado |
| 78 | Baixa de sacado especial |
| 07 | Baixa por prejuízo |
| 68 | Baixa de cheque |
| 66 | Write-off aprovado pelo ADM |
| 20 | Prorrogação de vencimento |

### Espécies

`01` Duplicata · `02` Nota Promissória · `03` Nota de Seguro · `04`
Cobrança Seriada · `05` Recibo · `06` NP Física · `07` Nota Comercial ·
`08` Boleto · `10` Letras de Câmbio · `11` Nota de Débito · `12` Duplicata
de Transporte Digital (CT-e) · `13` Precatórios · `14` Duplicata de Serviço
Física · `15` Duplicata de Serviço **and** Antecipação de Cartão (the manual
lists 15 twice — ask the custodian) · `41` CCB Digital · `42` CCB Assinada ·
`51` Cheque · `57` CPR · `60` Contrato Digital · `61` Contrato Físico · `62`
Confissão de Dívida · `64` Assunção de Dívida · `65` Operação de Cartão de
Crédito Digital · `70` CCB Pré Digital · `71` CCB Pré Balcão · `75` Crédito
Falimentar · `83` CPRF · `88` Write-off / Ação Judicial.

### Manual vs production discrepancies (resolved choices)

| Topic | Manual | Production files | Toolkit choice |
|---|---|---|---|
| Literal serviço | `COBRANÇA` | `COBRANCA` | `COBRANCA` (no-accent rule) |
| Nome do banco | uppercase rule | `ID G. Ad.Ltda` | preserved as-is (header only) |
| File name | `CBDDMMxx` (2-char xx) | `CBDDMM` + 4 digits of seq | both; default observed |
| Field 162–173 | "Tam 011 / X(14)" | 12 zeros | positions win: 12 zeros |
| Pos 93 papeleta | branco | `0` | `0` |
| Termo de cessão | free X(19) | = `seq_arquivo` | caller-supplied; pattern documented |
| Money example | `000000000247056` (15 digits) | 13-digit fields | field width wins |
| Espécie 15 | listed twice | — | accepted; flagged as ambiguous |
| Data liquidação | "obrig. só p/ liquidação" | — | ERROR for 14, WARN for other baixas |

## MCP SURFACE

`tools/cnab444_mcp_server.py` — stdlib-only MCP **stdio** server (newline-
delimited JSON-RPC 2.0; stdout is protocol-only).

```bash
claude mcp add cnab444 -- python3 /ABS/PATH/file-exchange/cnab-444/tools/cnab444_mcp_server.py
```

```json
{ "mcp": { "cnab444": { "type": "local",
  "command": ["python3", "/ABS/PATH/file-exchange/cnab-444/tools/cnab444_mcp_server.py"] } } }
```

| Tool | Purpose | Side effects |
|---|---|---|
| `cnab444_layout` | Field table (optionally one record type) | none |
| `cnab444_codes` | Espécie / ocorrência tables | none |
| `cnab444_filename` | Canonical `CB…` name | none |
| `cnab444_inspect` | `.REM` (path/content) → spec JSON + summary | reads a file |
| `cnab444_validate` | Findings by line/field | reads a file |
| `cnab444_generate` | Spec → content + findings | writes only with `output_dir`; never overwrites; refuses on ERROR |

## Tools

| Script | Use |
|---|---|
| `tools/cnab444.py` | CLI + library: `generate`, `validate`, `inspect`, `filename`, `layout` |
| `tools/cnab444_mcp_server.py` | MCP stdio server over the same library |
| `tools/cnab444-selftest.sh` | Offline regression suite; pass real `.REM` paths as args to round-trip them locally |
| `tools/examples/` | Synthetic spec + its generated `CB15100001.REM` |

## SUBAGENT ORCHESTRATION

| Situation | Agent | Hands off to |
|---|---|---|
| "Generate the remessa for these títulos" / mapping an ERP export | `cnab-444-remessa-generator` | auditor for an independent check |
| "Why was this file rejected?" / validate / diff / inspect | `cnab-444-file-auditor` | generator to regenerate, operator for instructions |
| Prorrogação, baixa, recompra, abatimento, cancelamento | `cnab-444-instructions-operator` | auditor before delivery |

Generator and auditor stay separate lanes: the agent that built a file does
not approve it.
