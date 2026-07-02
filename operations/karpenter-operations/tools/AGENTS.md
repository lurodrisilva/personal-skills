<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-07-02 | Updated: 2026-07-02 -->

# tools

## Purpose
Read-only **Karpenter triage scripts** (EKS + AKS) shipped with the
`karpenter-operations` skill. Each is a small `bash` + `kubectl` wrapper that
surfaces a common operational question about a Karpenter deployment on either
cloud. They are **starting points to review before running**, not a certified
audit, and they **only read** the cluster (`kubectl get`) — they never mutate it.
They need only cluster-reader RBAC over the Karpenter CRDs and core objects. They
are cloud-agnostic (the core `karpenter.sh` API + capacity-type/instance-type
labels are shared); `karpenter-health.sh` additionally probes both provider CRDs
(`ec2nodeclasses.karpenter.k8s.aws`, `aksnodeclasses.karpenter.azure.com`).

## Key Files
| File | Surfaces |
|------|----------|
| `karpenter-health.sh` | controller Deployment/pods (self-hosted), the core + provider CRDs, NodePool / EC2NodeClass / AKSNodeClass / NodeClaim `Ready` conditions |
| `disruption-blockers.sh` | pods/nodes with `karpenter.sh/do-not-disrupt`, PDBs allowing zero disruptions, nodes tainted `karpenter.sh/disrupted` |
| `nodepool-capacity.sh` | per-NodePool `limits` vs `status.resources`, node counts by `karpenter.sh/capacity-type` and instance type |

## For AI Agents

### Working In This Directory
- **Read-only is a hard invariant.** Every `kubectl` call must be `kubectl get`
  (or another non-mutating read). Never add `delete`/`apply`/`patch`/`replace`/
  `edit`/`create`/`scale`/`label`/`annotate`/`drain`/`cordon`/`exec`/… A mutating
  "triage" script is worse than none. (The finalizer break-glass in the SKILL.md
  is deliberately kept out of these scripts.)
- Each script starts with `set -euo pipefail`, checks `kubectl` is on `PATH`, and
  carries a header comment stating it is read-only and needs only cluster-reader
  RBAC, framed as a review-before-running starting point.
- Keep them dependency-light: `kubectl` + POSIX tools (`awk`/`grep`/`sort`/`uniq`).
  Do **not** require `jq` (use `-o custom-columns` / `-o jsonpath`).
- Namespace is overridable via `KARPENTER_NAMESPACE` (default `kube-system`).

### Testing Requirements
- **Not** covered by `scripts/validate-skills.sh` (it only validates `SKILL.md`).
  Before committing any change here, verify manually:
  1. `bash -n tools/*.sh` (syntax) — and `shellcheck` if available.
  2. No mutating subcommand: `grep -nE 'kubectl[[:space:]]+(delete|apply|patch|replace|edit|create|scale|drain|cordon|uncordon|label|annotate|set|expose|run|cp|exec)' tools/*.sh` returns nothing.
  3. Scripts are executable (`chmod +x`).

### Common Patterns
- Header block (purpose + read-only + RBAC + "review before running") → `set -euo
  pipefail` → `kubectl` presence check → one or more `kubectl get … -o custom-columns`
  queries with a short "Goal:" explanation of the healthy target state.

## Dependencies

### Internal
- `../SKILL.md` — the `karpenter-operations` skill; its **REFERENCE** and Phase D/F
  sections document these scripts. `karpenter-troubleshooter` and
  `karpenter-disruption-operator` are the owning subagents.

### External
- `kubectl` (read access to the target cluster, incl. `karpenter.sh`,
  `karpenter.k8s.aws`, and/or `karpenter.azure.com` CRDs) + POSIX
  `bash`/`awk`/`grep`/`sort`/`uniq`. No other dependencies.

<!-- MANUAL: -->
