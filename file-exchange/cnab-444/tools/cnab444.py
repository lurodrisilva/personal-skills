#!/usr/bin/env python3
"""cnab444.py — CNAB 444 (ID Serviços Financeiros / FIDC) remessa toolkit.

Single source of truth for the 444-byte layout. Stdlib only (Python >= 3.9).

Subcommands
  generate  JSON spec  -> .REM file (CRLF, 444-byte records, header/detail/trailer)
  validate  .REM file  -> findings (exit 1 when any ERROR)
  inspect   .REM file  -> JSON spec (same shape `generate` consumes; round-trips)
  filename  header data -> canonical CB file name
  layout    print the field table (text or --json)

The module is also imported by cnab444_mcp_server.py — keep the public helpers
(LAYOUT, generate_records, render_file, validate_bytes, inspect_bytes,
build_filename) stable.
"""
from __future__ import annotations

import argparse
import datetime as _dt
import json
import re
import sys
import unicodedata
from dataclasses import dataclass, asdict
from decimal import Decimal, InvalidOperation
from pathlib import Path
from typing import Any

RECORD_LEN = 444
EOL = b"\r\n"
ENCODING = "ascii"

# --------------------------------------------------------------------------- #
# Layout
#   kind: C = constant, B = blanks, Z = zeros, N = numeric (right, zero-pad),
#         A = alphanumeric (left, space-pad, uppercase, no accents),
#         M = money in cents (N, 2 implied decimals), D = date DDMMAA (zeros if empty)
# --------------------------------------------------------------------------- #


@dataclass(frozen=True)
class Field:
    name: str
    start: int  # 1-based inclusive
    end: int  # 1-based inclusive
    kind: str
    required: bool = False
    const: str = ""
    default: str = ""
    preserve_case: bool = False
    doc: str = ""

    @property
    def size(self) -> int:
        return self.end - self.start + 1


F = Field

HEADER = (
    F("tipo_registro", 1, 1, "C", True, "0", doc="Identificação do registro header"),
    F("id_arquivo", 2, 2, "C", True, "1", doc="Identificação do arquivo remessa"),
    F("literal_remessa", 3, 9, "C", True, "REMESSA"),
    F("codigo_servico", 10, 11, "C", True, "01"),
    F("literal_servico", 12, 26, "C", True, "COBRANCA", doc="Manual grafa COBRANÇA; sem acento por regra de caracteres"),
    F("codigo_originador", 27, 46, "N", True, doc="Código do originador (consultoria), fornecido pelo custodiante"),
    F("nome_originador", 47, 76, "A", True, doc="Razão social do originador"),
    F("numero_banco", 77, 79, "N", True, default="439", doc="Número do banco (amostras: 439)"),
    F("nome_banco", 80, 94, "A", True, default="ID G. Ad.Ltda", preserve_case=True,
      doc="Nome do banco (amostras: 'ID G. Ad.Ltda', caixa mista preservada)"),
    F("data_gravacao", 95, 100, "D", True, doc="Data do dia da operação DDMMAA"),
    F("brancos_1", 101, 108, "B"),
    F("id_sistema", 109, 110, "C", True, "MX"),
    F("seq_arquivo", 111, 117, "N", True, doc="Nº sequencial do arquivo (amostras: igual aos 4 últimos dígitos do nome CB)"),
    F("brancos_2", 118, 438, "B"),
    F("seq_registro", 439, 444, "N", True, doc="Sempre 000001"),
)

