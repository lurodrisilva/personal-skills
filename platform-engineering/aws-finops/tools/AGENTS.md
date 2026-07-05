<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-07-05 | Updated: 2026-07-05 -->

# tools

## Purpose
Read-only **AWS FinOps triage scripts** shipped with the `aws-finops` skill. Each is a
small `bash` + `aws` wrapper that answers one cost question — where spend goes, what
waste exists, and where rate savings sit — using AWS Cost Explorer, EC2/ELB `describe`,
and Cost Optimization Hub. They are **starting points to review before running**, not a
certified financial report, and they **only read** the estate (`aws ... describe-*` /
`get-*` / `list-*`) — they never provision, buy, resize, detach, release, or remove.
They need only read access (a billing / Cost Explorer read-only + EC2/ELB describe
policy; Cost Optimization Hub opted in for that section). Cost Explorer API calls are
billed ~$0.01 each.

## Key Files
| File | Surfaces |
|------|----------|
| `aws-cost-summary.sh` | top spend by service and by linked account over a period (`aws ce get-cost-and-usage`) |
| `aws-waste-finder.sh` | unattached EBS volumes, unassociated Elastic IPs, stopped EC2, aged snapshots, load balancers to review (regional `describe-*`) |
| `aws-commitment-coverage.sh` | Savings Plans + RI coverage/utilization + Cost Optimization Hub recommendations (`aws ce` / `aws cost-optimization-hub`) |

## For AI Agents

### Working In This Directory
- **Read-only is a hard invariant.** Every `aws` call must be a read — a `describe-*`,
  `get-*`, or `list-*`. Never add a mutating verb — no `create`/`delete`/`modify`/`run`/
  `terminate`/`start`/`stop`/`reboot`/`attach`/`detach`/`associate`/`disassociate`/
  `release`/`allocate`/`purchase`/`put`/`update`/`enable`/`disable`/`register`/
  `deregister`/`authorize`/`revoke`/`reset`/`cancel`/`set`. A "triage" script that
  spends or removes is worse than none. Buying a Savings Plan or deleting a resource is
  always a separate, human-approved change (a wrong delete can destroy a DR asset; a
  wrong 3-year commitment is money you can't get back).
- Each script starts with `set -euo pipefail`, checks `aws` is on `PATH`, and carries a
  header comment stating it is read-only, the IAM read access it needs, and that it is a
  review-before-running starting point.
- Keep them dependency-light: `aws` + POSIX tools. Do **not** require `jq` (use
  `--query` JMESPath / `--output table`). Tolerate empty results / missing opt-in with
  `|| echo`. Cost Explorer is a global endpoint; **EC2/ELB are regional** — the waste
  finder takes `AWS_REGION`.
- Period/scope are overridable via `AWS_CE_START` / `AWS_CE_END` / `AWS_CE_METRIC` /
  `AWS_REGION` / `SNAP_OWNER` (sensible defaults: month-to-date, current Region).

### Testing Requirements
- **Not** covered by `scripts/validate-skills.sh` (it only validates `SKILL.md`).
  Before committing any change here, verify manually:
  1. `bash -n tools/*.sh` (syntax) — and `shellcheck` if available.
  2. No mutating subcommand: `grep -nE 'aws[[:space:]]+[a-z0-9-]+[[:space:]]+(create|delete|modify|run|terminate|start|stop|reboot|attach|detach|associate|disassociate|release|allocate|purchase|put|update|enable|disable|register|deregister|authorize|revoke|reset|cancel|set)' tools/*.sh` returns nothing.
  3. Scripts are executable (`chmod +x`).

### Common Patterns
- Header block (purpose + read-only + IAM + "review before running") → `set -euo
  pipefail` → `aws` presence check → one or more `aws ... describe-*`/`get-*`/`list-*`
  reads with `--query` JMESPath + `--output table` → a short "Goal:" line explaining
  what to do with the output and that every action is a separate, gated change.

## Dependencies

### Internal
- `../SKILL.md` — the `aws-finops` skill; its **REFERENCE** and Phase A/C sections
  document these scripts. `aws-finops-usage-optimizer` owns `aws-waste-finder.sh`;
  `aws-finops-rate-optimizer` owns `aws-commitment-coverage.sh`.

### External
- `aws` CLI (billing / Cost Explorer read-only + EC2/ELB describe; Cost Optimization
  Hub opted in) + POSIX `bash`/`date`. No `jq`. No version pinned.

<!-- MANUAL: -->
