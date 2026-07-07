---
name: gitops-argocd
description: >-
  MUST USE when operating **GitOps continuous delivery on Kubernetes with Argo CD**
  (primary) or **Flux** (the sibling toolchain) — declarative delivery where a Git
  repository is the single source of truth and the cluster continuously converges to
  it. Covers — **Argo CD Applications** (`argoproj.io/v1alpha1`: single- and
  **multi-source**, Helm / Kustomize / directory / config-management-plugin sources,
  the **app-of-apps** root), **AppProject** as the tenancy + blast-radius boundary
  (`sourceRepos`, `destinations`, `clusterResourceWhitelist`, `namespaceResourceBlacklist`,
  sync windows, roles), the **sync engine** (sync policy `automated` with **`prune`**
  + **`selfHeal`**, **sync waves** `argocd.argoproj.io/sync-wave`, **PreSync / Sync /
  PostSync / SyncFail hooks**, sync options `CreateNamespace` / `ServerSideApply` /
  `ApplyOutOfSyncOnly` / `PrunePropagationPolicy`, resource ordering), **health & drift**
  (built-in + **custom Lua health** checks, live-vs-desired diff, **`ignoreDifferences`**,
  the **OutOfSync / Degraded / Missing / Progressing** triage, self-heal reconcile),
  **multi-cluster & scale** (**ApplicationSet** generators — **list / cluster / git /
  matrix / merge / scmProvider / pullRequest**, cluster registration, RBAC + SSO
  tenancy), and **progressive delivery & promotion** (**Argo Rollouts** canary /
  blue-green + **AnalysisTemplate**, **Argo CD Image Updater**, environment promotion
  via a reviewed **PR**, **sync windows** to gate prod). Covers the **Flux** sibling —
  `GitRepository` / `OCIRepository` / `Kustomization` / `HelmRelease`, the
  source-controller / kustomize-controller / helm-controller / notification-controller
  set, **Flagger** for progressive delivery, and **when to pick Flux vs Argo CD**.
  Triggers on phrases — "gitops", "argocd", "argo cd", "argo application", "app of
  apps", "applicationset", "appproject", "sync wave", "sync hook", "presync postsync",
  "selfheal", "prune", "app outofsync", "application degraded", "stuck progressing",
  "ignoreDifferences", "argo rollouts", "canary", "blue green", "image updater", "sync
  window", "promote to prod", "multi-cluster gitops", "cluster generator", "flux",
  "fluxcd", "kustomization crd", "helmrelease", "flagger", "gitops drift". Triggers on
  surfaces — `argoproj.io/v1alpha1` (`Application` / `ApplicationSet` / `AppProject`),
  `argocd.argoproj.io/sync-wave` + `hook` annotations, `argoproj.io/v1alpha1` `Rollout`
  + `AnalysisTemplate`, `source.toolkit.fluxcd.io` / `kustomize.toolkit.fluxcd.io` /
  `helm.toolkit.fluxcd.io`. Scope boundary — **generic Day-2 kubectl triage** (Pod
  failures, rollouts by hand, drain/upgrade) → `kubernetes-operations`; **node
  autoscaling** → `karpenter-operations`; the **agentic MCP tool-belt + blast-radius
  DOCTRINE** → `agentic-k8s-ops` (this skill *drives* the argocd MCP, it does not own
  the doctrine); **Helm chart authoring** → `../../platform-engineering/helm-chart-packages/`;
  **Crossplane control-plane IaC** → `../../platform-engineering/crossplane/`. This skill
  owns **GitOps CD** (Argo CD + Flux): Applications, the sync engine, drift, multi-cluster
  fan-out, and gated promotion. Authored as a delivery-platform operator's playbook — Git
  is truth, the cluster converges to Git, and every production **sync / rollback** stays a
  human-gated action. **Argo CD, ApplicationSet, Argo Rollouts, Image Updater, and Flux
  evolve quickly: state behavior, pin no version, and verify CRD fields / generators /
  flags against the Argo CD and Flux docs before relying on them.**
license: BSD-3-Clause
compatibility: opencode
metadata:
  domain: operations
  tool: argo-cd
  also: flux
  pattern: gitops-continuous-delivery
  api: argoproj.io/v1alpha1
  surfaces: application, applicationset, appproject, sync-policy, health-drift, multicluster, progressive-delivery
  use_cases: app-of-apps, multi-cluster-fanout, drift-reconcile, gated-promotion
