<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-29 | Updated: 2026-07-07 | DEEPINIT: 2026-07-04 -->

# operations

## Purpose
Day-2 / SRE skills for **operating running systems** — the third CI-validated
domain, parallel to `coding/` (build apps) and `platform-engineering/` (build
infra). Where those domains are about *creating* software and platforms, this
domain is about *running* them: incident triage, capacity, scaling, maintenance,
upgrades, security, and recovery on systems that already exist. Each subdirectory
ships one `SKILL.md` that Claude Code / opencode auto-loads when a project matches
its `description`. **This directory IS CI-validated:** `scripts/validate-skills.sh`
walks every domain in its `DOMAIN_DIRS` array — `coding/`, `platform-engineering/`,
`operations/`, `security/`, and `networking/` — on every push and PR.

## Key Files
None at this level — all content lives in subdirectories.

## Subdirectories
| Directory | Purpose |
|-----------|---------|
| `kubernetes-operations/` | Day-2 Kubernetes operations (SRE) — kubectl triage & Pod-failure decision trees, rollouts, resources/QoS, scheduling, autoscaling, disruptions/drain/upgrades, RBAC + Pod Security, networking, storage, observability; ships a 5-agent ops team in `../.claude/agents/` (see `kubernetes-operations/AGENTS.md`) |
| `azure-sre-agent/` | **Azure SRE Agent** (Preview) — Microsoft's AI-assisted SRE agent: the 6 extension primitives, the MCP-connector model (transports / auth / 80-tool budget), and the **propose-then-approve / Permission gate** doctrine; ships a 5-agent companion team in `../.claude/agents/` (see `azure-sre-agent/AGENTS.md`) |
| `agentic-k8s-ops/` | Umbrella playbook for AI-assisted SRE on K8s/Azure — the **Detect→Decide→Act** pattern, the credible **MCP tool-belt** (with read-only guardrails per server), and the **blast-radius doctrine**; coordinates the other skills rather than duplicating them (see `agentic-k8s-ops/AGENTS.md`) |
| `karpenter-operations/` | **Karpenter on Amazon EKS + Azure AKS** — just-in-time node-lifecycle autoscaling across both first-class clouds: shared core API (`NodePool` / `NodeClaim`) + per-cloud NodeClass (`EC2NodeClass` / `AKSNodeClass`), install/identity (EKS self-hosted; AKS **Node Auto Provisioning** managed + self-hosted), the disruption engine, observability, and troubleshooting trees; ships 3 read-only triage scripts under `tools/` and a 5-agent team in `../.claude/agents/` (see `karpenter-operations/AGENTS.md`) |
| `kubernetes-finops/` | **FinOps on Kubernetes** (vendor-neutral, EKS/AKS/GKE/on-prem) — the container cost model (allocated/idle/shared split on `max(request,usage)`), cost allocation via **OpenCost**/**Kubecost**, right-sizing (requests vs limits, QoS, VPA/Goldilocks/KRR), autoscaling + node efficiency (HPA/VPA/KEDA + bin-packing + Spot), waste elimination, and governance (ResourceQuota/LimitRange + admission policy); ships 3 read-only `kubectl` scripts under `tools/` and a 5-agent team in `../.claude/agents/` (see `kubernetes-finops/AGENTS.md`) |
| `gitops-argocd/` | **GitOps continuous delivery** with **Argo CD** (primary) + **Flux** (sibling) — Git as the single source of truth; `Application`/`AppProject`/multi-source, the sync engine (policy/waves/hooks, `prune`/`selfHeal`), health + drift (custom-Lua health, `ignoreDifferences`, OutOfSync triage), multi-cluster **ApplicationSet** fan-out + RBAC/SSO tenancy, progressive delivery (**Argo Rollouts**/**Flagger**) + PR-gated promotion; prod sync stays a human gate; ships 3 read-only `kubectl`/`argocd` scripts under `tools/` and a 5-agent team in `../.claude/agents/` (see `gitops-argocd/AGENTS.md`) |
| `observability-stack/` | **Vendor-neutral OSS observability** (Prometheus/Grafana/OpenTelemetry/Loki/Tempo/Alertmanager — the **LGTM** stack) + **SLOs** — three signals correlated into one context; PromQL rules + `ServiceMonitor`/cardinality control, the **OTel Collector** (OTLP/tail-sampling/`k8sattributes`), Loki/LogQL + Tempo/TraceQL + exemplar trace↔log correlation, Grafana dashboards-as-code (RED/USE), SLI/SLO/error-budget (**Sloth**/**OpenSLO**) + multi-window burn-rate + Alertmanager routing; the OSS counterpart to `../platform-engineering/dynatrace/`; ships 3 read-only config-validator scripts under `tools/` and a 5-agent team in `../.claude/agents/` (see `observability-stack/AGENTS.md`) |

## For AI Agents

### Working In This Directory
- This domain is for **operating** systems, not building them. Keep the boundary
  sharp: building a Kubernetes controller belongs in
  `../platform-engineering/kubernetes-operator-golang/`; building a control plane
  in `../platform-engineering/crossplane/`; *running* clusters belongs here.
- Naming convention: descriptive kebab-case, typically `<platform>-operations`
  (e.g. `kubernetes-operations`). Directory names are stable references —
  `README.md` and external docs link to them.
- The SKILL.md `name:` is independent of the directory name (both forms valid),
  but here they currently match (`kubernetes-operations`).
- Ops skills lead with **triage / decision-trees** and "what do I look at" tables,
  not a feature tour: one decision tree + one runnable example per surface. State
  *behavior* (stable) and avoid pinning a single product version (it rots) — point
  to the canonical upstream docs and the tool's own `--help`/introspection.

### Testing Requirements
- **`scripts/validate-skills.sh` validates this directory** (its `DOMAIN_DIRS`
  array includes `operations/`); CI runs it on every push and PR. Run it locally
  before pushing; per `SKILL.md` it checks:
  1. Frontmatter parses as YAML with `name`, `description`, `license`, `compatibility`, non-empty `metadata` map.
  2. Markdown body after the closing `---` is non-empty.
  3. Fenced code-block markers are even in count (these skills ship many bash/yaml blocks).
- After editing frontmatter, confirm `.description` still parses as a **string**
  (not a map): `yq '.description | type'` → `!!str`. A colon-dense description needs
  a `>-` block scalar.

### Common Patterns
- `metadata:` carries `domain: operations` plus `platform:` and `pattern:`
  (e.g. `pattern: day2-operations`) tags downstream registries can filter on.
- Body shape: CORE PRINCIPLES (non-negotiable) → a TRIAGE MAP → surface-by-surface
  phases with one decision tree + one runnable example each → anti-patterns table
  (violation → why → do instead) → pre-done checklist → reference → subagent
  orchestration. Same authoring shape as the `platform-engineering` skills.

## Dependencies

### Internal
- `../scripts/validate-skills.sh` — validates this tree (its `DOMAIN_DIRS` includes `operations/`); CI runs it on every push and PR. **A missing domain dir is itself a validator error**, so this directory must always contain at least one valid skill.
- `../README.md` — references each skill in the "Operations" table; rename → README update required.
- `../.claude/agents/` — the companion subagent teams that `kubernetes-operations` (`k8s-*`), `karpenter-operations` (`karpenter-*`), `azure-sre-agent` (`azure-sre-*`), `kubernetes-finops` (`k8s-cost-*` / `k8s-rightsizer` / `k8s-waste-hunter`), `gitops-argocd` (`argocd-*` / `flux-gitops-operator`), and `observability-stack` (`prometheus-rules-author` / `otel-collector-engineer` / `loki-tempo-correlation` / `grafana-dashboard-author` / `slo-alerting-engineer`) orchestrate.
- `../CLAUDE.md` — authoritative SKILL.md contract and repo layout.

<!-- MANUAL: -->