DETAIL = (
    F("tipo_registro", 1, 1, "C", True, "1"),
    F("debito_automatico", 2, 20, "B", doc="Débito automático c/c — brancos"),
    F("coobrigacao", 21, 22, "N", True, doc="01 com coobrigação / 02 sem coobrigação"),
    F("caracteristica_especial", 23, 24, "N", doc="Anexo 8 SCR 3040"),
    F("modalidade_operacao", 25, 28, "N", doc="Anexo 3 SCR 3040"),
    F("natureza_operacao", 29, 30, "N", doc="Anexo 2 SCR 3040"),
    F("origem_recurso", 31, 34, "N", doc="Anexo 4 SCR 3040"),
    F("classe_risco", 35, 36, "A", doc="Anexo 17 SCR 3040"),
    F("zero_37", 37, 37, "Z"),
    F("seu_numero", 38, 62, "A", True, doc="Nº de controle do participante (código do estoque)"),
    F("banco_cheque", 63, 65, "N", doc="Obrigatório p/ cheque, senão 000"),
    F("zeros_66", 66, 70, "Z"),
    F("id_titulo_banco", 71, 81, "B", doc="Identificação do título no banco — branco"),
    F("digito_nosso_numero", 82, 82, "B"),
    F("valor_pago", 83, 92, "M", doc="Valor pago na liquidação/baixa (2 dec); se ausente o sistema usa o valor presente"),
    F("papeleta", 93, 93, "N", doc="Condição p/ emissão de papeleta (amostras: 0)"),
    F("id_papeleta_debito", 94, 94, "B"),
    F("data_liquidacao", 95, 100, "D", doc="DDMMAA — obrigatório só para liquidação/baixa"),
    F("brancos_101", 101, 108, "B"),
    F("ocorrencia", 109, 110, "N", True, doc="Código de ocorrência (01 aquisição, 20 prorrogação, ...)"),
    F("numero_documento", 111, 120, "A", True, doc="Nº do documento (código do estoque)"),
    F("vencimento", 121, 126, "D", True, doc="DDMMAA (na prorrogação: novo vencimento)"),
    F("valor_face", 127, 139, "M", True, doc="Valor de face (2 dec)"),
    F("banco_cobranca", 140, 142, "N", doc="Banco encarregado da cobrança ou 000"),
    F("agencia_depositaria", 143, 147, "N", doc="Agência depositária ou 00000"),
    F("especie", 148, 149, "N", True, doc="Espécie do título (01 duplicata, 07 nota comercial, ...)"),
    F("identificacao_150", 150, 150, "B"),
    F("data_emissao", 151, 156, "D", True, doc="DDMMAA"),
    F("instrucao_1", 157, 158, "N", doc="1ª instrução — 00"),
    F("instrucao_2", 159, 159, "N", doc="2ª instrução — 0"),
    F("tipo_pessoa_cedente", 160, 161, "N", True, doc="01 PF / 02 PJ"),
    F("zeros_162", 162, 173, "Z", doc="Manual diz Tam 011/X(14); posições 162-173 = 12 zeros"),
    F("termo_cessao", 174, 192, "A", True, doc="Nº do termo de cessão (amostras: = seq_arquivo)"),
    F("valor_presente", 193, 205, "M", True, doc="Valor presente / de aquisição (2 dec)"),
    F("valor_abatimento", 206, 218, "M", doc="Valor do abatimento (2 dec)"),
    F("tipo_inscricao_sacado", 219, 220, "N", True, doc="01 CPF / 02 CNPJ"),
    F("inscricao_sacado", 221, 234, "N", True, doc="CPF/CNPJ do sacado"),
    F("nome_sacado", 235, 274, "A", True),
    F("endereco_sacado", 275, 314, "A", True),
    F("numero_nf", 315, 323, "A", doc="Nº da nota fiscal — obrigatório p/ duplicata"),
    F("serie_nf", 324, 326, "A", doc="Série da NF"),
    F("cep_sacado", 327, 334, "N", True),
    F("nome_cedente", 335, 380, "A", True, doc="Cedente: nome (46)"),
    F("cnpj_cedente", 381, 394, "N", True, doc="Cedente: CNPJ (14)"),
    F("chave_nfe", 395, 438, "A", doc="Chave de acesso NF-e (44 dígitos) — obrigatório p/ duplicata"),
    F("seq_registro", 439, 444, "N", True),
)

TRAILER = (
    F("tipo_registro", 1, 1, "C", True, "9"),
    F("brancos", 2, 438, "B"),
    F("seq_registro", 439, 444, "N", True, doc="= total de registros do arquivo"),
)

LAYOUT = {"header": HEADER, "detail": DETAIL, "trailer": TRAILER}

# Fields the generator computes; callers never supply them.
COMPUTED = {"seq_registro"}

ESPECIES = {
    "01": "Duplicata", "02": "Nota Promissória", "03": "Nota de Seguro", "04": "Cobrança Seriada",
    "05": "Recibo", "06": "Nota Promissória Física", "07": "Nota Comercial", "08": "Boleto",
    "10": "Letras de Câmbio", "11": "Nota de Débito", "12": "Duplicata de Transporte Digital (CT-e)",
    "13": "Precatórios", "14": "Duplicata de Serviço Física",
    "15": "Duplicata de Serviço / Antecipação de Cartão (código duplicado no manual)",
    "41": "CCB Digital", "42": "CCB Assinada", "51": "Cheque", "57": "CPR", "60": "Contrato Digital",
    "61": "Contrato Físico", "62": "Confissão de Dívida", "64": "Assunção de Dívida",
    "65": "Operação de Cartão de Crédito Digital", "70": "CCB Pré Digital", "71": "CCB Pré Balcão",
    "75": "Crédito Falimentar", "83": "CPRF", "88": "Write-off / Ação Judicial",
}
DUPLICATA_ESPECIES = {"01"}  # manual: NF + chave NF-e obrigatórias "para duplicata"

