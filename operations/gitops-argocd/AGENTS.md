<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-07-07 | Updated: 2026-07-07 -->

# gitops-argocd

## Purpose
Skill for **GitOps continuous delivery on Kubernetes** with **Argo CD** (primary) and
**Flux** (the sibling toolchain). GitOps is an operating model: a Git repository is the
single source of truth, a reconciler continuously diffs the live cluster against Git, and
the **cluster converges to Git** — never the reverse. Owns the operating doctrine + the CD
surface: **Applications** (single/multi-source, Helm/Kustomize/directory/CMP), the
**`AppProject`** tenancy boundary, the **sync engine** (automated `prune`/`selfHeal`, sync
waves, PreSync/Sync/PostSync/SyncFail hooks, sync options), **health & drift**
(custom-Lua health, `ignoreDifferences`, the OutOfSync/Degraded triage), **multi-cluster**
fan-out (`ApplicationSet` generators), and **gated promotion** (Argo Rollouts, Image
Updater, sync windows). A `operations/` Day-2 skill — it operates a running delivery
system; sits next to `kubernetes-operations` (hand-driven cluster ops) and
`agentic-k8s-ops` (the MCP/blast-radius doctrine it drives read-only).

## Key Files
| File | Description |
|------|-------------|
| `SKILL.md` | The skill — `name: gitops-argocd`, `domain: operations`, `tool: argo-cd`, `also: flux`, `pattern: gitops-continuous-delivery`, `api: argoproj.io/v1alpha1` |

## Subdirectories
| Directory | Purpose |
|-----------|---------|
| `tools/` | 3 read-only `kubectl` triage scripts (`argocd-app-health.sh`, `argocd-drift-check.sh`, `argocd-sync-status.sh`) over the `applications.argoproj.io` CRD; read-only is a hard invariant (see `tools/AGENTS.md`) |

## For AI Agents

### Working In This Directory
- Edit `SKILL.md` (and the read-only `tools/` scripts). Almost every change is authoring.
- **The doctrine is the spine, in order:** *Git is the single source of truth* (the cluster
  converges to Git; **no `kubectl apply` drift**) → *declarative Applications, not imperative
  pipelines* → *automated sync with `selfHeal` + `prune` is the target state, but prod is
  **GATED*** (sync window / manual sync / PR promotion) → *`AppProject` is the tenancy +
  blast-radius boundary* (restrict repos/destinations/whitelist; the `default` allow-all
  project is not for prod) → *sync waves + hooks order dependencies* → *drift is reconciled
  through Git* (revert the drift, don't hand-patch the cluster) → *least privilege* (SSO +
  RBAC, humans read-only by default) → *promotion is an explicit reviewable PR*. Keep those
  invariants intact on edits.
- **Argo CD primary, Flux sibling — don't blend.** The concepts map one-to-one (Application
  ↔ Kustomization/HelmRelease; ApplicationSet ↔ per-env Kustomization; sync waves ↔
  `dependsOn`; `AppProject` ↔ namespace+RBAC; Argo Rollouts ↔ Flagger). Never recommend
  running **both** reconcilers on the same objects — they fight.
- **Version discipline is load-bearing:** Argo CD, ApplicationSet generators, Argo
  Rollouts, Image Updater, and Flux all move fast. **State behavior, pin NO version, and
  frame CRD fields / generator types / sync options / flags as "verify against the Argo CD
  docs (`argo-cd.readthedocs.io`) + Flux docs (`fluxcd.io`)".** Same no-version-pin doctrine
  the `karpenter-operations` / `agentic-k8s-ops` skills follow.
- Keep the **scope boundary** sharp:
  - **Generic Day-2 kubectl triage** (Pod failures, hand-driven rollouts, drain/upgrade,
    RBAC/PSA mechanics) → `../kubernetes-operations/`.
  - **Node-lifecycle autoscaling** (Karpenter) → `../karpenter-operations/`.
  - **The agentic MCP tool-belt + blast-radius DOCTRINE** → `../agentic-k8s-ops/`. This
    skill *drives* the argocd MCP read-only; it does **not** own the doctrine.
  - **Helm chart authoring** → `../../platform-engineering/helm-chart-packages/` (Argo CD
    *consumes* charts; it does not author them).
  - **Crossplane control-plane IaC** → `../../platform-engineering/crossplane/`.