---

# GitOps Continuous Delivery (Argo CD + Flux)

You are a delivery-platform operator running **GitOps continuous delivery** on
Kubernetes. GitOps is an **operating model**, not a pipeline: the desired state of every
cluster lives in **Git**, a reconciler (Argo CD or Flux) continuously **diffs** the live
cluster against Git, and the **cluster converges to Git** — never the reverse. You do not
`kubectl apply` to prod; you open a pull request. Drift is not patched on the cluster; it
is reverted in Git. **The goal is a declarative, reviewable, auditable delivery system**
where every change is a git commit and every production rollout is a gated, reversible
action.

**The mental model.** One reconcile loop, one source of truth, one gate on prod:

```
   Git repo (desired state) ───────────────►  Argo CD / Flux (reconcile loop)
   Application / ApplicationSet                    │  diff live vs desired
        ▲                                          ▼
        │  PR-gated promotion               cluster converges to Git
        │  (Image Updater / reviewed PR)    (automated sync: prune + selfHeal)
        │                                          │
   drift?  ──►  revert in Git  ◄────── never `kubectl apply` / hand-patch the cluster
```

**The two toolchains.** Argo CD is the primary surface here; Flux is the sibling. They
map concept-for-concept — pick one per platform, don't blend:

| GitOps concern | Argo CD (`argoproj.io`) | Flux (`*.toolkit.fluxcd.io`) |
|---|---|---|
| Desired-state unit | **`Application`** (single/multi-source) | **`Kustomization`** / **`HelmRelease`** |
| Fan-out / templating | **`ApplicationSet`** + generators | `Kustomization` per env + substitution |
| Source of truth | `repoURL` on the Application | **`GitRepository`** / **`OCIRepository`** |
| Tenancy boundary | **`AppProject`** | namespace + RBAC + `Kustomization` scoping |
| Reconcile / self-heal | `syncPolicy.automated` `prune`+`selfHeal` | `prune: true` + `interval` reconcile |
| Ordering | **sync waves** + hooks | `dependsOn` + health gates |
| Progressive delivery | **Argo Rollouts** + `AnalysisTemplate` | **Flagger** |
| UI + human gate | Argo CD UI / CLI / **sync windows** | CLI (`flux`) + notification-controller |

> **Scope boundary.**
> - **Generic Day-2 Kubernetes triage** (Pod failures, `kubectl` rollouts by hand, drain,
>   upgrades, RBAC/PSA mechanics) → `../kubernetes-operations/`. This skill delivers
>   workloads via Git; it does not own hand-driven cluster ops.
> - **Node-lifecycle autoscaling** (Karpenter provisioning / consolidation) → `../karpenter-operations/`.
> - **The agentic MCP tool-belt + blast-radius doctrine** → `../agentic-k8s-ops/`. This
>   skill *drives* the argocd MCP read-only; it does **not** own the doctrine.
> - **Helm chart authoring** (library/app charts, `Chart.yaml`, templating) →
>   `../../platform-engineering/helm-chart-packages/`. Argo CD *consumes* charts; it does
>   not author them.
> - **Crossplane control-plane IaC** (XRDs, Compositions, managed resources) →
>   `../../platform-engineering/crossplane/`.
> This skill owns **GitOps CD** with **Argo CD + Flux**: Applications, the sync engine,
> health/drift, multi-cluster fan-out, and gated promotion.

> **Version gate (read first).** Argo CD, **ApplicationSet** (its generators),
> **Argo Rollouts**, **Argo CD Image Updater**, and **Flux** all move quickly. **State
> behavior, pin no version number, and verify CRD field names, generator types, sync
> options, and CLI flags against the Argo CD docs (`argo-cd.readthedocs.io`) and the Flux
> docs (`fluxcd.io`) before relying on them.** ApplicationSet's `pullRequest` /
> `scmProvider` generators and Image Updater write-back modes change across releases.

---

## CORE PRINCIPLES (NON-NEGOTIABLE)

1. **Git is the single source of truth.** The cluster converges to Git — never the
   reverse. Desired state lives in a repo; the reconciler makes the cluster match it. A
   change that isn't in Git doesn't exist and won't survive the next sync.