OCORRENCIAS = {
    "01": "Aquisição", "04": "Abatimento concedido", "07": "Baixa por prejuízo",
    "11": "Aquisição de contratos futuros", "12": "Cancelamento de cessão",
    "14": "Liquidação parcial", "20": "Prorrogação de vencimento", "61": "Aquisição de contrato físico",
    "66": "Write-off aprovado pelo ADM", "68": "Baixa de cheque", "72": "Recompra parcial sem adiantamento",
    "74": "Baixa por recompra", "75": "Baixa por depósito do cedente", "76": "Baixa por depósito da consultoria",
    "77": "Baixa por depósito do sacado", "78": "Baixa sacado especial",
    "84": "Entrada por recompra (troca de títulos)",
}
ACQUISITION = {"01", "11", "61", "84"}
LIQUIDATION = {"07", "14", "66", "68", "72", "74", "75", "76", "77", "78"}
PRORROGACAO = "20"
FORBIDDEN_CHARS = set("?@")


def _assert_tiling() -> None:
    for kind, fields in LAYOUT.items():
        pos = 1
        for f in fields:
            if f.start != pos or f.end < f.start:
                raise AssertionError(f"layout {kind}: {f.name} starts at {f.start}, expected {pos}")
            pos = f.end + 1
        if pos != RECORD_LEN + 1:
            raise AssertionError(f"layout {kind}: ends at {pos - 1}, expected {RECORD_LEN}")


_assert_tiling()


class CnabError(ValueError):
    """Invalid input for generation."""


# --------------------------------------------------------------------------- #
# Formatting
# --------------------------------------------------------------------------- #


def normalize_text(value: str, *, preserve_case: bool = False) -> str:
    text = unicodedata.normalize("NFKD", str(value))
    text = "".join(c for c in text if not unicodedata.combining(c))
    text = text.replace("\r", " ").replace("\n", " ").replace("\t", " ")
    if not preserve_case:
        text = text.upper()
    return text


def _digits(value: Any) -> str:
    return re.sub(r"\D", "", str(value))


def to_cents(value: Any, field: str) -> int:
    if value is None or value == "":
        return 0
    if isinstance(value, bool):
        raise CnabError(f"{field}: boolean is not an amount")
    if isinstance(value, float):
        raise CnabError(f"{field}: pass amounts as strings or {{\"cents\": int}}, not float {value!r}")
    if isinstance(value, dict) and "cents" in value:
        if not isinstance(value["cents"], int) or isinstance(value["cents"], bool):
            raise CnabError(f"{field}: cents must be an integer, got {value['cents']!r}")
        cents = value["cents"]
    else:
        text = str(value).strip()
        if "," in text:  # Brazilian notation 2.470,56
            if not re.fullmatch(r"\d{1,3}(\.\d{3})*,\d{1,2}|\d+,\d{1,2}", text):
                raise CnabError(f"{field}: {value!r} is not a valid amount (use 2470.56 or 2.470,56)")
            text = text.replace(".", "").replace(",", ".")
        elif re.fullmatch(r"\d{1,3}(\.\d{3})+", text):  # "1.500" — thousands separator or 1.50?
            raise CnabError(f"{field}: {value!r} is ambiguous (thousands separator?); use 1500.00 or 1.500,00")
        try:
            d = Decimal(text)
        except InvalidOperation:
            raise CnabError(f"{field}: {value!r} is not a decimal amount") from None
        if not d.is_finite():
            raise CnabError(f"{field}: {value!r} is not a finite amount")
        if d != d.quantize(Decimal("0.01")):
            raise CnabError(f"{field}: {value!r} has more than 2 decimal places")
        cents = int(d * 100)
    if cents < 0:
        raise CnabError(f"{field}: negative amount {value!r} is not allowed")
    return cents


def to_ddmmaa(value: Any, field: str) -> str:
    if value is None or value == "" or value == "000000":
        return "000000"
    s = str(value).strip()
    try:
        if re.fullmatch(r"\d{4}-\d{2}-\d{2}", s):
            d = _dt.date.fromisoformat(s)
        elif re.fullmatch(r"\d{2}/\d{2}/\d{4}", s):
            d = _dt.datetime.strptime(s, "%d/%m/%Y").date()
        elif re.fullmatch(r"\d{6}", s):
            d = _dt.datetime.strptime(s, "%d%m%y").date()
        else:
            raise ValueError
    except ValueError:
        raise CnabError(f"{field}: {value!r} is not a date (use YYYY-MM-DD, DD/MM/YYYY or DDMMAA)") from None
    return d.strftime("%d%m%y")


PUNCTUATED_FIELDS = frozenset({"inscricao_sacado", "cep_sacado", "cnpj_cedente"})


