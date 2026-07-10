<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-07-10 | Updated: 2026-07-10 -->

# tools

## Purpose
Read-only **Crossplane control-plane triage scripts** shipped with the `crossplane`
skill. Each is a small `bash` + `kubectl` wrapper that answers one operability question
about a running control plane — is the core + packages healthy, which managed/composite
resources are stuck, what the safe-start (MRD/MRAP) activation posture is, and whether
packages are fully-qualified + digest-pinned + signed — using only `kubectl get`. They
are **starting points to review before running**, not a certified audit, and they
**only read** the cluster: they never install, activate, apply, patch, sign, or delete.
They need cluster-reader RBAC over `pkg.crossplane.io`, `apiextensions.crossplane.io`,
the provider MR CRDs (`managed` category), and pods/logs in `crossplane-system`.

## Key Files
| File | Surfaces |
|------|----------|
| `crossplane-health-check.sh` | core pods; `providers`/`functions`/`configurations` (INSTALLED/HEALTHY); `providerrevisions` (one Active); `lock` |
| `crossplane-resource-audit.sh` | Managed Resources (`kubectl get managed`) not Ready/Synced; `deletionPolicy: Orphan`; provider-kubernetes `objects` |
| `crossplane-activation-audit.sh` | safe-start posture — MRDs by `state` (Inactive/Active), MRAP `spec.activate` vs `status.activated`, providerrevision `capabilities` |
| `crossplane-package-audit.sh` | Provider/Function/Configuration `spec.package` fully-qualified + `@sha256` digest-pinned; `imageconfigs` (auth/mirror/Cosign) |

## For AI Agents

### Working In This Directory
- **Read-only is a hard invariant.** Every `kubectl` call must be `kubectl get` (or
  another non-mutating read). Never add a mutating verb — no
  `kubectl (apply|patch|delete|edit|replace|create|scale|rollout|annotate|label|cordon|drain|set)`.
  A Crossplane control plane is tier-0 infra: a wrong `apply`/`patch` can activate an
  irreversible MRD, orphan cloud infra, or roll a bad package to every consumer. An
  install / activation / package upgrade / xpkg push is always a separate, human-approved
  action.
- Each script starts with `set -euo pipefail`, checks `kubectl` is on `PATH`, and carries
  a header stating it is read-only, the RBAC it needs, and that it is a
  review-before-running starting point whose output feeds a human-approved change.
- Keep them dependency-light: `kubectl` + POSIX tools (`awk`). Do **not** require `jq`
  (use `-o custom-columns` / `-o jsonpath`). Tolerate empty results / a missing CRD / no
  access with `|| echo`.
- Crossplane v2 MRs and XRs are **namespaced** — the scripts use `-A`. The `managed`
  category matches all provider MRs regardless of group.

### Testing Requirements
- **Not** covered by `scripts/validate-skills.sh` (it only validates `SKILL.md`). Before
  committing any change here, verify manually:
  1. `bash -n tools/*.sh` (syntax) — and `shellcheck` if available.
  2. No mutating `kubectl` verb:
     `grep -nE 'kubectl[[:space:]]+(apply|patch|delete|edit|replace|create|scale|rollout|annotate|label|cordon|drain|set)' tools/*.sh`
     returns nothing.
  3. Scripts are executable (`chmod +x`).

### Common Patterns
- Header block (purpose + read-only + RBAC + "review before running" + "activation/install
  is a separate, human-approved action") → `set -euo pipefail` → `kubectl` presence check
  → one or more `kubectl get … -A` reads with `-o custom-columns` / `-o jsonpath` (+ `awk`
  filtering) → a short "Goal:" line stating the healthy target and that every mutation is
  a separate, gated change.

## Dependencies

### Internal
- `../SKILL.md` — the `crossplane` skill; its **TOOLS** and **MCP SURFACE** sections and
  the phase bodies document these scripts. Ownership: `crossplane-control-plane-operator`
  owns `crossplane-health-check.sh`; `crossplane-managed-resource-author` owns
  `crossplane-resource-audit.sh`; `crossplane-package-publisher` owns
  `crossplane-activation-audit.sh` + `crossplane-package-audit.sh`.

### External
- `kubectl` (read access to `pkg.crossplane.io`, `apiextensions.crossplane.io`, provider
  MR CRDs, and pods in `crossplane-system`) + POSIX `bash`/`awk`. No `jq`. No version
  pinned.

<!-- MANUAL: -->