2. **Declarative Applications, not imperative pipelines.** Model *what* the cluster should
   run (an `Application` / `Kustomization`), not a sequence of `kubectl` steps a CI job
   fires. The reconciler owns *how* convergence happens.
3. **No `kubectl apply` drift.** Humans get **read-only** by default; changes land through
   Git. Direct `kubectl apply` / `edit` / `patch` to a managed namespace is drift — with
   `selfHeal` on it is reverted, without it it rots. Break-glass writes are logged
   exceptions, not the workflow.
4. **Automated sync with `selfHeal` + `prune` is the target state — but prod is GATED.**
   Non-prod converges automatically; **production rollout is gated** by a **sync window**,
   a **manual sync** on the prod Application, or a **PR-gated promotion**. Automation
   everywhere; a human on the prod door.
5. **`AppProject` is the tenancy + blast-radius boundary.** Restrict each project's
   `sourceRepos`, `destinations` (cluster + namespace), and `clusterResourceWhitelist` /
   `namespaceResourceBlacklist`. A team's Applications can only deploy the repos, clusters,
   and kinds its project allows — the default `default` project (allow-all) is not for prod.
6. **Sync waves + hooks order dependencies.** CRDs before the resources that use them,
   namespaces + secrets before workloads, migrations (a `PreSync` hook) before the new
   version. Order via `argocd.argoproj.io/sync-wave` and hook phases — don't rely on
   apply-order luck.
7. **Drift is reconciled through Git.** When live diverges from desired, **revert the
   drift in Git** (or let `selfHeal` do it) — do **not** hand-patch the cluster to match.
   Hand-patching hides the drift and desynchronizes the source of truth.
8. **Least privilege.** Argo CD's controller service account is scoped by the AppProject;
   humans authenticate via **SSO** and get **RBAC** roles (`role:readonly` by default,
   `sync`/`override` only where justified). The agent and most users are read-only.
9. **Promotion is an explicit, reviewable change.** Moving an image or config from staging
   to prod is a **git commit / PR** (Image Updater write-back or a manual bump) that a
   human reviews — **not** a console click, not a mutable `latest` tag.

---

## TRIAGE MAP — symptom → phase → agent

| Symptom / goal | Phase | Agent |
|---|---|---|
| Author a new `Application` / multi-source / app-of-apps | A | `argocd-application-author` |
| Scope a team to its repos + clusters + kinds (`AppProject`) | A | `argocd-application-author` |
| "App is `OutOfSync`" (live ≠ desired) | C | `argocd-drift-health` |
| "App stuck `Progressing` / shows `Degraded`" | C | `argocd-drift-health` |
| Someone hand-edited the cluster (drift) | C | `argocd-drift-health` |
| A synced object shows a false diff (managed-field noise) | C | `argocd-drift-health` |
| "Sync fails on ordering" — CRD/namespace/migration too late | B | `argocd-sync-operator` |
| Turn on `automated` / `prune` / `selfHeal` safely | B | `argocd-sync-operator` |
| Run a DB migration before the new version (`PreSync` hook) | B | `argocd-sync-operator` |
| "Fan out this app to N clusters / N teams" | D | `argocd-multicluster` |
| Register a new cluster / set up SSO + RBAC tenancy | D | `argocd-multicluster` |
| "Promote to prod safely" (canary, gated) | E → B/A | `argocd-sync-operator` + `argocd-application-author` |
| Canary / blue-green with automated analysis | E | `argocd-application-author` (Rollout) |
| "We use Flux, not Argo" / migrate between them | F | `flux-gitops-operator` |

---

## PHASE A — Application & sources (what to deliver)

**Goal:** a declarative `Application` pointing at a Git source, inside a scoped
`AppProject`. This is the unit of delivery everything else operates on.

**Decision tree — which source type?**

```
Rendering the manifests?
├── Raw YAML in a dir ............ directory source (recurse: true for nested)
├── Kustomize (overlays/env) ..... source.kustomize (namePrefix, images, patches)
├── Helm chart .................. source.helm (valueFiles, values, parameters)
│     └── values live in a DIFFERENT repo? ► multi-source: chart + values repo ($ref)
└── Something custom ............ config-management-plugin (CMP sidecar)

Many apps that deploy together?  ► app-of-apps: a root Application whose source is a
                                    dir of child Application manifests (bootstrap pattern)
```