def format_field(f: Field, value: Any) -> str:
    if f.kind == "C":
        return f.const.ljust(f.size)
    if f.kind == "B":
        return " " * f.size
    if f.kind == "Z":
        return "0" * f.size
    if isinstance(value, str):
        value = value.strip()
    if value is None or value == "":
        value = f.default
    if f.required and (value is None or value == "") and f.name not in COMPUTED:
        raise CnabError(f"{f.name} ({f.start}-{f.end}) is required")
    if f.kind == "M":
        s = str(to_cents(value, f.name))
    elif f.kind == "D":
        s = to_ddmmaa(value, f.name)
    elif f.kind == "N":
        if isinstance(value, (float, bool)):
            raise CnabError(f"{f.name}: {value!r} must be an integer or digit string")
        raw = str(value).strip()
        # punctuation (11.222.333/0001-81, 01310-100) is tolerated only in document/CEP fields
        allowed = r"[\d.\-/ ]" if f.name in PUNCTUATED_FIELDS else r"\d"
        if re.search(rf"(?!{allowed}).", raw):
            raise CnabError(f"{f.name}: {value!r} must be numeric")
        s = _digits(raw)
        if f.required and f.name not in COMPUTED and not s:
            raise CnabError(f"{f.name} ({f.start}-{f.end}) is required")
        s = s or "0"
    else:  # A
        s = normalize_text(value, preserve_case=f.preserve_case).strip()
        bad = [c for c in s if not (32 <= ord(c) < 127) or c in FORBIDDEN_CHARS]
        if bad:
            raise CnabError(f"{f.name}: forbidden character(s) {''.join(sorted(set(bad)))!r} in {value!r}")
        if len(s) > f.size:
            raise CnabError(f"{f.name}: {len(s)} chars exceeds {f.size} ({f.start}-{f.end}): {s!r}")
        return s.ljust(f.size)
    if len(s) > f.size:
        raise CnabError(f"{f.name}: value {s} exceeds {f.size} digits ({f.start}-{f.end})")
    return s.rjust(f.size, "0")


def build_record(fields: tuple[Field, ...], data: dict[str, Any]) -> str:
    known = {f.name for f in fields}
    unknown = sorted(set(data) - known)
    if unknown:
        raise CnabError(f"unknown field(s): {', '.join(unknown)}")
    rec = "".join(format_field(f, data.get(f.name)) for f in fields)
    assert len(rec) == RECORD_LEN, (len(rec), data)
    return rec


# --------------------------------------------------------------------------- #
# Generation
# --------------------------------------------------------------------------- #


def generate_records(spec: dict[str, Any]) -> list[str]:
    """spec = {"header": {...}, "defaults": {...}, "titulos": [{...}, ...]}"""
    if not isinstance(spec, dict) or "header" not in spec or "titulos" not in spec:
        raise CnabError('spec must be an object with "header" and "titulos"')
    titulos = spec["titulos"]
    if not isinstance(titulos, list) or not titulos:
        raise CnabError('"titulos" must be a non-empty list')
    defaults = dict(spec.get("defaults") or {})
    header = dict(spec["header"])
    header["seq_registro"] = 1
    records = [build_record(HEADER, header)]
    for i, t in enumerate(titulos, start=1):
        data = {**defaults, **t, "seq_registro": i + 1}
        try:
            records.append(build_record(DETAIL, data))
        except CnabError as e:
            raise CnabError(f"titulos[{i - 1}]: {e}") from None
    records.append(build_record(TRAILER, {"seq_registro": len(records) + 1}))
    return records


def render_file(records: list[str]) -> bytes:
    return b"".join(r.encode(ENCODING) + EOL for r in records)


def build_filename(data_gravacao: Any, seq_arquivo: Any = None, *, suffix: str | None = None,
                   style: str = "observed", ext: str = "REM") -> str:
    """observed: CB + DDMM + last 4 digits of seq_arquivo (CB15104321)
    manual:   CB + DDMM + 2-char alnum suffix (CB230501)"""
    ddmm = to_ddmmaa(data_gravacao, "data_gravacao")[:4]
    if ext.upper() not in {"REM", "TXT"}:
        raise CnabError("extension must be REM or TXT")
    if suffix is None:
        if seq_arquivo is None:
            raise CnabError("need seq_arquivo or suffix")
        digits = _digits(seq_arquivo).rjust(7, "0")
        suffix = digits[-4:] if style == "observed" else digits[-2:]
    suffix = suffix.upper()
    want = 4 if style == "observed" else 2
    if not re.fullmatch(rf"[A-Z0-9]{{{want}}}", suffix):
        raise CnabError(f"suffix {suffix!r} must be {want} alphanumeric chars for style {style}")
    return f"CB{ddmm}{suffix}.{ext.upper()}"


