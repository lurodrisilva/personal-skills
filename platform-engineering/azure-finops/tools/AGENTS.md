<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-07-02 | Updated: 2026-07-02 -->

# tools

## Purpose
Read-only **Azure FinOps triage scripts** shipped with the `azure-finops` skill. Each
is a small `bash` + `az` wrapper that answers one cost question — where spend goes,
what waste exists, and where rate savings sit — using Microsoft Cost Management, Azure
Resource Graph (ARG KQL), and Azure Advisor. They are **starting points to review
before running**, not a certified financial report, and they **only read** the estate
(`az ... query` / `list` / `show`) — they never provision, buy, resize, deallocate, or
delete. They need only reader RBAC (**Cost Management Reader** + **Reader**).

## Key Files
| File | Surfaces |
|------|----------|
| `azure-cost-summary.sh` | top spend by service and by resource group over a timeframe (Cost Management query) |
| `azure-waste-finder.sh` | stopped-but-not-deallocated VMs, unattached disks / public IPs / NICs, aged snapshots (ARG KQL) |
| `azure-commitment-coverage.sh` | Advisor COST recommendations + Windows/SQL VMs missing Azure Hybrid Benefit (ARG) |

## For AI Agents

### Working In This Directory
- **Read-only is a hard invariant.** Every `az` call must be a read
  (`query` / `list` / `show`). Never add a mutating verb — no `create`/`delete`/
  `update`/`set`/`deallocate`/`start`/`stop`/`restart`/`purchase`/`add`/`remove`/
  `apply`/`import`/`enable`/`disable`/`cancel`/`move`/`reset`/`regenerate`. A "triage"
  script that spends or deletes is worse than none. Buying a reservation or deleting a
  resource is always a separate, human-approved change (a wrong delete can destroy a DR
  asset; a wrong reservation is money you can't get back).
- Each script starts with `set -euo pipefail`, checks `az` is on `PATH`, and carries a
  header comment stating it is read-only, the RBAC it needs, and that it is a
  review-before-running starting point.
- Keep them dependency-light: `az` + POSIX tools. Do **not** require `jq` (use
  `--query` JMESPath / `-o table`). ARG queries via `az graph query -q`; cost via
  `az costmanagement query`; both may need a one-time local `az extension add`
  (`resource-graph`, `costmanagement`) — that is a local install, not a cloud mutation.
- Scope is overridable via `AZ_SUBSCRIPTION` / `AZ_SCOPE` / `AZ_TIMEFRAME` /
  `AZ_GRAPH_FIRST` (sensible defaults; `az account show` for the current subscription).

### Testing Requirements
- **Not** covered by `scripts/validate-skills.sh` (it only validates `SKILL.md`).
  Before committing any change here, verify manually:
  1. `bash -n tools/*.sh` (syntax) — and `shellcheck` if available.
  2. No mutating subcommand: `grep -nE 'az[[:space:]]+[a-z0-9 -]*[[:space:]](create|delete|update|set|deallocate|start|stop|restart|purchase|add|remove|apply|import|enable|disable|cancel|move|reset|regenerate)([[:space:]]|$)' tools/*.sh` returns nothing.
  3. Scripts are executable (`chmod +x`).

### Common Patterns
- Header block (purpose + read-only + RBAC + "review before running") → `set -euo
  pipefail` → `az` presence check → one or more `az ... query`/`list` reads (ARG KQL in
  single-quoted heredoc-style strings) → a short "Goal:" line explaining what to do with
  the output and that every action is a separate, gated change.

## Dependencies

### Internal
- `../SKILL.md` — the `azure-finops` skill; its **REFERENCE** and Phase C/E sections
  document these scripts. `finops-usage-optimizer` owns `azure-waste-finder.sh`;
  `finops-rate-optimizer` owns `azure-commitment-coverage.sh`.

### External
- `az` CLI (reader RBAC over Cost Management + resources), the `resource-graph` and
  `costmanagement` extensions, and POSIX `bash`/`grep`. No `jq`. No version pinned.

<!-- MANUAL: -->