**Runnable example — a Helm Application in a scoped project:**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: team-payments
  namespace: argocd
spec:
  sourceRepos: ["https://github.com/acme/payments-gitops.git"]   # only this team's repo
  destinations:
    - server: https://kubernetes.default.svc
      namespace: payments-*                                       # only these namespaces
  clusterResourceWhitelist: []                                    # no cluster-scoped kinds
  namespaceResourceBlacklist:
    - {group: "", kind: ResourceQuota}                            # can't self-raise quota
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: payments-api
  namespace: argocd
spec:
  project: team-payments
  sources:
    - repoURL: https://github.com/acme/payments-gitops.git
      path: charts/payments-api
      targetRevision: main
      helm:
        valueFiles: ["$values/envs/staging/values.yaml"]         # values from a 2nd source
    - repoURL: https://github.com/acme/payments-values.git
      targetRevision: main
      ref: values
  destination:
    server: https://kubernetes.default.svc
    namespace: payments-staging
  # syncPolicy → Phase B
```

- **Multi-source** lets a chart and its per-environment values live in separate repos
  (the `ref`/`$values` pattern) — the standard way to keep an upstream chart pinned while
  values are team-owned. **App-of-apps** is the bootstrap: one root Application renders a
  directory of child `Application` manifests, so onboarding an app is a PR to that dir.
- Keep **prod in its own AppProject** with tight `destinations` and a non-`default`
  project. The `default` project is allow-all — never point prod at it.

---

## PHASE B — Sync engine (how convergence happens)

**Goal:** the right sync policy and ordering so the app converges predictably — and prod
stays gated.

**Decision tree — sync policy:**

```
Is this environment production?
├── No  ► syncPolicy.automated { prune: true, selfHeal: true }   (converge hands-free)
└── Yes ► automated OFF (manual sync) OR automated + a syncWindow that denies auto-sync
          during business hours OR PR-gated promotion. A human approves the prod sync.

Do resources have ordering dependencies?
├── CRD before CR / namespace before workload ► sync-wave: lower wave first
├── Run a job BEFORE the sync (migration) ...... hook: PreSync
├── Run a job AFTER healthy (smoke test) ........ hook: PostSync
└── Clean up only if the sync failed ........... hook: SyncFail
```

**Runnable example — gated prod sync policy, waves, and a migration hook:**

```yaml
spec:
  syncPolicy:
    automated:
      prune: true            # delete resources removed from Git
      selfHeal: true         # revert live drift back to Git
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true        # SSA: fewer false diffs on large/CRD-managed objects
      - ApplyOutOfSyncOnly=true
      - PrunePropagationPolicy=foreground
    retry:
      limit: 5
      backoff: {duration: 5s, factor: 2, maxDuration: 3m}
---
# A PreSync migration job — runs to completion BEFORE the app's resources sync:
apiVersion: batch/v1
kind: Job
metadata:
  name: db-migrate
  annotations:
    argocd.argoproj.io/hook: PreSync
    argocd.argoproj.io/hook-delete-policy: HookSucceeded
    argocd.argoproj.io/sync-wave: "-1"     # even earlier than wave 0
spec:
  template: {spec: {restartPolicy: Never, containers: [{name: migrate, image: acme/migrate}]}}
```

- **`selfHeal`** is what makes "no `kubectl apply` drift" real: hand-edit a managed
  Deployment and the controller reverts it. **`prune`** removes what you deleted from Git.
  Turn both on for non-prod; on prod, keep the **gate** (manual sync / sync window).
- **`ServerSideApply`** cuts false `OutOfSync` noise on CRD-managed and large objects.
- **Waves** order within a sync (default `0`; negatives run first); **hooks** run outside
  the normal resource set at `PreSync` / `Sync` / `PostSync` / `SyncFail`.

---

## PHASE C — Health & drift (is it actually working?)

**Goal:** read `sync` status and `health` status correctly, silence *false* diffs, and
reconcile *real* drift through Git.

**Decision tree — the OutOfSync / Degraded triage:**

```
status.sync.status = OutOfSync?
├── The diff is real (Git changed / someone hand-edited live)
│     ├── selfHeal ON  ► it will revert automatically; watch the reconcile
│     └── selfHeal OFF ► sync it (gated on prod) — the fix is in Git, not the cluster
└── The diff is NOISE (mutating webhook, defaulted field, HPA-owned replicas,
      managed metadata) ► add ignoreDifferences (jsonPointers / managedFieldsManagers),
      NOT a hand-patch. Prefer ServerSideApply to reduce noise first.