# --------------------------------------------------------------------------- #
# Parsing / validation
# --------------------------------------------------------------------------- #


def slice_fields(fields: tuple[Field, ...], rec: str) -> dict[str, str]:
    return {f.name: rec[f.start - 1:f.end] for f in fields}


def _decode(f: Field, raw: str) -> Any:
    if f.kind in "CBZ":
        return None
    if f.kind == "M":
        return f"{int(raw) // 100}.{int(raw) % 100:02d}" if raw.isdigit() else raw
    if f.kind == "A":
        return raw.rstrip()
    return raw  # N and D kept verbatim (leading zeros matter for codes)


def cnpj_ok(s: str) -> bool:
    if not re.fullmatch(r"\d{14}", s) or len(set(s)) == 1:
        return False
    def dv(base: str, weights: list[int]) -> str:
        r = sum(int(a) * b for a, b in zip(base, weights)) % 11
        return "0" if r < 2 else str(11 - r)
    w1 = [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]
    d1 = dv(s[:12], w1)
    d2 = dv(s[:12] + d1, [6] + w1)
    return s[12:] == d1 + d2


def cpf_ok(s: str) -> bool:
    s = s[-11:]
    if not re.fullmatch(r"\d{11}", s) or len(set(s)) == 1:
        return False
    for n in (9, 10):
        r = sum(int(s[i]) * (n + 1 - i) for i in range(n)) * 10 % 11 % 10
        if r != int(s[n]):
            return False
    return True


def nfe_key_ok(s: str) -> bool:
    if not re.fullmatch(r"\d{44}", s):
        return False
    total, w = 0, 2
    for c in reversed(s[:43]):
        total += int(c) * w
        w = 2 if w == 9 else w + 1
    r = total % 11
    return int(s[43]) == (0 if r < 2 else 11 - r)


@dataclass
class Finding:
    level: str  # ERROR | WARN
    line: int  # 1-based; 0 = file
    field: str
    message: str

    def __str__(self) -> str:
        where = f"line {self.line}" if self.line else "file"
        return f"{self.level}: {where}" + (f" [{self.field}]" if self.field else "") + f": {self.message}"


def _date_ok(raw: str) -> bool:
    if not (len(raw) == 6 and raw.isdigit()):
        return False
    try:
        _dt.datetime.strptime(raw, "%d%m%y")
        return True
    except ValueError:
        return False


def _check_fields(fields: tuple[Field, ...], rec: str, ln: int, out: list[Finding]) -> dict[str, str]:
    v = slice_fields(fields, rec)
    for f in fields:
        raw = v[f.name]
        if f.kind == "C" and raw != f.const.ljust(f.size):
            out.append(Finding("ERROR", ln, f.name, f"expected {f.const!r}, got {raw!r}"))
        elif f.kind == "B" and raw.strip():
            out.append(Finding("ERROR", ln, f.name, f"positions {f.start}-{f.end} must be blank, got {raw.strip()!r}"))
        elif f.kind == "Z" and raw != "0" * f.size:
            out.append(Finding("ERROR", ln, f.name, f"positions {f.start}-{f.end} must be zeros, got {raw!r}"))
        elif f.kind in "NM" and not raw.isdigit():
            out.append(Finding("ERROR", ln, f.name, f"non-numeric value {raw!r} at {f.start}-{f.end}"))
        elif f.kind == "D" and raw != "000000" and not _date_ok(raw):
            out.append(Finding("ERROR", ln, f.name, f"invalid DDMMAA date {raw!r}"))
        elif f.kind == "D" and raw == "000000" and f.required:
            out.append(Finding("ERROR", ln, f.name, "required date is empty"))
        elif f.kind == "A":
            if f.required and not raw.strip():
                out.append(Finding("ERROR", ln, f.name, "required field is blank"))
            if raw != raw.lstrip() and raw.strip():
                out.append(Finding("WARN", ln, f.name, "alphanumeric field is not left-aligned"))
            if not f.preserve_case and raw != raw.upper():
                out.append(Finding("WARN", ln, f.name, "lowercase characters (manual requires UPPERCASE)"))
            if any(c in FORBIDDEN_CHARS for c in raw):
                out.append(Finding("ERROR", ln, f.name, "forbidden character (? or @)"))
    return v


