<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-07-02 | Updated: 2026-07-02 -->

# karpenter-operations

## Purpose
Skill for **Karpenter** — the just-in-time node-lifecycle autoscaler — across its
**two first-class clouds, Amazon EKS and Azure AKS**. Karpenter provisions right-sized
cloud VMs directly from pending-pod constraints instead of scaling fixed node groups.
Owns the **operating doctrine + the CRD reference + the troubleshooting trees** for both
providers: the shared core API (`NodePool` / `NodeClaim`, `karpenter.sh/v1`), both
NodeClasses (`EC2NodeClass` `karpenter.k8s.aws/v1` and `AKSNodeClass`
`karpenter.azure.com/v1beta1`), install/identity on each cloud (EKS self-hosted; AKS
**Node Auto Provisioning** managed + self-hosted Azure provider), the disruption engine,
observability, and migration. Fourth skill in the `operations/` domain; the
node-lifecycle counterpart to the vendor-neutral `kubernetes-operations`.

## Key Files
| File | Description |
|------|-------------|
| `SKILL.md` | The skill — `name: karpenter-operations`, `domain: operations`, `platform: aws-eks, azure-aks`, `tool: karpenter`, `pattern: node-lifecycle-autoscaling`, `api-versions: karpenter.sh/v1, karpenter.k8s.aws/v1, karpenter.azure.com/v1beta1` |

## Subdirectories
| Directory | Purpose |
|-----------|---------|
| `tools/` | 3 read-only `kubectl` triage scripts (`karpenter-health.sh`, `disruption-blockers.sh`, `nodepool-capacity.sh`), cloud-agnostic; read-only is a hard invariant (see `tools/AGENTS.md`) |

## For AI Agents

### Working In This Directory
- Edit `SKILL.md` (and the read-only `tools/` scripts). Almost every change is authoring.
- **The portability model is the spine:** Karpenter is one project with a shared,
  cloud-neutral core API (`NodePool`/`NodeClaim`) and a **per-cloud provider** that
  supplies a NodeClass + cloud requirement keys. Keep the AWS/Azure split accurate:
  `EC2NodeClass` + `karpenter.k8s.aws/instance-*` vs `AKSNodeClass` +
  `karpenter.azure.com/sku-*`; everything in `spec.disruption`/`limits`/`weight`/
  `expireAfter`/`capacity-type`/`minValues` is identical across clouds.
- **Version discipline is load-bearing:** core + AWS APIs are **v1 GA**; Azure
  `AKSNodeClass` is **`karpenter.azure.com/v1beta1`**; **AKS NAP is evolving**. **State
  behavior, pin NO version, and frame flags / feature gates / image families / NAP
  limitations as "verify against `karpenter.sh/docs` + Microsoft Learn".** Same
  no-version-pin doctrine the `azure-sre-agent` / `dynatrace` / `kubernetes-*` skills follow.
- Keep the **scope boundary** sharp:
  - Generic **HPA / VPA / KEDA** and **Cluster Autoscaler** → `../kubernetes-operations/`
    (`k8s-autoscaling-engineer`). This skill is Karpenter-specific.
  - Cluster upgrades / scheduling / node maintenance → `../kubernetes-operations/`
    (`k8s-cluster-operator`); pod-crash triage → `k8s-workload-troubleshooter`.
  - Security / IRSA / Workload-Identity hardening *strategy* → `../../security/kubernetes-security/`.
  - Agentic **MCP tool-belt + blast-radius doctrine** → `../agentic-k8s-ops/`.
- Highest-blast-radius facts to keep correct: **AWS** spot needs the SQS interruption
  queue + IMDSv2 + pinned AMIs; **Azure NAP** requires Azure-CNI-Overlay+Cilium + a
  managed identity and is mutually exclusive with the cluster autoscaler (no Windows /
  IPv6 / Kubenet / service principal); **never delete the `karpenter.azure.com` CRDs**
  during migration (it deletes NodeClaims → nodes); disruption **budgets don't gate
  Expiration/Interruption**; the `karpenter.sh/termination` finalizer is load-bearing.
- The `description:` uses a `>-` block scalar (colon/backtick-dense) — keep it and
  re-verify `yq '.description | type'` is `!!str` after edits.

### Testing Requirements
- **`scripts/validate-skills.sh` validates this directory** (`operations/` is in
  `DOMAIN_DIRS`): frontmatter (`name`/`description`/`license`/`compatibility`, non-empty
  `metadata` map), non-empty body, even fence count. Run it after edits.
- `tools/` is **not** validator-covered — verify by hand (`bash -n`, the mutating-verb
  grep, executable bit) per `tools/AGENTS.md`.

### Companion Subagents
- Ships a **5-agent Karpenter team** in `../../.claude/agents/` (cloud-agnostic — each
  covers both providers): `karpenter-nodepool-designer` (NodePool + scheduling, AWS
  `instance-*` / Azure `sku-*`), `karpenter-nodeclass-author` (`EC2NodeClass` **and**
  `AKSNodeClass`), `karpenter-disruption-operator` (consolidation/drift/interruption/
  budgets + NAP disable — owns `tools/disruption-blockers.sh`), `karpenter-installer`
  (EKS helm/IAM/SQS + AKS NAP/self-hosted/Workload-Identity + migrations),
  `karpenter-troubleshooter` (Phase-F trees for both clouds — owns the `tools/` scripts).
  The SKILL's "Subagent Orchestration" table maps phase → agent; update both on rename.

### Common Patterns
- CORE PRINCIPLES → the AWS-vs-Azure provider table → TRIAGE MAP → phases A–G (each with
  provider-split subsections where the clouds differ) → anti-patterns → checklist →
  reference → MCP surface → subagent orchestration. Same authoring shape as the sibling
  operations skills.

## Dependencies

### Internal
- `../../scripts/validate-skills.sh` — enforces the SKILL.md contract.
- `../../README.md` — references this skill in the "Operations" table; rename → README update.
- `../../.claude/agents/karpenter-*.md` — the 5 companion subagents.
- `../kubernetes-operations/SKILL.md` (generic autoscaling / cluster ops),
  `../agentic-k8s-ops/SKILL.md` (MCP tool-belt / blast-radius),
  `../../security/kubernetes-security/SKILL.md` (IRSA / Workload-Identity hardening) —
  cross-referenced to keep boundaries sharp.

### External
None at runtime — documentation. Describes Karpenter on EKS + AKS; cites `karpenter.sh/docs`
and `learn.microsoft.com/azure/aks/node-auto-provisioning`. `tools/` scripts need only
`kubectl` (cluster-reader RBAC) + POSIX tools. No version pinned.

<!-- MANUAL: -->
