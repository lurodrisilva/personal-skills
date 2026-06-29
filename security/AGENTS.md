<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-29 | Updated: 2026-06-29 | DEEPINIT: 2026-06-29 -->

# security

## Purpose
Security / hardening / threat-model skills — the fourth CI-validated domain,
parallel to `coding/` (build apps), `platform-engineering/` (build infra), and
`operations/` (run systems). This domain owns the **security discipline**: *why*
controls exist, *how* they fail, and the attack chains they block — distinct from
day-to-day operation. Each subdirectory ships one `SKILL.md` (and may ship
read-only audit scripts under a `tools/` subdir). **This directory IS
CI-validated:** `scripts/validate-skills.sh` walks every domain in its
`DOMAIN_DIRS` array — `coding/`, `platform-engineering/`, `operations/`, and
`security/` — on every push and PR.

## Key Files
None at this level — all content lives in subdirectories.

## Subdirectories
| Directory | Purpose |
|-----------|---------|
| `kubernetes-security/` | Securing/hardening Kubernetes — 4Cs threat model, cluster/etcd/kubelet hardening, secrets, least-privilege RBAC, workload hardening (PSA/securityContext), supply-chain & admission policy, zero-trust microsegmentation, runtime threat detection; ships read-only `tools/` audit scripts + a 5-agent security team in `../.claude/agents/` (see `kubernetes-security/AGENTS.md`) |

## For AI Agents

### Working In This Directory
- This domain is for **securing/hardening**, not building or running. Keep the
  boundary sharp: *running* a cluster (apply RBAC/PSA, drain) →
  `../operations/kubernetes-operations/`; *building* a controller →
  `../platform-engineering/kubernetes-operator-golang/`; CI supply-chain for
  GitHub Actions → `../platform-engineering/github-actions/`. This skill owns the
  *why / how-it-fails / defense-in-depth*.
- Naming convention: descriptive kebab-case, typically `<platform>-security`.
  Directory names are stable references — `README.md` links to them.
- Security skills lead with a **threat model** and reason about *which attack
  chain a control blocks*; state behavior, and **do not pin tool release numbers
  or a single Kubernetes minor** (they rot). Cite the CIS Benchmark and
  kubernetes.io security docs; confirm against the live cluster.
- A skill here may ship a `tools/` subdir of **read-only** helper scripts. Those
  scripts must only read (`kubectl get`), pass `bash -n`, carry a read-only header,
  and be framed as starting points to review before running. `tools/` has its own
  `AGENTS.md`.

### Testing Requirements
- **`scripts/validate-skills.sh` validates this directory** (its `DOMAIN_DIRS`
  array includes `security/`); CI runs it on every push and PR. Per `SKILL.md` it
  checks frontmatter (`name`, `description`, `license`, `compatibility`, non-empty
  `metadata`), a non-empty body, and balanced fences. The validator's orphan loop
  is one level deep (`security/*/`), so a nested `tools/` dir is **not** treated as
  a skill dir — but it is not validated either, so check `tools/*.sh` by hand
  (`bash -n`, read-only).
- After editing frontmatter, confirm `.description` parses as a **string**
  (`yq '.description | type'` → `!!str`); a colon-dense description needs a `>-`
  block scalar.

### Common Patterns
- `metadata:` carries `domain: security` plus `platform:` and `pattern:` (e.g.
  `pattern: defense-in-depth`). Body shape: CORE PRINCIPLES → THREAT MODEL → phases
  (each control tied to the attack it blocks) → anti-patterns (violation → why it's
  exploitable → do instead) → checklist → reference → subagent orchestration.

## Dependencies

### Internal
- `../scripts/validate-skills.sh` — validates this tree (its `DOMAIN_DIRS` includes `security/`); CI runs it on every push and PR. **A missing domain dir is itself a validator error**, so this directory must always contain at least one valid skill.
- `../README.md` — references each skill in the "Security" table; rename → README update required.
- `../.claude/agents/` — the companion `k8s-*` security subagent team (`k8s-cluster-hardener`, `k8s-rbac-iam-auditor`, `k8s-supplychain-admission`, `k8s-network-zerotrust`, `k8s-runtime-threat`).
- `../operations/kubernetes-operations/` & `../platform-engineering/kubernetes-operator-golang/` — the operate/build counterparts this domain cross-references to keep boundaries sharp.

<!-- MANUAL: -->