def validate_bytes(data: bytes, filename: str | None = None) -> list[Finding]:
    out: list[Finding] = []
    try:
        text = data.decode(ENCODING)
    except UnicodeDecodeError as e:
        out.append(Finding("ERROR", 0, "", f"non-ASCII byte at offset {e.start} (accents/Ç are forbidden)"))
        text = data.decode("latin-1")
    crlf, lf = text.count("\r\n"), text.count("\n")
    if crlf == 0:
        out.append(Finding("WARN", 0, "", "no CRLF line endings (samples use CRLF)"))
    elif crlf != lf or text.replace("\r\n", "").count("\r"):
        out.append(Finding("ERROR", 0, "", "mixed line endings (CRLF and bare LF/CR)"))
    if not text.endswith("\n"):
        out.append(Finding("WARN", 0, "", "file does not end with a line break after the trailer"))
    lines = text.replace("\r\n", "\n").split("\n")
    if lines and lines[-1] == "":
        lines.pop()
    if len(lines) < 3:
        out.append(Finding("ERROR", 0, "", f"need header + >=1 detail + trailer, got {len(lines)} record(s)"))
        return out
    for i, rec in enumerate(lines, start=1):
        if len(rec) != RECORD_LEN:
            out.append(Finding("ERROR", i, "", f"record length {len(rec)} != {RECORD_LEN}"))
    if out and any(f.level == "ERROR" and "record length" in f.message for f in out):
        return out

    h = _check_fields(HEADER, lines[0], 1, out)
    cedentes: set[str] = set()
    ocorrs: set[str] = set()
    for i, rec in enumerate(lines[1:-1], start=2):
        if rec[0] != "1":
            out.append(Finding("ERROR", i, "tipo_registro", f"detail records must start with '1', got {rec[0]!r}"))
            continue
        d = _check_fields(DETAIL, rec, i, out)
        oc, esp = d["ocorrencia"], d["especie"]
        ocorrs.add(oc)
        cedentes.add(d["cnpj_cedente"])
        if oc not in OCORRENCIAS:
            out.append(Finding("WARN", i, "ocorrencia", f"code {oc} not in the manual's occurrence table"))
        if esp not in ESPECIES:
            out.append(Finding("WARN", i, "especie", f"code {esp} not in the manual's espécie table"))
        if d["coobrigacao"] not in {"01", "02"}:
            out.append(Finding("ERROR", i, "coobrigacao", "must be 01 (com) or 02 (sem)"))
        if d["tipo_pessoa_cedente"] not in {"01", "02"}:
            out.append(Finding("ERROR", i, "tipo_pessoa_cedente", "must be 01 (PF) or 02 (PJ)"))
        tis, ins = d["tipo_inscricao_sacado"], d["inscricao_sacado"]
        if tis not in {"01", "02"}:
            out.append(Finding("ERROR", i, "tipo_inscricao_sacado", "must be 01 (CPF) or 02 (CNPJ)"))
        elif tis == "02" and not cnpj_ok(ins):
            out.append(Finding("WARN", i, "inscricao_sacado", f"CNPJ {ins} fails check digits"))
        elif tis == "01" and (ins[:3] != "000" or not cpf_ok(ins)):
            out.append(Finding("WARN", i, "inscricao_sacado", f"CPF {ins} fails check digits / not right-aligned"))
        if d["cnpj_cedente"].isdigit() and not cnpj_ok(d["cnpj_cedente"]) and d["tipo_pessoa_cedente"] == "02":
            out.append(Finding("WARN", i, "cnpj_cedente", f"CNPJ {d['cnpj_cedente']} fails check digits"))
        if esp in DUPLICATA_ESPECIES:
            if not d["numero_nf"].strip():
                out.append(Finding("ERROR", i, "numero_nf", "required for duplicata"))
            if not d["chave_nfe"].strip():
                out.append(Finding("ERROR", i, "chave_nfe", "required for duplicata"))
        key = d["chave_nfe"].strip()
        if key and not nfe_key_ok(key):
            out.append(Finding("WARN", i, "chave_nfe", "NF-e access key is not 44 digits with a valid mod-11 DV"))
        if esp == "51" and d["banco_cheque"] == "000":
            out.append(Finding("ERROR", i, "banco_cheque", "required for cheque (espécie 51)"))
        vf, vp = d["valor_face"], d["valor_presente"]
        if vf.isdigit() and int(vf) == 0:
            out.append(Finding("ERROR", i, "valor_face", "must be > 0"))
        if oc in ACQUISITION and vp.isdigit() and int(vp) == 0:
            out.append(Finding("ERROR", i, "valor_presente", "must be > 0 for acquisition"))
        if vf.isdigit() and vp.isdigit() and int(vp) > int(vf):
            out.append(Finding("WARN", i, "valor_presente", "valor presente > valor de face"))
        if oc in LIQUIDATION and d["data_liquidacao"] == "000000":
            level = "ERROR" if oc == "14" else "WARN"  # manual: obrigatório "só para liquidação"
            out.append(Finding(level, i, "data_liquidacao", f"data de liquidação/baixa empty for ocorrência {oc}"))
        if oc == PRORROGACAO and d["seu_numero"].strip() != d["numero_documento"].strip():
            out.append(Finding("ERROR", i, "numero_documento",
                               "prorrogação: seu número (38-62) and nº documento (111-120) must both equal the stock code"))
        if _date_ok(d["vencimento"]) and _date_ok(d["data_emissao"]):
            ven = _dt.datetime.strptime(d["vencimento"], "%d%m%y")
            emi = _dt.datetime.strptime(d["data_emissao"], "%d%m%y")
            if ven < emi:
                out.append(Finding("WARN", i, "vencimento", "vencimento before data de emissão"))
    t = _check_fields(TRAILER, lines[-1], len(lines), out)
    if lines[-1][0] != "9":
        out.append(Finding("ERROR", len(lines), "tipo_registro", "last record must be the trailer ('9')"))
    for i, rec in enumerate(lines, start=1):
        seq = rec[438:444]
        if seq != f"{i:06d}":
            out.append(Finding("ERROR", i, "seq_registro", f"expected {i:06d}, got {seq!r}"))
    if PRORROGACAO in ocorrs and len(cedentes) > 1:
        out.append(Finding("ERROR", 0, "cnpj_cedente", "prorrogação files must contain a single cedente"))
    if PRORROGACAO in ocorrs and ocorrs != {PRORROGACAO}:
        out.append(Finding("WARN", 0, "ocorrencia", "prorrogação mixed with other occurrences in one file"))
    if filename:
        name = Path(filename).name
        m = re.search(r"CB(\d{2})(\d{2})([A-Z0-9]{2,4})\.(REM|TXT)$", name, re.I)
        if not m:
            out.append(Finding("WARN", 0, "filename", f"{name!r} does not end in CBDDMMxx.REM/.TXT"))
        elif h["data_gravacao"][:4] != m.group(1) + m.group(2):
            out.append(Finding("WARN", 0, "filename", f"DDMM in name ({m.group(1)}{m.group(2)}) != header date {h['data_gravacao'][:4]}"))
        elif len(m.group(3)) == 4 and not h["seq_arquivo"].endswith(m.group(3)):
            out.append(Finding("WARN", 0, "filename", f"suffix {m.group(3)} != last digits of seq_arquivo {h['seq_arquivo']}"))
    _ = t
    return out