- Highest-blast-radius facts to keep correct: **`selfHeal` reverts hand-edits** (that's what
  makes "no drift" real) and **`prune` deletes what's removed from Git** — both ON for
  non-prod, but **prod stays gated**; `ignoreDifferences` is for **noise only**, never to
  hide real drift; **`ServerSideApply`** cuts false diffs; the `default` AppProject is
  allow-all (not for prod); **every production sync / rollback is a human-gated action** —
  the agent and most humans are read-only.
- The `description:` uses a `>-` block scalar (colon/backtick-dense) — keep it and re-verify
  `yq --front-matter=extract '.description | type'` is `!!str` after edits.

### Testing Requirements
- **`scripts/validate-skills.sh` validates this directory** (`operations/` is in
  `DOMAIN_DIRS`): frontmatter (`name`/`description`/`license`/`compatibility`, non-empty
  `metadata` map), non-empty body, even fence count. Run it after edits.
- `tools/` is **not** validator-covered — verify by hand (`bash -n`, the mutating-`kubectl`
  grep, the mutating-`argocd` grep, executable bit) per `tools/AGENTS.md`.

### Companion Subagents
- Ships a **5-agent GitOps team** in `../../.claude/agents/`:
  `argocd-application-author` (Phase A — `Application` single/multi-source,
  Helm/Kustomize/directory/CMP sources, `AppProject` tenancy, app-of-apps; also the Phase E
  `Rollout` + Image-Updater manifests), `argocd-sync-operator` (Phase B — sync policy
  automated/prune/selfHeal, sync waves, PreSync/Sync/PostSync/SyncFail hooks, sync options,
  the gated prod sync — owns `tools/argocd-sync-status.sh`), `argocd-drift-health` (Phase C —
  health incl. custom Lua, diff, `ignoreDifferences`, OutOfSync/Degraded triage, self-heal —
  owns `tools/argocd-drift-check.sh`), `argocd-multicluster` (Phase D — `ApplicationSet`
  generators, cluster registration, RBAC + SSO tenancy — owns `tools/argocd-app-health.sh`),
  `flux-gitops-operator` (Phase F — the Flux sibling `GitRepository`/`Kustomization`/
  `HelmRelease` + controllers + Flagger, Argo-vs-Flux selection + migration). The SKILL's
  "Subagent Orchestration" table maps phase → agent; update both on rename.

### Common Patterns
- Intro + mental model → the Argo-CD-vs-Flux concept table → CORE PRINCIPLES → TRIAGE MAP →
  phases A–F (Application / Sync / Health-drift / Multi-cluster / Promotion / Flux) →
  anti-patterns → checklist → reference → MCP surface → subagent orchestration. Same
  authoring shape as the sibling operations skills (`karpenter-operations`, `kubernetes-finops`).

## Dependencies

### Internal
- `../../scripts/validate-skills.sh` — enforces the SKILL.md contract.
- `../../README.md` — references this skill in the "Operations" table; rename → README update.
- `../../.claude/agents/argocd-application-author.md`, `.../argocd-sync-operator.md`,
  `.../argocd-drift-health.md`, `.../argocd-multicluster.md`, `.../flux-gitops-operator.md`
  — the 5 companion subagents.
- `../kubernetes-operations/SKILL.md` (generic Day-2 triage),
  `../karpenter-operations/SKILL.md` (node autoscaling),
  `../agentic-k8s-ops/SKILL.md` (MCP tool-belt / blast-radius doctrine — cites the same
  `mcp-for-argocd` server), `../../platform-engineering/helm-chart-packages/SKILL.md` (chart
  authoring), `../../platform-engineering/crossplane/SKILL.md` (control-plane IaC) —
  cross-referenced to keep boundaries sharp.

### External
None at runtime — documentation. Describes GitOps CD with Argo CD + Flux; cites the Argo CD
docs (`argo-cd.readthedocs.io`), Argo Rollouts / Image Updater docs, and the Flux docs
(`fluxcd.io`). `tools/` scripts need only `kubectl` (cluster-reader RBAC over
`applications.argoproj.io`) + POSIX tools; the `argocd` CLI is optional (read-only). No
version pinned.

<!-- MANUAL: -->
