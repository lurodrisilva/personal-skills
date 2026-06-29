<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-29 | Updated: 2026-06-29 -->

# kubernetes-security

## Purpose
Skill that guides **securing / hardening** Kubernetes — the security discipline:
the 4Cs threat model, cluster/kubelet/etcd hardening, secrets, least-privilege
RBAC & identity, workload hardening (Pod Security Admission + `securityContext`),
software-supply-chain & admission policy, zero-trust network microsegmentation,
and runtime threat detection. It owns *why* controls exist, *how* they fail, and
the attack chains they block. First skill in the `security/` domain; ships
read-only audit scripts under `tools/`.

## Key Files
| File | Description |
|------|-------------|
| `SKILL.md` | The skill definition — `name: kubernetes-security`, `domain: security`, `pattern: defense-in-depth`, `platform: kubernetes`, `surfaces: threat-model, cluster-hardening, secrets, rbac-identity, workload-hardening, supply-chain-admission, network-zerotrust, runtime-threat, compliance` |

## Subdirectories
| Directory | Purpose |
|-----------|---------|
| `tools/` | Read-only `kubectl`-based audit scripts referenced by the skill (see `tools/AGENTS.md`) |

## For AI Agents

### Working In This Directory
- Edit `SKILL.md`; add/maintain `tools/*.sh` (read-only only).
- This is the **secure/harden/threat-model** skill — keep the scope boundary:
  - *Run* a cluster day-to-day → `../../operations/kubernetes-operations/` (its Phase G is operational RBAC/PSA; this skill owns *why/how-it-fails/defense-in-depth*).
  - *Build* a controller → `../../platform-engineering/kubernetes-operator-golang/`.
  - GitHub Actions supply-chain CI → `../../platform-engineering/github-actions/`.
  - Edge authN/authZ at a gateway → `../../platform-engineering/auth0-kong-authZ-authN/`.
- The **CORE PRINCIPLES** and **THREAT MODEL** are the load-bearing review gate.
  Every control should answer "which attack chain does this block?". Highest-blast-radius
  facts to keep correct:
  - PodSecurityPolicy is **removed** → Pod Security Admission (PSA GA) is the mechanism.
  - **ValidatingAdmissionPolicy** (CEL, in-tree) is GA — the webhook-free admission option.
  - **NetworkPolicy egress** is GA — default-deny egress is production-safe.
  - **`seccompProfile: RuntimeDefault` on a pod needs NO kubelet flag** (the kubelet `--seccomp-default` flag only sets the cluster-wide default for pods that don't specify one). Do not regress this to "requires the flag".
  - etcd Secrets are **not** encrypted at rest by default → `EncryptionConfiguration` (KMS preferred); the `identity` provider must be **last**.
  - Falco = CNCF-graduated; Calico/Cilium are production CNIs.
- **Do NOT pin tool release numbers or dated CVE incidents** (the source research
  was contaminated with post-cutoff specifics like "Trivy v0.43.0", "Gatekeeper
  v3.22.0", "trivy-action compromised March 2026"). State capabilities and the
  stable GA anchors; say "pin tools/actions by digest" generically.
- The `description:` uses a `>-` YAML block scalar **on purpose** (colon- and
  backtick-dense). Keep it; re-verify `yq '.description | type'` is `!!str` after editing.

### Testing Requirements
- **`scripts/validate-skills.sh` validates this directory** (`DOMAIN_DIRS` includes
  `security/`). It checks frontmatter, non-empty body, and even fences
  (`grep -c '^```' SKILL.md`). Positive **and** negative check after structural
  edits: break a required field → validator must FAIL naming this skill; restore.
- `tools/*.sh` are **not** validated by CI — check them manually: `bash -n`,
  `shellcheck`, and confirm every `kubectl` call is read-only (`get`), never a
  mutating subcommand (`delete`/`apply`/`patch`/`create`/`label`/…).

### Companion Subagents
- Orchestrated by five repo-scoped subagents in `../../.claude/agents/`:
  `k8s-cluster-hardener`, `k8s-rbac-iam-auditor`, `k8s-supplychain-admission`,
  `k8s-network-zerotrust`, `k8s-runtime-threat`. The "Subagent Orchestration" table
  at the end of `SKILL.md` maps surfaces → agents (threat-model first, then all
  five for defense in depth). Rename a surface or agent → update both sides.
  Note: these are distinct from the operations team's `k8s-*` agents (different names).

### Common Patterns
- CORE PRINCIPLES → THREAT MODEL & 4Cs → phases (cluster hardening + secrets →
  RBAC/identity → workload hardening → supply-chain & admission → network
  zero-trust → runtime → managed example) → TOOLS (shipped scripts + external
  playbook) → anti-patterns → checklist → reference → orchestration.

## Dependencies

### Internal
- `../../scripts/validate-skills.sh` — enforces the frontmatter + body + fenced-block contract.
- `../../README.md` — references this skill in the "Security" table; rename → README update required.
- `../../.claude/agents/k8s-cluster-hardener.md` (+ the other four `k8s-*` security agents) — the companion subagents this skill delegates to.
- `tools/` — the read-only audit scripts the skill references (rbac-audit, psa-coverage, netpol-coverage, privileged-workloads, image-provenance).
- `../../operations/kubernetes-operations/SKILL.md` — the operate counterpart (Phase G overlap is intentional and cross-referenced, not duplicated).

### External
None at runtime — this is documentation + read-only helper scripts. The skill
*describes* the Kubernetes security ecosystem (kube-bench, Trivy, Cosign,
Gatekeeper/Kyverno, Falco/Tetragon, Calico/Cilium) but does not depend on them
being installed in this repo. Cites **kubernetes.io** security docs + the **CIS
Kubernetes Benchmark**.

<!-- MANUAL: -->