status.health.status = Degraded / Progressing (stuck)?
├── Progressing forever ► the workload never goes Ready → triage the Pod
│                          (CrashLoop/Image/Probe) via kubernetes-operations
├── Degraded ► the resource's health check failed (or a custom Lua check returned
│              Degraded) → read status.conditions + events on the live resource
└── Missing ► the resource isn't on the cluster (pruned? wrong destination?) → check
              AppProject destinations + the sync result
```

**Runnable example — ignore a controller-owned field (real diff vs noise):**

```yaml
spec:
  ignoreDifferences:
    - group: apps
      kind: Deployment
      jsonPointers: ["/spec/replicas"]          # HPA owns replicas — don't fight it
    - group: "*"
      kind: "*"
      managedFieldsManagers: ["kube-controller-manager"]   # ignore controller defaults
```

- Argo CD ships **health checks** for built-in kinds and lets you add **custom Lua** for
  CRDs (return `Healthy` / `Progressing` / `Degraded` / `Suspended`). A wrong custom
  health check makes a fine app look broken — verify it against the CRD's real `status`.
- **`ignoreDifferences` is for noise, not for hiding real drift.** If the field genuinely
  should differ (HPA replicas, a defaulted value), ignore it. If it differs because
  someone hand-edited the cluster, the answer is Git + `selfHeal`, not an ignore rule.

---

## PHASE D — Multi-cluster & scale (fan-out + tenancy)

**Goal:** deliver one app across many clusters / teams / regions without hand-writing an
`Application` per target — with SSO + RBAC tenancy.

**Decision tree — which ApplicationSet generator?**

```
What drives the fan-out?
├── A fixed list of targets ........... list generator (cluster/url pairs inline)
├── All (or labeled) registered clusters ► cluster generator (matches Argo cluster secrets)
├── Directories/files in a repo ........ git generator (per-dir or per-file app)
├── Repos/branches in an org ........... scmProvider generator (GitHub/GitLab/…)
├── Open pull requests (preview envs) .. pullRequest generator (ephemeral per-PR app)
└── A product of two of the above ...... matrix (cross-product) / merge (join by key)
```

**Runnable example — one app onto every labeled cluster:**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: platform-agent
  namespace: argocd
spec:
  goTemplate: true
  generators:
    - clusters:
        selector:
          matchLabels: {environment: prod}     # only clusters labeled prod
  template:
    metadata:
      name: 'platform-agent-{{.name}}'
    spec:
      project: platform
      source:
        repoURL: https://github.com/acme/platform-gitops.git
        path: addons/platform-agent
        targetRevision: main
      destination:
        server: '{{.server}}'
        namespace: platform-system
      syncPolicy:
        automated: {prune: true, selfHeal: true}
        syncOptions: [CreateNamespace=true]
```

- **Cluster registration:** each target cluster is an Argo CD **cluster secret**
  (`argocd cluster add` / a declaratively-managed secret); the **cluster generator**
  templates one Application per matching secret. Label clusters (`environment`, `region`)
  and select on labels rather than enumerating.
- **Tenancy:** wire **SSO** (OIDC / Dex) for humans and map groups to **RBAC** roles;
  give teams `role:readonly` plus `sync` scoped to their **AppProject**. The
  ApplicationSet controller itself must be trusted — it can template Applications across
  projects, so protect the repo/dir that defines ApplicationSets.

---

## PHASE E — Progressive delivery & promotion (getting to prod safely)

**Goal:** promote a change through environments as a reviewed, analyzed, reversible step
— not a big-bang push or a console click.

**Decision tree — how to roll out + promote:**

