<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-29 | Updated: 2026-06-29 -->

# tools

## Purpose
Read-only Kubernetes **security audit scripts** shipped with the
`kubernetes-security` skill. Each is a small `bash` + `kubectl` wrapper that
surfaces a common high-risk misconfiguration. They are **starting points to
review before running**, not a certified audit, and they **only read** the
cluster (`kubectl get`) — they never mutate it. They need only cluster-reader
RBAC.

## Key Files
| File | Flags |
|------|-------|
| `rbac-audit.sh` | cluster-admin bindings, wildcard rules, privilege-escalation verbs (`escalate`/`bind`/`impersonate`) |
| `psa-coverage.sh` | namespaces without a hardened Pod Security Admission `enforce` level |
| `netpol-coverage.sh` | namespaces with pods but no `NetworkPolicy` (flat / unrestricted) |
| `privileged-workloads.sh` | host-namespace pods, privileged containers, `hostPath` mounts |
| `image-provenance.sh` | containers on mutable tags / `:latest` instead of `@sha256:` digests |

## For AI Agents

### Working In This Directory
- **Read-only is a hard invariant.** Every `kubectl` call must be `kubectl get`
  (or another non-mutating read). Never add `delete`/`apply`/`patch`/`replace`/
  `edit`/`create`/`scale`/`label`/`annotate`/`drain`/`cordon`/`exec`/… A mutating
  "audit" script is worse than none.
- Each script starts with `set -euo pipefail`, checks `kubectl` is on `PATH`, and
  carries a header comment stating it is read-only and needs only cluster-reader
  RBAC, framed as a review-before-running starting point.
- Keep them dependency-light: `kubectl` + POSIX tools (`awk`/`grep`/`sort`). Do
  **not** require `jq` (use `-o jsonpath` / `-o custom-columns`).

### Testing Requirements
- **Not** covered by `scripts/validate-skills.sh` (it only validates `SKILL.md`).
  Before committing any change here, verify manually:
  1. `bash -n tools/*.sh` (syntax) — and `shellcheck` if available.
  2. No mutating subcommand: `grep -nE 'kubectl[[:space:]]+(delete|apply|patch|replace|edit|create|scale|drain|cordon|uncordon|label|annotate|set|expose|run|cp|exec)' tools/*.sh` returns nothing.
  3. Scripts are executable (`chmod +x`).

### Common Patterns
- Header block (purpose + read-only + RBAC + "review before running") → `set -euo
  pipefail` → `kubectl` presence check → one or more `kubectl get … -o jsonpath`
  queries with a short "Goal:" explanation of the secure target state.

## Dependencies

### Internal
- `../SKILL.md` — the `kubernetes-security` skill; its **TOOLS** section documents these scripts and the agents that own them (`rbac-audit` → `k8s-rbac-iam-auditor`, `netpol-coverage` → `k8s-network-zerotrust`, etc.).

### External
- `kubectl` (read access to the target cluster) + POSIX `bash`/`awk`/`grep`. No other dependencies.

<!-- MANUAL: -->