def inspect_bytes(data: bytes) -> dict[str, Any]:
    text = data.decode("latin-1").replace("\r\n", "\n")
    lines = [l for l in text.split("\n") if l]
    if len(lines) < 3 or lines[0][:1] != "0" or lines[-1][:1] != "9":
        raise CnabError("not a CNAB 444 remessa: need header '0', >=1 detail '1', trailer '9'")
    def section(fields: tuple[Field, ...], rec: str) -> dict[str, Any]:
        return {f.name: _decode(f, rec[f.start - 1:f.end]) for f in fields
                if f.kind not in "CBZ" and f.name not in COMPUTED}
    header = section(HEADER, lines[0])
    titulos = [section(DETAIL, r) for r in lines[1:-1]]
    summary = {
        "records": len(lines),
        "titulos": len(titulos),
        "ocorrencias": sorted({t["ocorrencia"] for t in titulos}),
        "especies": sorted({t["especie"] for t in titulos}),
        "cedentes": sorted({t["cnpj_cedente"] for t in titulos}),
        "total_valor_face": _sum(t["valor_face"] for t in titulos),
        "total_valor_presente": _sum(t["valor_presente"] for t in titulos),
    }
    return {"header": header, "titulos": titulos, "_summary": summary}


def _sum(values) -> str:
    total = Decimal(0)
    for v in values:
        try:
            total += Decimal(v)
        except InvalidOperation:
            pass
    return f"{total:.2f}"


def layout_table() -> list[dict[str, Any]]:
    return [{"record": k, **asdict(f), "size": f.size} for k, fs in LAYOUT.items() for f in fs]


# --------------------------------------------------------------------------- #
# CLI
# --------------------------------------------------------------------------- #


def _load_spec(path: str) -> dict[str, Any]:
    raw = sys.stdin.read() if path == "-" else Path(path).read_text(encoding="utf-8")
    return json.loads(raw)


