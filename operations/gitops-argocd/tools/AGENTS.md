<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-07-07 | Updated: 2026-07-07 -->

# tools

## Purpose
Read-only **Argo CD GitOps triage scripts** shipped with the `gitops-argocd` skill. Each
is a small `bash` + `kubectl` wrapper that answers one delivery question about a fleet of
Argo CD Applications — what's synced/healthy, what has drifted, and how each app's sync
policy is configured — using only `kubectl get` against the `applications.argoproj.io`
CRD. They are **starting points to review before running**, not a certified audit, and
they **only read** the cluster — they never sync, roll back, prune, or otherwise mutate.
They need only cluster-reader RBAC over `applications.argoproj.io` (an Argo CD read-only
role). The `argocd` CLI is **optional** (a read-only `argocd app list`/`get`/`diff`
alternative is noted in a comment); the scripts themselves use only `kubectl`.

## Key Files
| File | Surfaces |
|------|----------|
| `argocd-app-health.sh` | every Application's NAMESPACE/NAME/PROJECT/SYNC/HEALTH/REVISION, plus a count by sync × health (`kubectl get applications.argoproj.io -A -o custom-columns`) |
| `argocd-drift-check.sh` | only the Applications not `Synced` (OutOfSync) or not `Healthy` (Degraded/Progressing/Missing/Suspended), via `kubectl ... -o jsonpath` |
| `argocd-sync-status.sh` | per-Application sync policy (automated? prune? selfHeal?) + sync-wave annotation + last operation phase; and apps *without* automated sync (gated prod) |

## For AI Agents

### Working In This Directory
- **Read-only is a hard invariant.** Every `kubectl` call must be `kubectl get` (or another
  non-mutating read). Never add a mutating verb — no
  `kubectl (apply|patch|delete|edit|replace|create|scale|rollout|annotate|label|cordon|drain|set)`.
  And never add a mutating `argocd` subcommand — no
  `argocd app (sync|delete|create|set|rollback|patch|actions run)` and no
  `argocd (repo|cluster|proj) (add|rm|create|delete|set)`. A "triage" script that syncs or
  rolls back is worse than none: a wrong auto-sync rolls a bad change to the whole fleet; a
  wrong rollback drops the fix. A sync / rollback / cluster registration is always a
  separate, human-approved action.
- Each script starts with `set -euo pipefail`, checks `kubectl` is on `PATH`, and carries a
  header comment stating it is read-only, the RBAC it needs, and that it is a
  review-before-running starting point whose output feeds a human-approved change.
- Keep them dependency-light: `kubectl` + POSIX tools (`awk`/`sort`/`uniq`). Do **not**
  require `jq` (use `-o custom-columns` / `-o jsonpath`). Tolerate empty results / a missing
  CRD / no access with `|| echo`.
- Applications can live in any namespace (apps-in-any-namespace) — the scripts use `-A`.

### Testing Requirements
- **Not** covered by `scripts/validate-skills.sh` (it only validates `SKILL.md`). Before
  committing any change here, verify manually:
  1. `bash -n tools/*.sh` (syntax) — and `shellcheck` if available.
  2. No mutating `kubectl` verb:
     `grep -nE 'kubectl[[:space:]]+(apply|patch|delete|edit|replace|create|scale|rollout|annotate|label|cordon|drain|set)' tools/*.sh`
     returns nothing.
  3. No mutating `argocd` subcommand:
     `grep -nE 'argocd[[:space:]]+(app|repo|cluster|proj)[[:space:]]+(sync|delete|create|set|rollback|patch|add|rm|actions)' tools/*.sh`
     returns nothing.
  4. Scripts are executable (`chmod +x`).

### Common Patterns
- Header block (purpose + read-only + RBAC + "review before running" + "a sync/rollback is
  a separate, human-approved action") → `set -euo pipefail` → `kubectl` presence check →
  one or more `kubectl get applications.argoproj.io -A` reads with `-o custom-columns` /
  `-o jsonpath` → a short "Goal:" line explaining the healthy target state and that every
  action is a separate, gated change.

## Dependencies

### Internal
- `../SKILL.md` — the `gitops-argocd` skill; its **REFERENCE** and Phase B/C/D sections
  document these scripts. Ownership: `argocd-sync-operator` owns `argocd-sync-status.sh`;
  `argocd-drift-health` owns `argocd-drift-check.sh`; `argocd-multicluster` owns
  `argocd-app-health.sh`.

### External
- `kubectl` (read access to `applications.argoproj.io` cluster-wide) + POSIX
  `bash`/`awk`/`sort`/`uniq`. The `argocd` CLI is optional (read-only alternatives only).
  No `jq`. No version pinned.

<!-- MANUAL: -->
