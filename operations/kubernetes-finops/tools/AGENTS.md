<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-07-04 | Updated: 2026-07-04 -->

# tools

## Purpose
Read-only **Kubernetes FinOps triage scripts** shipped with the `kubernetes-finops`
skill. Each is a small `bash` + `kubectl` wrapper that answers one cost question —
where capacity is wasted, which workloads are over-provisioned, and what is idle/orphaned
— vendor-neutral across EKS / AKS / GKE / on-prem. They are **starting points to review
before running**, not a certified cost report (that is OpenCost / Kubecost on Prometheus),
and they **only read** the cluster (`kubectl get` / `kubectl top`) — they never mutate it.
They need only cluster-reader RBAC; `kubectl top` additionally needs **metrics-server**.

## Key Files
| File | Surfaces |
|------|----------|
| `k8s-cost-allocation.sh` | node utilization (idle signal), per-namespace usage totals, workloads missing the cost label (unallocatable) |
| `k8s-rightsizing-scan.sh` | pod usage vs declared requests, pods with no requests (BestEffort), QoS-class breakdown |
| `k8s-idle-waste.sh` | unbound PVCs, Released/Available PVs, zero-replica Deployments, completed/failed pods |

## For AI Agents

### Working In This Directory
- **Read-only is a hard invariant.** Every `kubectl` call must be `kubectl get` or
  `kubectl top` (or another non-mutating read). Never add `delete`/`apply`/`patch`/
  `replace`/`edit`/`create`/`scale`/`label`/`annotate`/`set`/`drain`/`cordon`/`uncordon`/
  `expose`/`run`/`cp`/`exec`/`rollout`. A "triage" script that resizes, scales, or deletes
  is worse than none — a wrong request cut throttles prod, a wrong PVC delete loses data.
  Every action is a separate, human-approved GitOps change.
- Each script starts with `set -euo pipefail`, checks `kubectl` is on `PATH`, and carries
  a header comment stating it is read-only, the RBAC (+ metrics-server) it needs, and that
  it is a review-before-running starting point.
- Keep them dependency-light: `kubectl` + POSIX tools (`awk`/`grep`/`sort`/`uniq`). Do
  **not** require `jq` (use `-o custom-columns` / `-o jsonpath`). Tolerate missing
  metrics-server / empty results with `|| true` / `|| echo`.
- The cost-label key is overridable via `COST_LABEL` (default `team`).

### Testing Requirements
- **Not** covered by `scripts/validate-skills.sh` (it only validates `SKILL.md`).
  Before committing any change here, verify manually:
  1. `bash -n tools/*.sh` (syntax) — and `shellcheck` if available.
  2. No mutating subcommand: `grep -nE 'kubectl[[:space:]]+(delete|apply|patch|replace|edit|create|scale|drain|cordon|uncordon|label|annotate|set|expose|run|cp|exec|rollout)' tools/*.sh` returns nothing.
  3. Scripts are executable (`chmod +x`).

### Common Patterns
- Header block (purpose + read-only + RBAC + metrics-server + "review before running") →
  `set -euo pipefail` → `kubectl` presence check → one or more `kubectl get`/`top` reads
  with `-o custom-columns` + `awk` filters → a short "Goal:" line explaining the healthy
  target and that every action is a separate, gated change.

## Dependencies

### Internal
- `../SKILL.md` — the `kubernetes-finops` skill; its **REFERENCE** and Phase A/B/D
  sections document these scripts. `k8s-cost-allocator` owns `k8s-cost-allocation.sh`,
  `k8s-rightsizer` owns `k8s-rightsizing-scan.sh`, `k8s-waste-hunter` owns `k8s-idle-waste.sh`.

### External
- `kubectl` (cluster-reader RBAC) + **metrics-server** (for `kubectl top`) + POSIX
  `bash`/`awk`/`grep`/`sort`/`uniq`. No `jq`. No version pinned.

<!-- MANUAL: -->
