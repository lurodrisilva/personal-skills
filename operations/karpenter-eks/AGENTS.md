<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-07-02 | Updated: 2026-07-02 -->

# karpenter-eks

## Purpose
Skill for **Karpenter on Amazon EKS** — the just-in-time node-lifecycle autoscaler
that provisions right-sized EC2 nodes directly from pending-pod constraints instead
of scaling fixed node groups. Owns the **operating doctrine + the CRD reference +
the troubleshooting trees**: `NodePool` / `EC2NodeClass` / `NodeClaim`, the AWS
install/IAM surface, the disruption engine (consolidation / drift / expiration /
interruption), observability, and the Cluster-Autoscaler migration. Fourth skill in
the `operations/` domain; the AWS-node-lifecycle counterpart to the vendor-neutral
`kubernetes-operations`.

## Key Files
| File | Description |
|------|-------------|
| `SKILL.md` | The skill — `name: karpenter-eks`, `domain: operations`, `platform: aws-eks`, `tool: karpenter`, `pattern: node-lifecycle-autoscaling`, `api-versions: karpenter.sh/v1, karpenter.k8s.aws/v1` |

## Subdirectories
| Directory | Purpose |
|-----------|---------|
| `tools/` | 3 read-only `kubectl` triage scripts (`karpenter-health.sh`, `disruption-blockers.sh`, `nodepool-capacity.sh`); read-only is a hard invariant (see `tools/AGENTS.md`) |

## For AI Agents

### Working In This Directory
- Edit `SKILL.md` (and the read-only `tools/` scripts). Almost every change is authoring.
- **Version discipline is the load-bearing rule:** Karpenter's core APIs are **v1 GA**
  (`karpenter.sh/v1`, `karpenter.k8s.aws/v1`) but the release line moves fast. **State
  behavior, pin NO version number in configs, and frame flags / feature gates / AMI
  aliases as "verify against `karpenter.sh/docs`".** Same no-version-pin doctrine the
  `azure-sre-agent` / `dynatrace` / `kubernetes-*` skills follow. Feature-gate stability
  (`SpotToSpotConsolidation`, `NodeRepair`, `NodeOverlay`, `ReservedCapacity`) changes
  between releases — always label it.
- Keep the **scope boundary** sharp:
  - Generic **HPA / VPA / KEDA** and **Cluster Autoscaler** → `../kubernetes-operations/`
    (agent `k8s-autoscaling-engineer`). This skill is Karpenter-specific.
  - Cluster upgrades / scheduling / node maintenance → `../kubernetes-operations/`
    (`k8s-cluster-operator`); pod-crash triage → `k8s-workload-troubleshooter`.
  - Security / IRSA-hardening *strategy*, KMS policy → `../../security/kubernetes-security/`.
  - Agentic **MCP tool-belt + blast-radius doctrine** → `../agentic-k8s-ops/`.
  This skill owns **Karpenter-on-EKS install + NodePool/EC2NodeClass design + disruption
  + troubleshooting**.
- Highest-blast-radius facts to keep correct: spot needs the **SQS interruption queue**
  (`settings.interruptionQueue`); **IMDSv2 required** (`httpTokens: required`, hop 1);
  pin AMIs (floating alias = silent fleet drift); disruption **budgets do not gate
  Expiration/Interruption** (forceful); the `karpenter.sh/termination` finalizer is
  load-bearing (bulk force-removal is break-glass only).
- The `description:` uses a `>-` block scalar (colon/backtick-dense) — keep it and
  re-verify `yq '.description | type'` is `!!str` after edits.

### Testing Requirements
- **`scripts/validate-skills.sh` validates this directory** (`operations/` is in
  `DOMAIN_DIRS`). It checks frontmatter (`name`/`description`/`license`/`compatibility`,
  non-empty `metadata` map), non-empty body, and even fence count. Run it after edits.
- `tools/` is **not** covered by the validator — verify those by hand
  (`bash -n`, the mutating-verb grep, executable bit) per `tools/AGENTS.md`.

### Companion Subagents
- Ships a **5-agent Karpenter-EKS team** in `../../.claude/agents/`:
  `karpenter-nodepool-designer` (NodePool + scheduling), `karpenter-nodeclass-author`
  (EC2NodeClass / AWS shape), `karpenter-disruption-operator` (consolidation / drift /
  interruption / budgets — owns `tools/disruption-blockers.sh`), `karpenter-installer`
  (helm / IAM / SQS / CA migration), `karpenter-troubleshooter` (Phase-F trees — owns
  the `tools/` scripts). The SKILL's "Subagent Orchestration" table maps phase → agent;
  update both sides on rename.

### Common Patterns
- CORE PRINCIPLES (non-negotiable) → TRIAGE MAP → phases A–G (one decision tree + one
  runnable example each) → anti-patterns table → pre-done checklist → reference
  cheat-sheets → MCP surface (read-only) → subagent orchestration. Same authoring shape
  as the sibling operations skills.

## Dependencies

### Internal
- `../../scripts/validate-skills.sh` — enforces the SKILL.md contract.
- `../../README.md` — references this skill in the "Operations" table; rename → README update.
- `../../.claude/agents/karpenter-*.md` — the 5 companion subagents.
- `../kubernetes-operations/SKILL.md` (generic autoscaling / cluster ops),
  `../agentic-k8s-ops/SKILL.md` (MCP tool-belt / blast-radius),
  `../../security/kubernetes-security/SKILL.md` (IRSA/KMS hardening) — cross-referenced
  to keep boundaries sharp.

### External
None at runtime — documentation. Describes Karpenter on EKS; cites `karpenter.sh/docs`.
`tools/` scripts need only `kubectl` (cluster-reader RBAC) + POSIX tools. No version pinned.

<!-- MANUAL: -->
