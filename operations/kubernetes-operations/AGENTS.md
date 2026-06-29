<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-29 | Updated: 2026-06-29 -->

# kubernetes-operations

## Purpose
Skill that guides **operating** Kubernetes — Day-2 / SRE work on clusters and
workloads that already exist: incident triage (failing Pods, rollouts), capacity
(requests/limits, QoS, quotas), scheduling & placement, autoscaling, node
maintenance and version-skew-aware upgrades, RBAC + Pod-security hardening,
networking & DNS debugging, storage/PVC operations, and observability. Its spine
is the **TRIAGE MAP** (read Events + `describe` + `logs --previous` before acting)
and the per-surface decision trees (CrashLoopBackOff / Pending / service-not-
reachable / PVC-Pending). The first skill in the `operations/` domain.

## Key Files
| File | Description |
|------|-------------|
| `SKILL.md` | The skill definition — `name: kubernetes-operations`, `domain: operations`, `pattern: day2-operations`, `platform: kubernetes`, `surfaces: workload-triage, rollouts, resources-qos, scheduling, autoscaling, disruptions-upgrades, rbac-podsecurity, networking, storage, observability` |

## Subdirectories
None.

## For AI Agents

### Working In This Directory
- Edit `SKILL.md` only.
- This is the **operate** skill — keep the scope boundary intact:
  - Build a controller/CRD → `../../platform-engineering/kubernetes-operator-golang/`.
  - Build a control plane → `../../platform-engineering/crossplane/`.
  - Consume platform building blocks → `../../platform-engineering/addons-and-building-blocks/`.
  - Vendor observability query languages → `../../platform-engineering/dynatrace/` (DQL), `../../platform-engineering/kusto-kql-api/` (KQL).
- The **CORE PRINCIPLES** and the **TRIAGE MAP** are the load-bearing review gate —
  don't soften them. Lead with decision-trees, one runnable example per surface;
  field-level specs belong behind a **kubespec.dev** citation, not enumerated.
- **Version discipline (highest-rot risk):** state *behavior*, don't pin a single
  Kubernetes minor in prose. Facts that were deliberately set and must stay correct:
  - **PodSecurityPolicy is removed** → Pod Security Admission is the mechanism.
  - **HPA is `autoscaling/v2`**; the resource Metrics API is **`metrics.k8s.io/v1beta1`** (not `v1`).
  - **Ingress is GA but feature-frozen**; **Gateway API** is the successor (core kinds GA).
  - **EndpointSlices** (`discovery.k8s.io/v1`) replace the deprecated Endpoints API.
  - **nftables** kube-proxy mode exists but is **not the universal default** — say "verify per cluster".
  - **exit 137 = OOMKilled**; memory-limit → OOMKilled, CPU-limit → throttled (not killed).
  - Node-pressure eviction **ignores PDBs**; API-initiated eviction (drain) **honors** them.
  - Karpenter is a "CNCF project" (don't overstate the maturity label).
- The `description:` uses a `>-` YAML block scalar **on purpose** (it is colon- and
  backtick-dense). Keep the block scalar and re-verify `yq '.description | type'`
  is `!!str` after editing.

### Testing Requirements
- **`scripts/validate-skills.sh` validates this directory** (`DOMAIN_DIRS` includes
  `operations/`); CI runs it on every push and PR. It checks:
  1. Frontmatter parses and contains `name`, `description`, `license`, `compatibility`, non-empty `metadata` map.
  2. Body after the closing `---` is non-empty.
  3. Fenced code-block markers are even — this skill ships many bash/yaml/dql blocks; `grep -c '^```' SKILL.md` must be even.
- Positive **and** negative check the validator after structural edits: break a
  required field, confirm the validator FAILS and names this skill, then restore —
  a typo'd `DOMAIN_DIRS` entry would otherwise pass green and skip the file.

### Companion Subagents
- Orchestrated by five repo-scoped subagents in `../../.claude/agents/`:
  `k8s-workload-troubleshooter`, `k8s-cluster-operator`, `k8s-autoscaling-engineer`,
  `k8s-security-rbac`, `k8s-network-storage`. The "Subagent Orchestration" table at
  the end of `SKILL.md` maps surfaces → agents (troubleshooter triages, then hands
  to the owning specialist). Rename a surface or agent → update both sides.

### Common Patterns
- "CORE PRINCIPLES (NON-NEGOTIABLE)" numbered list + a TRIAGE MAP, then
  surface-by-surface phases (workload triage → rollouts → resources/QoS →
  scheduling → autoscaling → disruptions/upgrades → security → networking →
  storage → observability), each with a decision tree and one runnable example,
  closing with an anti-patterns table and a pre-done checklist — same authoring
  shape as the `platform-engineering` skills.

## Dependencies

### Internal
- `../../scripts/validate-skills.sh` — enforces the frontmatter + body + fenced-block contract.
- `../../README.md` — references this skill in the "Operations" table; rename → README update required.
- `../../.claude/agents/k8s-*.md` — the five companion subagents this skill delegates to.
- `../../platform-engineering/kubernetes-operator-golang/SKILL.md` & `../../platform-engineering/crossplane/SKILL.md` — the **build** counterparts; this skill cross-references them to keep the operate-vs-build boundary sharp.

### External
None at runtime — this is documentation, not code. The skill *describes* `kubectl`,
the Kubernetes API, and the surrounding ecosystem (metrics-server, autoscalers,
CSI, Gateway API) but does not depend on them being installed in this repo. Cites
**kubernetes.io** (canonical behavior) and **kubespec.dev** (exact field specs).

<!-- MANUAL: -->