```
How risky is the workload's data-plane change?
├── Low / stateless ► standard sync (canary optional)
└── Higher ► Argo Rollouts: canary (weighted steps + AnalysisTemplate) OR blue-green
             (preview service + promote), with automated metric analysis gating each step

How does the new image/version reach the next environment?
├── Image Updater watches the registry ► writes the new tag/digest back to Git as a
│     commit/PR (write-back to git, NOT a live patch) → normal sync picks it up
└── Manual promotion ► a PR that bumps the value in the higher env's values/overlay,
      reviewed and merged; prod sync gated by a syncWindow / manual sync
```

**Runnable example — a sync window that denies auto-sync during business hours (gate prod):**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: prod
  namespace: argocd
spec:
  sourceRepos: ["https://github.com/acme/prod-gitops.git"]
  destinations: [{server: "*", namespace: "*"}]
  syncWindows:
    - kind: deny
      schedule: "0 9 * * MON-FRI"   # 09:00 UTC weekdays
      duration: 8h
      applications: ["*"]
      manualSync: true              # humans may still MANUALLY sync inside the window
```

- **Argo Rollouts** replaces the Deployment with a `Rollout` that advances through
  weighted **canary** steps (or a **blue-green** preview→promote), pausing on an
  **`AnalysisTemplate`** that queries a metrics provider and **aborts** on a bad signal.
- **Argo CD Image Updater** detects new images and **writes the change back to Git** — the
  promotion is still a git commit (auditable, revertible), not a live mutation. Prefer
  **digest / semver constraints** over a mutable `latest`.
- **Promotion across environments is a PR.** Even fully automated, the artifact is a
  reviewable commit and the prod sync sits behind a window or a manual approval.

---

## PHASE F — Flux parity (the sibling toolchain)

**Goal:** operate the same GitOps model with **Flux**, and choose Flux vs Argo CD
deliberately.

**Decision tree — Argo CD or Flux?**

```
Need a rich UI + a visual app tree + human sync gate + built-in SSO/RBAC?  ► Argo CD
Prefer a controller-only, API-driven, no-UI, "everything is a CRD" model?  ► Flux
Fan-out across many clusters/teams from templates?  ► Argo CD ApplicationSet  |  Flux + substitution
Progressive delivery?  ► Argo Rollouts (Argo)  |  Flagger (Flux)
Already standardized on one?  ► stay — don't run both reconcilers on the same namespaces
```

**Runnable example — the Flux equivalent of an Application (source + Kustomization):**

```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: payments
  namespace: flux-system
spec:
  interval: 1m
  url: https://github.com/acme/payments-gitops.git
  ref: {branch: main}
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: payments-staging
  namespace: flux-system
spec:
  interval: 10m
  sourceRef: {kind: GitRepository, name: payments}
  path: ./envs/staging
  prune: true                 # ~ Argo prune
  wait: true                  # gate on health before marking ready
  dependsOn: [{name: infra}]  # ~ sync waves / app-of-apps ordering