def cmd_generate(a: argparse.Namespace) -> int:
    spec = _load_spec(a.spec)
    try:
        records = generate_records(spec)
    except CnabError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 2
    data = render_file(records)
    h = spec["header"]
    name = a.output or str(Path(a.outdir) / build_filename(h.get("data_gravacao"), h.get("seq_arquivo"),
                                                         style=a.style, ext=a.ext))
    findings = validate_bytes(data, name)
    for f in findings:
        print(f, file=sys.stderr)
    if any(f.level == "ERROR" for f in findings):
        print("ERROR: generated file failed validation — not written", file=sys.stderr)
        return 1
    if a.dry_run:
        sys.stdout.write(data.decode(ENCODING))
        return 0
    p = Path(name)
    try:  # without --force, "xb" refuses any existing path (incl. a dangling symlink)
        with p.open("wb" if a.force else "xb") as fh:
            fh.write(data)
    except FileExistsError:
        print(f"ERROR: {p} exists (use --force)", file=sys.stderr)
        return 2
    print(f"wrote {p} ({len(records)} records, {len(records) - 2} títulos)")
    return 0


def cmd_validate(a: argparse.Namespace) -> int:
    rc = 0
    for path in a.files:
        findings = validate_bytes(Path(path).read_bytes(), path)
        errs = sum(f.level == "ERROR" for f in findings)
        warns = len(findings) - errs
        if a.json:
            print(json.dumps({"file": path, "errors": errs, "warnings": warns,
                              "findings": [asdict(f) for f in findings]}, ensure_ascii=False))
        else:
            for f in findings:
                if f.level == "ERROR" or not a.quiet:
                    print(f"{path}: {f}")
            print(f"{path}: {'FAIL' if errs else 'OK'} ({errs} error(s), {warns} warning(s))")
        rc |= 1 if errs else 0
    return rc


def cmd_inspect(a: argparse.Namespace) -> int:
    doc = inspect_bytes(Path(a.file).read_bytes())
    if a.summary:
        doc = doc["_summary"]
    print(json.dumps(doc, ensure_ascii=False, indent=2))
    return 0


def cmd_filename(a: argparse.Namespace) -> int:
    try:
        print(build_filename(a.date, a.seq, suffix=a.suffix, style=a.style, ext=a.ext))
    except CnabError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 2
    return 0


def cmd_layout(a: argparse.Namespace) -> int:
    rows = [r for r in layout_table() if not a.record or r["record"] == a.record]
    if a.json:
        print(json.dumps(rows, ensure_ascii=False, indent=2))
        return 0
    for r in rows:
        flag = "*" if r["required"] else " "
        extra = r["const"] or r["default"]
        print(f"{r['record']:<7} {r['start']:>3}-{r['end']:<3} {r['size']:>3} {r['kind']} {flag} "
              f"{r['name']:<24} {extra!s:<14} {r['doc']}")
    return 0


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(prog="cnab444", description="CNAB 444 (ID/FIDC) remessa toolkit")
    sub = p.add_subparsers(dest="cmd", required=True)

    g = sub.add_parser("generate", help="JSON spec -> .REM")
    g.add_argument("spec", help="JSON spec path or - for stdin")
    g.add_argument("-o", "--output", help="exact output path (overrides --outdir naming)")
    g.add_argument("--outdir", default=".", help="directory for the auto-named CB file")
    g.add_argument("--style", choices=["observed", "manual"], default="observed")
    g.add_argument("--ext", choices=["REM", "TXT"], default="REM")
    g.add_argument("--dry-run", action="store_true", help="print to stdout, write nothing")
    g.add_argument("--force", action="store_true", help="overwrite an existing file")
    g.set_defaults(fn=cmd_generate)

    v = sub.add_parser("validate", help="validate .REM files")
    v.add_argument("files", nargs="+")
    v.add_argument("--json", action="store_true")
    v.add_argument("-q", "--quiet", action="store_true", help="hide warnings")
    v.set_defaults(fn=cmd_validate)

    i = sub.add_parser("inspect", help=".REM -> JSON spec")
    i.add_argument("file")
    i.add_argument("--summary", action="store_true")
    i.set_defaults(fn=cmd_inspect)

    n = sub.add_parser("filename", help="canonical CB file name")
    n.add_argument("--date", required=True, help="data de gravação (YYYY-MM-DD or DDMMAA)")
    n.add_argument("--seq", help="seq_arquivo (header 111-117)")
    n.add_argument("--suffix", help="explicit xx suffix")
    n.add_argument("--style", choices=["observed", "manual"], default="observed")
    n.add_argument("--ext", choices=["REM", "TXT"], default="REM")
    n.set_defaults(fn=cmd_filename)

    lay = sub.add_parser("layout", help="print the field table")
    lay.add_argument("--record", choices=["header", "detail", "trailer"])
    lay.add_argument("--json", action="store_true")
    lay.set_defaults(fn=cmd_layout)

    a = p.parse_args(argv)
    try:
        return a.fn(a)
    except (CnabError, OSError, json.JSONDecodeError, UnicodeDecodeError) as e:
        print(f"ERROR: {type(e).__name__}: {e}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
