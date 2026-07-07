<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-07-07 | Updated: 2026-07-07 -->

# tools

## Purpose
Read-only **Terraform / OpenTofu triage scripts** shipped with the `terraform-iac`
skill. Each is a small `bash` + `terraform` (falling back to `tofu`) wrapper that
answers one lifecycle question — what would this plan change, what does this config
manage, and has reality drifted from state — using only Terraform's own read/plan
verbs. They are **starting points to review before running**, not an approval to
change anything, and they **only read / plan** (`validate`, `plan`,
`plan -refresh-only`, `version`, `providers`, `workspace list`, `state list`,
`output`) — they never `apply`, `destroy`, `import`, `taint`, or touch state. A plan
does not change infrastructure; **apply is always a separate, human-approved
change.** They need the same provider read access an apply would (to refresh + diff)
and must be run **after a human has run `terraform init`**.

## Key Files
| File | Surfaces |
|------|----------|
| `tf-plan-summary.sh` | `terraform validate` then `terraform plan -detailed-exitcode -no-color`; summarizes add/change/**destroy**/replace counts and the exit code (0=no-change / 1=error / 2=changes). Read-only — plan does not apply. Env: `TF_DIR` (default `.`) |
| `tf-state-inventory.sh` | `terraform version` / `providers` / `workspace list` / `state list` (+ optional `output` via `SHOW_OUTPUTS=1`). No state mutation. Env: `TF_DIR` |
| `tf-drift-check.sh` | `terraform plan -refresh-only -detailed-exitcode -no-color` — real infra vs state; reports drifted resources (exit 2 = drift). No apply, no state write. Env: `TF_DIR` |

## For AI Agents

### Working In This Directory
- **Read-only is a hard invariant.** Every `terraform`/`tofu` call must be a read or
  a plan — `validate`, `plan`, `plan -refresh-only`, `version`, `providers`,
  `workspace list`, `state list`, `output`. **Never** add a mutating verb: no
  `apply`, `destroy`, `import`, `state mv`, `state rm`, `state push`,
  `state replace-provider`, `taint`, `untaint`, `workspace new`, `workspace delete`,
  `force-unlock`, or an `init` that writes/migrates a backend. A "triage" script
  that applies or rewrites state is worse than none. `apply`, `destroy`, and any
  state surgery are always a separate, human-approved change (a wrong destroy drops
  a prod resource; a `state rm`/`push` rewrites the source of truth with no undo).
- Each script starts with `set -euo pipefail`, resolves `terraform` (falling back to
  `tofu`) on `PATH`, and carries a header comment stating it is read-only, the
  access it needs, that it must run after a human `terraform init`, and that apply is
  a separate human-approved change.
- Keep them dependency-light: `terraform`/`tofu` + POSIX tools. Do **not** require
  `jq` — prefer Terraform's own flags (`-json`, `-detailed-exitcode`, `-no-color`)
  and parse with `grep`/`awk`. Tolerate empty/uninitialized state with `|| echo`.
- Scope is overridable via `TF_DIR` (default `.`, passed as `-chdir=`) and
  `SHOW_OUTPUTS` (default off, since outputs can be sensitive).

### Testing Requirements
- **Not** covered by `scripts/validate-skills.sh` (it only validates `SKILL.md`).
  Before committing any change here, verify manually:
  1. `bash -n tools/*.sh` (syntax) — and `shellcheck` if available.
  2. No mutating verb — both greps return nothing:
     `grep -nE 'terraform[[:space:]]+(apply|destroy|import|taint|untaint|force-unlock)' tools/*.sh`
     and `grep -nE 'state[[:space:]]+(mv|rm|push)' tools/*.sh`.
  3. Scripts are executable (`chmod +x`).

### Common Patterns
- Header block (purpose + read-only + access needed + "run after `terraform init`" +
  "apply is a separate human-approved change") → `set -euo pipefail` →
  `terraform`/`tofu` resolution → one or more read/plan verbs with `-no-color`
  (+ `-detailed-exitcode` where a code matters) → defensive `grep`/`awk` parsing →
  a short "Goal:" line explaining what to do with the output and that every mutation
  is a separate, gated change.

## Dependencies

### Internal
- `../SKILL.md` — the `terraform-iac` skill; its **REFERENCE**, Phase D, and Phase
  B/F sections document these scripts. `terraform-plan-reviewer` owns
  `tf-plan-summary.sh`; `terraform-state-operator` owns `tf-state-inventory.sh` +
  `tf-drift-check.sh`.

### External
- `terraform` (or OpenTofu `tofu`) on `PATH`, with provider read access to the
  configured backend/state, run after a human `terraform init` + POSIX `bash`/`grep`/
  `awk`. No `jq`. No version pinned.

<!-- MANUAL: -->
