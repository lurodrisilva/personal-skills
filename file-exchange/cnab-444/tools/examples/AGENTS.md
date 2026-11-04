<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-11-04 | DEEPINIT: 2026-11-04 -->

# examples

## Purpose
Synthetic fixtures for the `cnab-444` toolkit. The repo is public: nothing
here comes from a real remessa.

## Key Files
| File | Description |
|------|-------------|
| `remessa-duplicata.json` | Input spec for `cnab444.py generate`: fake cedente/sacado CNPJs with valid check digits, valid-DV NF-e keys, accented names that exercise normalization |
| `CB15100001.REM` | Generated output of that spec (CRLF, 444-byte records); `cnab444-selftest.sh` asserts byte-identity |

## For AI Agents

### Working In This Directory
- Never add real `.REM` files, CNPJs, names, addresses or NF-e keys.
  Test real files by passing their paths to `../cnab444-selftest.sh`.
- Edit the JSON, then regenerate the `.REM` with
  `python3 ../cnab444.py generate remessa-duplicata.json --force -o .` —
  only when the layout change is intended.

### Testing Requirements
- `bash ../cnab444-selftest.sh` must end `ALL SELFTESTS PASSED`.