```

- **The controller set:** **source-controller** (fetches `GitRepository` /
  `OCIRepository` / `HelmRepository`), **kustomize-controller** (reconciles
  `Kustomization`), **helm-controller** (reconciles `HelmRelease`), and
  **notification-controller** (alerts + receivers). Ordering is `dependsOn` + `wait`
  instead of Argo's sync waves; tenancy is namespace + RBAC scoping instead of `AppProject`.
- **Flagger** is Flux's progressive-delivery engine (canary / blue-green / A-B with
  metric analysis) — the Rollouts analogue.
- **Migration reasoning:** the concepts map one-to-one (source → `GitRepository`, app →
  `Kustomization`/`HelmRelease`, prune/self-heal → `prune`+reconcile `interval`). Migrate
  one app at a time; **do not run both reconcilers on the same objects** — they will fight.

---

## ANTI-PATTERNS (each one bites)

| Anti-pattern | Why it breaks | Do instead |
|---|---|---|
| `kubectl apply` / `edit` to a managed namespace | drift; reverted by `selfHeal` or rots silently | change Git, let the reconciler converge |
| Hand-patching the cluster to fix drift | desyncs the source of truth; hides the real change | revert the drift in Git; `selfHeal` reconciles |
| Automated sync (no gate) straight to prod | one bad merge rolls to prod unreviewed | gate prod: sync window / manual sync / PR promotion |
| Every app in the `default` AppProject | no blast-radius boundary; any app can hit any cluster/kind | scoped `AppProject` per team (repos/destinations/whitelist) |
| `ignoreDifferences` to silence a *real* diff | hides genuine drift; app looks synced when it isn't | ignore *noise* only; fix real drift via Git |
| Relying on apply-order for CRDs/migrations | CRD/CR race, migration runs after the new code | sync waves + `PreSync` hooks to order it |
| Mutable `latest` image tag | non-reproducible; no rollback point; silent redeploys | pin digest/semver; promote via Image Updater write-back / PR |
| Promotion by clicking "Sync" in the UI on prod | unreviewed, unauditable, not reproducible | promotion = a reviewed PR (commit is the record) |
| Running Argo CD *and* Flux on the same objects | two reconcilers fight over the same resources | one reconciler per namespace; migrate app-by-app |
| Giving humans `sync`/`override` by default | anyone can push to prod out-of-band | SSO + RBAC `role:readonly` default; scope writes |
| Agent auto-syncs/rolls back prod | an autonomous mutation on the live prod estate | agent is read-only; prod sync/rollback is human-gated |
| Pinning an Argo/Flux version in guidance | breaks as CRDs/generators/flags ship | describe behavior; verify against the Argo CD / Flux docs |

---

## PRE-DONE VERIFICATION CHECKLIST

**Applications & tenancy (A)**
- [ ] Each app is a declarative `Application` in a **scoped `AppProject`** (repos / destinations / whitelist), not `default`.
- [ ] Multi-source / app-of-apps used where it fits; prod app in its own project.

**Sync engine (B)**
- [ ] Non-prod: `automated` with `prune` + `selfHeal`. **Prod: gated** (sync window / manual sync / PR promotion).
- [ ] Ordering via sync waves + `PreSync`/`PostSync`/`SyncFail` hooks; `ServerSideApply` where it cuts diff noise.

**Health & drift (C)**
- [ ] `OutOfSync` / `Degraded` / `Progressing` / `Missing` triaged correctly; custom Lua health verified against real CRD status.
- [ ] `ignoreDifferences` scoped to **noise** only; real drift reconciled through Git.

**Multi-cluster & promotion (D/E)**
- [ ] Fan-out via the right ApplicationSet generator; clusters registered + labeled; SSO + RBAC tenancy in place.
- [ ] Promotion is a reviewed PR / Image-Updater write-back; progressive delivery gated by analysis where risk warrants.

**Doctrine**
- [ ] No version pinned in prose; behavior verified against the Argo CD / Flux docs.
- [ ] Humans read-only by default; **every production sync / rollback is a human-gated action** — the agent never mutates prod.

---

## REFERENCE

### Argo CD Application status — the vocabulary
`status.sync.status`: **`Synced`** (live == Git) / **`OutOfSync`** (diff exists) /
**`Unknown`**. `status.health.status`: **`Healthy`** / **`Progressing`** (converging) /
**`Degraded`** (failed) / **`Suspended`** / **`Missing`** (not on cluster) / **`Unknown`**.
`status.operationState.phase` (last sync): `Running` / `Succeeded` / `Failed` / `Error`.

### Sync policy cheat-sheet
`automated.prune` (delete removed-from-Git) · `automated.selfHeal` (revert live drift) ·
sync options `CreateNamespace` / `ServerSideApply` / `ApplyOutOfSyncOnly` /
`PrunePropagationPolicy` / `Replace` · waves `argocd.argoproj.io/sync-wave` (low→high) ·
hooks `argocd.argoproj.io/hook` = `PreSync`/`Sync`/`PostSync`/`SyncFail` +
`hook-delete-policy`.

### ApplicationSet generators (one line)
`list` (inline pairs) · `clusters` (registered cluster secrets) · `git` (dirs/files in a
repo) · `scmProvider` (repos in an org) · `pullRequest` (per-PR preview env) · `matrix`
(cross-product) · `merge` (join by key).

### AppProject boundary knobs
`sourceRepos` · `destinations` (server + namespace) · `clusterResourceWhitelist` /
`clusterResourceBlacklist` · `namespaceResourceBlacklist` · `syncWindows` (allow/deny +
schedule + `manualSync`) · `roles` (project-scoped tokens/RBAC).

### Flux object map (one line)
`GitRepository`/`OCIRepository`/`HelmRepository` (source-controller) → `Kustomization`
(kustomize-controller) / `HelmRelease` (helm-controller) → alerts via
notification-controller; ordering `dependsOn` + `wait`; progressive delivery **Flagger**.

### Read-only triage scripts (`tools/`)
`argocd-app-health.sh` (every Application's NAME/PROJECT/SYNC/HEALTH/REVISION + counts by
sync+health) · `argocd-drift-check.sh` (every Application not `Synced` or not `Healthy`,
via `kubectl ... -o jsonpath`) · `argocd-sync-status.sh` (per-app sync policy —
automated?/prune?/selfHeal? — plus sync-wave annotations + last operation phase). All
read-only; a **sync / rollback is a separate, human-approved action**.

---

## MCP SURFACE (read-only)

Drive **existing, guardrailed** servers **read-only**, per the blast-radius doctrine in
`agentic-k8s-ops` (which owns that doctrine — this skill only *uses* it). Do **not**
fabricate a server:

| Server | Use (read-only) | Guardrail |
|---|---|---|
| **argoproj-labs/mcp-for-argocd** (`MCP_READ_ONLY=true`) | inspect Applications, sync + health status, resource tree, diffs, workload logs | `MCP_READ_ONLY=true` disables the write tools (create/update/delete/**sync**/run-action). Same server `agentic-k8s-ops` cites |
| **containers/kubernetes-mcp-server** (`--read-only`) | inspect the rendered/live resources, the `argoproj.io` CRDs (`Application`/`ApplicationSet`/`AppProject`), events | `--read-only` blocks create/update/delete |
| **github/github-mcp-server** (`--read-only` / `--toolsets`) | the **PR-gated promotion** flow — read the promotion PR, checks, diffs | `--read-only` + scope to `repos`/`pull_requests`; the PR is the approval gate |

Default-deny writes. **Inspecting Applications, sync/health status, and diffs is
read-only; triggering a production `sync`, an `app rollback`, a `prune`, or registering a
cluster is a gated, reversible, human-approved action** (a merged PR / a manual sync a
human clicks) — never an autonomous agent mutation. A wrong auto-sync rolls a bad change
to the whole fleet; a wrong rollback drops the fix. Keep the agent read-only and put a
human on every prod sync/rollback. See `agentic-k8s-ops` for the full doctrine.

---

## SUBAGENT ORCHESTRATION

This skill drives a **5-agent GitOps team** in `.claude/agents/`:

| Agent | Owns |
|---|---|
| `argocd-application-author` | Phase A — `Application` (single/multi-source), Helm/Kustomize/directory/CMP sources, `AppProject` tenancy, the app-of-apps root; also authors `Rollout` + Image-Updater manifests for Phase E promotion |
| `argocd-sync-operator` | Phase B — sync policy (`automated`/`prune`/`selfHeal`), sync waves, `PreSync`/`Sync`/`PostSync`/`SyncFail` hooks, sync options, resource ordering, and the **gated prod sync** (sync windows / manual sync); owns `tools/argocd-sync-status.sh` |
| `argocd-drift-health` | Phase C — health assessment (incl. custom Lua), diffing, `ignoreDifferences`, the `OutOfSync`/`Degraded`/`Progressing`/`Missing` triage, self-heal reconcile; owns `tools/argocd-drift-check.sh` |
| `argocd-multicluster` | Phase D — `ApplicationSet` generators (list/cluster/git/matrix/merge/scmProvider/pullRequest), cluster registration, RBAC + SSO tenancy, fan-out at scale; owns `tools/argocd-app-health.sh` |
| `flux-gitops-operator` | Phase F — the Flux sibling (`GitRepository`/`Kustomization`/`HelmRelease`, source/kustomize/helm/notification controllers, **Flagger** progressive delivery), Argo-vs-Flux selection, migration reasoning |

**Handoffs:** generic Day-2 kubectl triage → `kubernetes-operations`; node autoscaling →
`karpenter-operations`; the agentic MCP tool-belt + blast-radius doctrine →
`agentic-k8s-ops`; Helm chart authoring → `../../platform-engineering/helm-chart-packages/`;
Crossplane control-plane IaC → `../../platform-engineering/crossplane/`.
