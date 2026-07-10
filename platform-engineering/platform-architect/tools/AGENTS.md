<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-07-10 | Updated: 2026-07-10 -->

# tools

## Purpose
Read-only **platform-architecture assessment scripts** shipped with the
`platform-architect` skill. Each is a small `bash` wrapper that answers one
strategy/governance question — *are we actually faster (DORA)*, *are our decision
records well-formed (ADR/RFC)*, and *what IDP maturity signals exist* — using only
read commands (`git log`/`tag`, `find`, `grep`, `awk`). They are **starting points
to review before running**, not an approval to change anything, and they **only
read** — they never commit, tag, push, check out, edit, rename, or delete
anything. A metric proxy, a lint warning, and a maturity signal are inputs to a
**human-owned decision**; recording an ADR, changing a golden path, or advancing a
maturity level is always a separate, gated action.

## Key Files
| File | Surfaces |
|------|----------|
| `dora-metrics-report.sh` | DORA four-key **proxies** from git history — deploy-frequency (tags/merges per week), lead-time (commit-age p50/mean), change-fail (revert/hotfix subject share), MTTR (reported as "needs incident data"). Read-only git only. Env: `SINCE_DAYS` (90), `BRANCH`, `TAG_GLOB` (`v*`) |
| `adr-lint.sh` | Lints an ADR/RFC directory against the **MADR** shape — filename `NNNN-`, `# ADR-NNNN:` title, `Status:` value, Context/Decision/Consequences sections, duplicate numbers, dangling `Superseded by`. Read-only; never edits records. Env: `ADR_DIR` (auto: `docs/adr`→`adr`→`docs/decisions`→`docs/rfc`) |
| `platform-maturity-scan.sh` | Heuristic **presence** scan for IDP building blocks (catalog-info.yaml, scaffolder templates, IaC modules, CI, GitOps, policy-as-code, secrets, observability, SLOs, ADRs, RFCs, tech radar) → coarse CNCF-model scorecard. Presence != quality. Read-only. Env: `ROOT` (`.`) |

## For AI Agents

### Working In This Directory
- **Read-only is a hard invariant.** Every command must read: `git log`, `git tag`,
  `git rev-list`, `git for-each-ref`, `git symbolic-ref`, `git rev-parse`, `find`,
  `grep`, `awk`, `sed` (non-in-place). **Never** add a mutating verb: no `git
  commit`, `git tag -a/-d`, `git push`, `git checkout`/`switch`, `git reset`, `git
  rebase`, `git branch`, `git stash`, and no filesystem writes (`>`/`>>` to repo
  files, `mkdir`/`rm`/`mv`/`cp` into the tree, `sed -i`, `tee`). A "scan" script
  that writes is worse than none: the whole point is that decisions stay human-gated.
- Each script starts with `set -euo pipefail`, checks its prerequisites (`git` on
  `PATH` / inside a work tree; target dir exists), and carries a header comment
  stating it is read-only, that its output is a **proxy/heuristic starting point**,
  and that recording/acting on the result is a separate, human-owned decision.
- Keep them dependency-light: `git` + POSIX tools (`find`/`grep`/`awk`/`sed`). Do
  **not** require `jq`, `yq`, or any network call. Tolerate empty repos / missing
  dirs with `|| true` and a friendly message, not a crash.
- Honesty is load-bearing here: DORA figures are **proxies**, not audited metrics
  (real numbers come from CI/CD + incident systems); maturity signals are
  **presence, not quality**. Keep the "this is a starting point" framing in output.

### Testing Requirements
- **Not** covered by `scripts/validate-skills.sh` (it only validates `SKILL.md`).
  Before committing any change here, verify manually:
  1. `bash -n tools/*.sh` (syntax) — and `shellcheck` if available.
  2. No mutating verb — this grep returns nothing (note `git tag --list`/`-l` is
     read-only; only the create/delete/force/sign flags `-a`/`-d`/`-f`/`-s` mutate):
     `grep -nE '(git[[:space:]]+(commit|push|tag[[:space:]]+-[adfs]|checkout|switch|reset|rebase|branch|stash))|sed[[:space:]]+-i|[[:space:]](rm|mv|cp)[[:space:]]|tee[[:space:]]' tools/*.sh`
  3. Scripts are executable (`chmod +x`).

### Common Patterns
- Header block (purpose + read-only + "proxy/heuristic starting point" + "acting on
  it is a separate human-owned decision") → `set -euo pipefail` → prereq checks →
  one or more read commands → defensive `grep`/`awk` parsing (tolerate empty) → a
  short "Goal:" line explaining what to do with the output and that every decision
  is human-gated.

## Dependencies

### Internal
- `../SKILL.md` — the `platform-architect` skill; its **REFERENCE**, Phase D, E, and
  F sections document these scripts. `developer-experience-lead` reads
  `dora-metrics-report.sh`; `governance-standards-author` owns `adr-lint.sh`;
  `platform-maturity-assessor` owns `platform-maturity-scan.sh`.

### External
- `git` on `PATH` (for `dora-metrics-report.sh`) + POSIX `bash`/`find`/`grep`/`awk`.
  No `jq`, no `yq`, no network. No version pinned.

<!-- MANUAL: -->
