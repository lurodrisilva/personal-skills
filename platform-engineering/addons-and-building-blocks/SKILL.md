---
name: addons-and-building-blocks
description: MUST USE when authoring, reviewing, or modifying anything in a Kubernetes **Platform Engineering** workspace that ships **baseline addons** (ArgoCD App-of-Apps `base_chart/` + per-addon `addon_charts/*`) or **building blocks** (application Helm charts such as a database / cache package built on a shared library chart). Covers — Helm library charts with `myorg.*` / `plat-net.*` helpers; application charts consuming those helpers via OCI (`oci://ghcr.io/<org>/helm-charts`); CloudNativePG `Cluster`, Crossplane `RedisCache`, and similar CRD-driven resources rendered from values arrays; ArgoCD `Application` templates with sync waves, `ServerSideApply`, and `ignoreDifferences`; the wrapper-chart `tests/chart/` helm-unittest pattern; yamllint + helm lint + helm-unittest + kubeconform as the four-tier local/CI validation; Terraform + Terratest AKS foundations that bootstrap ArgoCD; GitOps repositories structured as `base_chart/templates/{NN}-{kebab-case}.yaml` + `addon_charts/<kebab-case>/`. Use when the user asks to "add a new addon", "enable cert-manager / karpenter / kube-state-metrics / cloudnative-pg", "create a building block", "add another database / cache / building block", "bump the commons library version", "pin helm to 3.20.0", "fix helm-unittest", "add a kubeconform step", "wire OCI dependency", "fix `datatabase.yaml` typo" (do NOT), "quote `redisVersion`", or "review a PR against `02-plat-eng-commons-package`, `04-plat-eng-building-block-database`, `05-plat-eng-building-block-cache`, `00-baseline-addons`, or `03-plat-eng-aks-foundation`". Also triggers on file patterns `Chart.yaml`, `values.yaml`, `templates/_helpers.tpl`, `templates/*.yaml`, `.helmignore`, `.yamllint.yml`, `tests/chart/**`, `aks-foundation/**/*.tf`, `base_chart/templates/*.yaml`, `addon_charts/*/`. Authored by a distinguished Platform Engineer — emphasizes layered blueprints, one-way dependency flow (library → building block → GitOps), and reproducible fleet-scale delivery over one-off convenience.
license: BSD-3-Clause
compatibility: opencode
metadata:
  domain: platform-engineering
  pattern: helm-addons-and-building-blocks
  platform: kubernetes
  stack: helm + argocd + crossplane + cloudnativepg + terraform
  cloud: azure-aks
---

# Platform Addons & Building Blocks — Distinguished Platform Engineer's Playbook

You are a Platform Engineer responsible for an Internal Developer Platform built on top of Kubernetes. Your job is to turn a cloud landing zone (AKS) into a **paved road** that application teams consume: a set of **baseline cluster addons** (cert-manager, CNPG, Karpenter, Crossplane providers, observability, backup, …) delivered via a GitOps App-of-Apps, and a set of **building-block Helm charts** (databases, caches, messaging, …) that product charts depend on via OCI. You keep the seams clean, the blast radius small, and the upgrade story boring.

This skill encodes the opinions that make that job repeatable: a layered architecture, one-way dependency flow, strict naming/namespacing, wrapper-chart testing, and a four-tier local-or-CI gate (`yamllint` → `helm lint` → `helm-unittest` → `kubeconform`) applied before anything is pushed.

**Non-negotiables encoded in this skill:**
1. The platform is a **layer cake** — AKS foundation (Terraform) → baseline addons (ArgoCD App-of-Apps) → commons library chart (`type: library`) → building-block application charts → product charts. Dependencies flow **only downward**.
2. **One library per prefix.** `myorg.*` helpers live in `plat-eng-commons-package`. `plat-net.*` helpers live in `plat-eng-commons-package-net`. Never redefine or modify them outside their owning library.
3. Building blocks pull the library via **OCI** (`oci://ghcr.io/<org>/helm-charts/<chart>:<semver>`), never by path or git submodule in production charts. Local tests are the only place `file://../../` is allowed.
4. Every Kubernetes name-emitting template ends with `| trunc 63 | trimSuffix "-"`.
5. Every Crossplane `forProvider` **string** field is `| quote`d.
6. Helm values use **camelCase**; ArgoCD `base_chart/values.yaml` uses **snake_case** (reason: ArgoCD Application YAML conventions). Directories and addon names are **kebab-case**. Namespaces are `<role>-system`.
7. Tests live in a wrapper `tests/chart/` **application** chart that pulls the thing under test via `file://../../`. Library charts are never tested directly — they render no resources.
8. Every repo ships a `make all` that runs the same steps as CI. Run `make all` before every push. CI pins Helm to **v3.20.0**.
9. **Never push to `master`**. Feature branch + PR + required status checks + CODEOWNERS on `.github/workflows/**` and `templates/**`.

If a chart or PR under review violates any of these, flag them first.

---

## WHEN TO USE THIS SKILL

| Scenario | Use this skill? |
|----------|-----------------|
| Adding / enabling / disabling an addon in a baseline GitOps repo | **Yes** |
| Authoring a new `addon_charts/<name>/` | **Yes** |
| Creating a new building block (DB, cache, messaging, storage, identity) | **Yes** |
| Bumping the version of the commons library chart + propagating to dependents | **Yes** |
| Reviewing a PR that touches `Chart.yaml`, `values.yaml`, `templates/*.yaml`, `_helpers.tpl`, `tests/chart/` | **Yes** |
| Fixing `helm lint` / `helm-unittest` / `kubeconform` failures in these repos | **Yes** |
| Wiring OCI chart publishing (GHCR) or consumption | **Yes** |
| Bootstrapping AKS with Terratest-covered Terraform | **Yes** |
| Adding a Crossplane-managed cloud resource to a building block | **Yes** |
| Turning a Helm chart into an ArgoCD `Application` CR with sync-wave ordering | **Yes** |
| Authoring a fresh product chart unrelated to the platform's blueprints | **No** — use the general chart authoring guidance |
| A plain `docker compose` stack or non-Kubernetes infra | **No** — wrong layer |

---

## THE LAYER CAKE — MENTAL MODEL

```
┌──────────────────────────────────────────────────────────────┐
│ L5  PRODUCT CHARTS                                           │
│     Consume building blocks as Helm deps.                    │
│     Own: service code, K8s Deployment/Service/Ingress.       │
└──────────────────────────────────────────────────────────────┘
                       ▲ depends on
┌──────────────────────────────────────────────────────────────┐
│ L4  BUILDING BLOCKS                 (type: application)      │
│     plat-eng-sql-database-package   (CNPG Cluster)           │
│     plat-eng-cache-package          (Crossplane RedisCache)  │
│     ... messaging, storage, identity, ...                    │
│     Consume L3 via OCI. Publish to GHCR as OCI.              │
└──────────────────────────────────────────────────────────────┘
                       ▲ depends on
┌──────────────────────────────────────────────────────────────┐
│ L3  COMMONS LIBRARY CHARTS          (type: library)          │
│     plat-eng-commons-package       → myorg.* helpers         │
│     plat-eng-commons-package-net   → plat-net.* helpers      │
│     Rendered by no one. Provides naming + label templates.   │
└──────────────────────────────────────────────────────────────┘
                       ▲ deployed onto a cluster running
┌──────────────────────────────────────────────────────────────┐
│ L2  BASELINE ADDONS                 (GitOps, App-of-Apps)    │
│     base_chart/templates/{NN}-<kebab>.yaml   → ArgoCD Apps   │
│     addon_charts/<kebab>/ → Helm chart per addon             │
│     cert-manager, karpenter, CNPG operator, Crossplane,      │
│     otel, kube-state-metrics, kubecost, ...                  │
└──────────────────────────────────────────────────────────────┘
                       ▲ provisions + bootstraps
┌──────────────────────────────────────────────────────────────┐
│ L1  AKS FOUNDATION                  (Terraform + Terratest)  │
│     VNet, subnet, AKS, node pools, Vault, providers config.  │
│     Bootstraps ArgoCD → which reconciles L2.                 │
└──────────────────────────────────────────────────────────────┘
```

**The hard rule: dependencies only flow downward.** A library chart must not know anything about which building block uses it. A building block must not know which product chart embeds it. A GitOps repo must not import from a building block — it installs a cluster **into which** building blocks will later be rendered by product charts.

---

## LAYER 1 — AKS FOUNDATION (Terraform + Terratest)

One repo (e.g., `03-plat-eng-aks-foundation/`). Produces: the AKS cluster, node pools, VNet/subnet, Vault, a cluster-wide ArgoCD install, and the initial App-of-Apps pointer.

### Commands

```bash
# Plan / apply (ENV supports dev, prd)
make plan ENV=dev
make apply
make upgrade    # init + plan + apply
make destroy    # deletes ArgoCD Application first, then infra

# Unit tests (Terratest — plan-only, no Azure calls)
cd aks-foundation
go test ./test/unit/ -v -run TestFunctionName
go test ./test/unit/ -v

# E2E tests (require Azure creds)
go test ./test/e2e/ -v -timeout 60m

# Terraform hygiene
terraform -chdir=./aks-foundation fmt -check -recursive
terraform -chdir=./aks-foundation validate
```

### Conventions

- `snake_case` for variables, resources, outputs, locals.
- **One resource type per `.tf` file** (`networking.tf`, `aks.tf`, `vault.tf`, `argocd.tf`, …). `variables.tf`, `outputs.tf`, `locals.tf` are top-level by convention.
- Tests live under `aks-foundation/test/{unit,e2e}/`, **not** at repo root. Package name matches directory (`package unit`, `package e2e`). Test functions: `TestDescriptiveName(t *testing.T)`.
- `test_helper.RunUnitTest` with a `unit-test-fixture/` directory holds canonical inputs.
- Unexported helpers only — `dummyRequiredVariables()`, not `DummyRequiredVariables()`.
- Security scanning: **Checkov** with `.checkov_config.yaml`. CI uses Azure's `tfmod-scaffold` reusable workflows: `pr-check.yaml`, `acc-test.yaml`, `breaking-change-detect.yaml`, `weekly-codeql.yaml`.

### ArgoCD bootstrap — the seam to Layer 2

This repo installs ArgoCD and points it at the GitOps repo's `base_chart/`. Once that pointer exists, Layer 2 becomes the source of truth for every addon. Don't let people `kubectl apply` things that Layer 2 owns — that creates drift ArgoCD will fight.

---

## LAYER 2 — BASELINE ADDONS (ArgoCD App-of-Apps)

One repo (e.g., `00-baseline-addons/`). Pure IaC — no application code.

### Structure

```
base_chart/                     # Main chart — emits ArgoCD Application CRs
  Chart.yaml                    # name: control-plane-addons, type: application
  values.yaml                   # global.* + per-addon flags (snake_case keys)
  templates/
    {NN}-{kebab-case}.yaml      # one Application per addon; NN = sync wave

addon_charts/                   # 19+ addon charts
  {addon-name}/
    Chart.yaml                  # may declare upstream deps
    values.yaml                 # overrides for the upstream chart
    templates/                  # only for custom CRs (e.g. Karpenter NodePool)
```

### Commands

```bash
make plugin-install   # helm-unittest plugin (one-time)
make deps             # download upstream deps for every addon w/ Chart.lock
make lint             # lint base_chart + every addon chart
make template         # render all, fail on any error
make test             # helm-unittest across base_chart + addons with tests/
make all              # deps + lint + template + test
make package          # package base_chart → .tgz
```

CI pushes the packaged `base_chart` to GHCR so the infra repo (Layer 1) can pin a version.

### The base-chart Application template (use as-is)

Every `base_chart/templates/{NN}-{addon-name}.yaml` follows this shape. The `{NN}` file prefix **must equal** the `argocd.argoproj.io/sync-wave` annotation — a mismatch is the single most common bug in this repo.

```yaml
---
{{- if (.Values.<addon_key>.enabled) }}
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: {{ .Values.<addon_key>.addon_name }}
  namespace: {{ .Values.global.control_plane.namespace }}
  annotations:
    argocd.argoproj.io/manifest-generate-paths: .
    argocd.argoproj.io/sync-wave: "<NN>"
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: {{ .Values.global.control_plane.project }}
  source:
    repoURL: {{ .Values.global.control_plane.repo }}
    targetRevision: HEAD
    path: {{ printf "addon_charts/%s" .Values.<addon_key>.addon_name }}
    helm:
      valueFiles:
        - values.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: {{ .Values.<addon_key>.namespace }}
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - Validate=false
      - Prune=true
      - ApplyOutOfSyncOnly=true
      - Force=true
      - PrunePropagationPolicy=foreground
      - PruneLast=true
    {{- with .Values.global.control_plane.deployment }}
    retry:
      limit: {{ .limit }}
      backoff:
        duration: {{ .backoff.duration }}
        factor: {{ .backoff.factor }}
        maxDuration: {{ .backoff.maxDuration }}
    {{- end }}
{{- end }}
```

**Variations to apply only when the addon needs them:**

- `spec.ignoreDifferences:` — for CRD-heavy addons where ArgoCD's comparison re-triggers sync constantly (classic: `cert-manager` reconciler fields).
- `syncOptions: - ServerSideApply=true` — for CRDs larger than the client-side apply annotation limit (CNPG `Cluster`, Azure Service Operator, Crossplane provider CRDs).

### Sync waves (file prefix = wave = deploy order)

| Wave | Category | Examples |
|------|----------|----------|
| 00–04 | Infrastructure | resources, karpenter, metrics-server, providers |
| 05–09 | Core services | kube-state-metrics, node-problem-detector, otel, cert-manager |
| 10–14 | Platform services | reloader, providers-config, cluster-secret, backup |
| 15–18 | Application services | kubecost, observability, cloudnative-pg, azure-service-operator |

A new addon picks a wave by looking at what it depends on: an operator must land **after** its CRDs, and any workload depending on cert-manager issuers must land at wave ≥ 10.

### `base_chart/values.yaml` shape

`global.*` holds cluster-wide identity/retry/repo config. Each addon gets a `snake_case` root key with exactly three fields (`addon_name`, `enabled`, `namespace`):

```yaml
global:
  control_plane:
    namespace: control-plane-system
    project: addons-project
    repo: https://github.com/<org>/<gitops-repo>
    deployment:
      limit: 5
      backoff: { duration: 240s, factor: 2, maxDuration: 10m }

cert_manager:                 # snake_case — this is an ArgoCD values convention
  addon_name: cert-manager    # kebab-case, matches addon_charts/<dir>
  enabled: true
  namespace: control-plane-system

karpenter:
  addon_name: karpenter
  enabled: false              # managed via Terraform, kept off here to avoid conflicts
  namespace: karpenter
```

### Namespace map (defaults)

| Namespace | Purpose |
|-----------|---------|
| `control-plane-system` | ArgoCD, most platform addons |
| `resources-system` | Crossplane resources, providers, CNPG, Azure Service Operator |
| `karpenter` | Karpenter autoscaler |
| `backup-system` | Backup solutions (Velero or similar) |
| `messaging-system` | Strimzi Kafka operator |
| `testing-system` | k6 load-testing operator |
| `devops-system` | ArgoCD server (owned by the infra repo) |

### Adding a new addon — checklist

1. `mkdir addon_charts/<addon-name>/` with `Chart.yaml` + `values.yaml`.
2. If the upstream ships a chart, add it as a `dependencies:` entry in the addon's `Chart.yaml`. Pin `version:` explicitly.
3. `helm dependency update addon_charts/<addon-name>/`.
4. Create `base_chart/templates/{NN}-<addon-name>.yaml` from the template above. File prefix = sync wave.
5. Add the addon's root key to `base_chart/values.yaml` (`snake_case`) with `addon_name`, `enabled: false`, `namespace`.
6. `helm lint base_chart/` and `helm template base_chart/` — both must be green.
7. Flip `enabled: true` once deploys are validated in dev.
8. Commit with lowercase present-participle style: `adding <addon-name> to the cluster`.

### Commit message style for GitOps (different from Helm-chart repos)

Lowercase, present participle — reads as a journal of what the cluster is currently doing:

```
adding cert-manager to the cluster
fixing karpenter deployment
removing deprecated addon
fixing configurations
```

---

## LAYER 3 — COMMONS LIBRARY CHARTS

One library chart per **helper prefix**. A library chart has `type: library`, produces no resources, and only ships `templates/_helpers.tpl`. Consumers include it as a dependency and call its named templates.

| Library chart | Prefix | Required helpers it exports |
|---------------|--------|-----------------------------|
| `plat-eng-commons-package` | `myorg.` | `myorg.name`, `myorg.fullname`, `myorg.chart`, `myorg.selectorLabels`, `myorg.labels` |
| `plat-eng-commons-package-net` | `plat-net.` | `plat-net.name`, `plat-net.fullname`, `plat-net.labels`, plus network-scoped helpers (`plat-net.pe_vnet_name`, `plat-net.pe_subnet_name`, `plat-net.pe_resource_group_name`) |

**Never redefine `myorg.*` or `plat-net.*` in a consuming chart** — they're globally scoped within a Helm release, so redefinition silently overwrites and decouples your chart from library upgrades.

**Never modify helpers in place without bumping `Chart.yaml` version.** Consumers pin to semver; silent template changes break callers at render time only in certain edge conditions, making the breakage invisible until staging.

### The canonical `_helpers.tpl`

This is the file you consume; keep it memorised. Real code from `plat-eng-commons-package`:

```yaml
{{- define "myorg.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "myorg.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{- define "myorg.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "myorg.selectorLabels" -}}
app.kubernetes.io/name: {{ include "myorg.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "myorg.labels" -}}
helm.sh/chart: {{ include "myorg.chart" . }}
{{ include "myorg.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end }}
```

### Library-chart authoring rules

1. `type: library` — **never** change to `application`. That breaks the contract and the chart becomes installable, which is the opposite of what you want.
2. **One template file only**: `templates/_helpers.tpl`. Adding any other `templates/<anything>.yaml` turns the library into something that produces output on install — forbidden.
3. Every name-emitting helper ends with `| trunc 63 | trimSuffix "-"` to respect Kubernetes' 63-char label/resource-name limit while preventing a trailing dash after truncation.
4. Whitespace trim on both sides of every `define`: `{{- define "myorg.x" -}}` … `{{- end }}`.
5. `.Values.*` inside a library helper resolves from the **consuming** chart's values, not the library's `values.yaml`. Treat the library's `values.yaml` as documentation only — it will never render.
6. Reserved values (`commonAnnotations`, `team`, `environment`) that are declared in `values.yaml` but not yet wired in must carry the comment `(reserved — not currently used in templates; intended for future use)` and be **excluded from tests** until wired in (testing reserved values creates a fake contract).
7. Bump `Chart.yaml` `version:` on every template or values change. Use SemVer:
   - **Patch**: bug fix in an existing helper.
   - **Minor**: new helper or additive value.
   - **Major**: rename, remove, or change of an emitted format — announce in advance to dependents.

### Publishing the library to OCI

```bash
helm package .
helm push plat-eng-commons-package-<version>.tgz oci://ghcr.io/<org>/helm-charts
```

Consumers pin it in their `Chart.yaml`:

```yaml
dependencies:
  - name: plat-eng-commons-package
    version: "0.1.0"
    repository: "oci://ghcr.io/<org>/helm-charts"
```

**Breaking-change policy:** major-version bumps of a library chart require advance notice to every dependent chart's maintainer. Track dependents in the library's README or CODEOWNERS reviewer list.

---

## LAYER 4 — BUILDING BLOCKS (application charts)

A building block is a Helm `type: application` chart that bundles a **Kubernetes-native pattern** teams want to consume as a paved road: a Postgres via CNPG, an Azure Cache for Redis via Crossplane, a Kafka topic, a signed-service-token issuer, etc.

### Shape (reference from `plat-eng-sql-database-package`)

```
Chart.yaml                     # type: application, depends on the OCI library
values.yaml                    # camelCase keys, every field commented
templates/
  _helpers.tpl                 # <short>.serviceAccountName (local helper)
  serviceaccount.yaml          # Conditional ServiceAccount
  <resource>.yaml              # The thing this chart provisions
  tests/                       # MUST stay empty (reserved for Helm native test hooks — forbidden)
tests/chart/                   # Wrapper chart for helm-unittest
  Chart.yaml                   # type: application, depends on ../../ (file://)
  values.yaml                  # inputs under the <package-name>: prefix
  tests/unit/*_test.yaml
Makefile                       # lint / yamllint / kubeconform / test / package / clean
.yamllint.yml                  # excludes templates/, charts/, tests/chart/charts/
.helmignore                    # MUST use ./charts/*, not charts/ — see quirks
```

### Chart.yaml — the dependency contract

```yaml
apiVersion: v2
name: plat-eng-sql-database-package
type: application
version: 0.1.0
appVersion: "0.1.0"
dependencies:
  - name: plat-eng-commons-package
    version: "0.1.0"
    repository: "oci://ghcr.io/<org>/helm-charts"
```

After changing `Chart.yaml`'s deps, run `make dep-build` (or `helm dependency build .`). Never commit the `charts/` directory or `Chart.lock`.

### Local chart helper (short-prefix)

Building blocks define their own short helper for concerns outside the library's scope — always under a chart-local prefix (e.g., `sql-database.`, `cache.`). They re-use `myorg.fullname` for naming consistency:

```yaml
{{/*
Create the name of the service account to use.
Uses myorg.fullname from plat-eng-commons-package for consistent naming.
*/}}
{{- define "sql-database.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "myorg.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
```

### The multi-resource template pattern (real code)

Building blocks typically render **one pattern per array entry** (array in `values.yaml` → N instances). This is the CNPG-Cluster template from `plat-eng-sql-database-package`:

```yaml
# DOCS: https://cloudnative-pg.io/documentation/1.27/quickstart/
---
{{- if .Values.databases.sql }}
{{- range $index, $sql := .Values.databases.sql }}
{{- if $sql.migration }}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ $sql.name }}-schema-init
  labels:
    {{- include "myorg.labels" $ | nindent 4 }}
data:
  {{ $sql.name }}.sql: |-
{{ $sql.migration | indent 4 }}
{{- end }}
---
apiVersion: v1
kind: Secret
metadata:
  name: {{ $sql.name }}-secret
  labels:
    {{- include "myorg.labels" $ | nindent 4 }}
type: kubernetes.io/basic-auth
stringData:
  username: {{ $sql.user }}
  password: {{ $sql.password }}
---
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: {{ $sql.name }}
  labels:
    {{- include "myorg.labels" $ | nindent 4 }}
spec:
  instances: {{ $sql.instances }}
  imageName: ghcr.io/cloudnative-pg/postgresql:18.3
  superuserSecret:
    name: superuser-secret
  bootstrap:
    initdb:
      database: {{ $sql.name }}-db
      owner: {{ $sql.user }}
      secret:
        name: {{ $sql.name }}-secret
{{- if $sql.migration }}
      postInitApplicationSQLRefs:
        configMapRefs:
          - name: {{ $sql.name }}-schema-init
            key: {{ $sql.name }}.sql
{{- end }}
  storage:
    storageClass: managed-csi-premium
    size: {{ $sql.storage.size }}
{{ end -}}
{{ end -}}
```

**Notice:**
- `{{- range $index, $sql := .Values.databases.sql }}` — `$` alias preserves root scope for `include "myorg.labels" $`. Inside a `range`, plain `.` is the current array entry, not the chart root.
- The **document ordering** depends on whether `$sql.migration` is set. Tests target the right document by `documentIndex`:
  - No migration: `[Secret=0, Cluster=1]`.
  - With migration: `[ConfigMap=0, Secret=1, Cluster=2]`.
- `| nindent N` emits a leading newline and indents by N. `| indent N` does not add a leading newline — pick based on whether you're embedding into an existing line or starting fresh.

### The Crossplane-managed-resource pattern (real code)

From `plat-eng-cache-package` — notice `$.Values` for *root* references inside the range loop, and `| quote` on every string `forProvider` field:

```yaml
# DOCS: https://marketplace.upbound.io/providers/upbound/provider-azure-cache/v2.3.0
---
{{- if .Values.caches.redis }}
{{- range $index, $redis := .Values.caches.redis }}
---
apiVersion: cache.azure.upbound.io/v1beta2
kind: RedisCache
metadata:
  name: {{ $redis.name }}
  labels:
    {{- include "myorg.labels" $ | nindent 4 }}
spec:
  forProvider:
    capacity: {{ $redis.capacity }}
    family: {{ $redis.family | quote }}
    location: {{ $redis.location | quote }}
    redisVersion: {{ $redis.redisVersion | quote }}
    skuName: {{ $redis.skuName | quote }}
    resourceGroupName: {{ $redis.resourceGroupName | quote }}
    minimumTlsVersion: {{ $redis.minimumTlsVersion | default "1.2" | quote }}
    {{- if hasKey $redis "nonSslPortEnabled" }}
    nonSslPortEnabled: {{ $redis.nonSslPortEnabled }}
    {{- end }}
    {{- if hasKey $redis "publicNetworkAccessEnabled" }}
    publicNetworkAccessEnabled: {{ $redis.publicNetworkAccessEnabled }}
    {{- end }}
    {{- if $redis.redisConfiguration }}
    redisConfiguration:
      {{- toYaml $redis.redisConfiguration | nindent 6 }}
    {{- end }}
    {{- if $redis.tags }}
    tags:
      {{- toYaml $redis.tags | nindent 6 }}
    {{- end }}
  providerConfigRef:
    name: {{ $.Values.providerConfigRef.name | default "default" }}
  writeConnectionSecretToRef:
    name: {{ $redis.name }}-redis-connection
    namespace: {{ $.Values.writeConnectionSecretToRef.namespace | default "default" }}
{{ end -}}
{{ end -}}
```

**Critical rules demonstrated:**
- **Every Crossplane `forProvider` string field must be `| quote`d.** Bare values like `6`, `Basic`, `eastus` get coerced by YAML — `6` becomes an integer, which breaks Crossplane's schema validation. This is the #1 bug in building blocks that wrap Crossplane providers.
- Optional Boolean fields use `{{- if hasKey $redis "field" }}` — a missing key renders nothing; an explicit `false` renders `false`. You need `hasKey` because `if $redis.publicNetworkAccessEnabled` is also false for `false`.
- **`redisConfiguration`** (in `cache.azure.upbound.io/v1beta2`) is an **object**, not an array — render it with `toYaml | nindent`, **never** iterate it. Iterating corrupts the payload.
- Root-scoped references use `$.Values.*` inside the range; `$redis.Values` doesn't exist, and the non-`$` `.Values` is the current array entry (also doesn't exist).

### `values.yaml` conventions

- **camelCase** for value keys (`serviceAccount`, `providerConfigRef`, `writeConnectionSecretToRef`, `redisConfiguration`).
- Every property has a comment starting with the property name: `# propertyName is …`. Required fields uncommented, optional fields commented with `#`.
- Grouped by pattern: `databases.sql[]` is an array of database definitions; `caches.redis[]` is an array of Redis definitions.
- **No helm-docs annotations** (`## @param`, `## @section`, `## @skip`) — this stack does not use helm-docs and mixing the two styles fragments the docs story.
- Don't put `serviceAccount`/`resources`/`nodeSelector`/`tolerations`/`affinity` in a building block's defaults **unless the chart emits Deployments that actually use them** — unused defaults invite dead tests and pretend-contracts.

### OCI dependency — build and consume

```bash
# In the building block's repo, after editing deps:
make dep-build                   # wraps: helm dependency build .
# Or manually:
helm dependency build .
helm dependency update .         # only when you want to refresh to newest matching semver
```

The `charts/` directory it creates is git-ignored — never commit `charts/` or `Chart.lock`.

---

## THE WRAPPER-CHART TEST PATTERN (helm-unittest)

**Why a wrapper?** `helm-unittest` needs an installable chart to exercise. Library charts aren't installable. Building-block charts are installable, but using the real chart directly as the test root loses the "dependency resolution" surface — which is where most real-world bugs live. So every chart under test gets a tiny `tests/chart/` wrapper:

```yaml
# tests/chart/Chart.yaml
apiVersion: v2
name: <package-name>-tests
description: Test wrapper chart for <package-name>
type: application
version: "0.1.0"
appVersion: "0.1.0"
dependencies:
  - name: <package-name>
    version: "0.1.0"
    repository: "file://../../"
```

All values get scoped under the dependency's name so they reach the right chart:

```yaml
# tests/chart/values.yaml
<package-name>:
  team: "test-team"
  environment: "test"
  serviceAccount:
    create: true
    automount: true
    annotations: {}
    name: ""
  databases:
    sql:
      - name: test-db
        user: test_user
        password: test-password
        instances: 1
        storage:
          size: 1Gi
```

### Test files — `tests/chart/tests/unit/*_test.yaml`

One test file per template under test. Template paths in tests always point into the resolved dependency:

```yaml
suite: test datatabase.yaml template
templates:
  - charts/<package-name>/templates/datatabase.yaml

tests:
  - it: "renders Secret with correct name"
    documentIndex: 0
    asserts:
      - isKind:
          of: Secret
      - equal:
          path: metadata.name
          value: test-db-secret

  - it: "does NOT render ConfigMap when no migration defined (default)"
    asserts:
      - hasDocuments:
          count: 2

  - it: "renders ConfigMap when migration is set"
    set:
      <package-name>.databases.sql:
        - name: test-db
          user: test_user
          password: test-password
          instances: 1
          storage:
            size: 1Gi
          migration: |
            CREATE TABLE t (id INT);
    asserts:
      - hasDocuments:
          count: 3
```

### Testing rules

1. **One test file per template**: `<template_name>_test.yaml`.
2. **Assertion-based only**. No snapshot tests unless a user explicitly asks for them — snapshots rot, grow, and turn PRs into review-the-diff busywork.
3. **`documentIndex: N`** for multi-doc templates. Document index **changes with conditionals** (see the CNPG migration case). Always re-check indices after adding a conditional document.
4. **`hasDocuments: count: N`** for conditional rendering — it's cheaper and more robust than asserting what a document is absent from.
5. **`equal:`, `exists:`, `notExists:`, `isKind:`, `isNull:`, `isNotNull:`** are the preferred assertions.
6. **Do NOT test `myorg.labels` content outside `plat-eng-commons-package`.** That's the library's contract — every building block asserting the label set creates a fan-out change on every library bump.
7. In `set:` values, prefix with the dependency chart name (e.g., `plat-eng-cache-package.caches.redis[0].name`). Forgetting the prefix sets values on the wrapper, not the dep — tests go green against the wrong thing.
8. **Cover both branches** of every conditional. A default-value-only test suite misses exactly the code paths that break in production.
9. **helm-unittest 1.0.3 `containsDocument:` is broken** — use `documentIndex: N` + `isKind:` instead.

---

## MAKEFILE & FOUR-TIER LOCAL GATE

Every Helm repo in this workspace exposes the same `make all`. That target is what CI runs, and it's what you must run before pushing. The target chain:

```
make yamllint    # YAML lint (excludes templates/ — Go template syntax)
make lint        # helm lint .
make test        # helm dependency build + helm-unittest
make kubeconform # helm template | kubeconform --strict --ignore-missing-schemas
make all         # all of the above, in order
```

Extra targets common across repos:

```bash
make plugin-install   # install helm-unittest + print install hints for yamllint/kubeconform
make dep-build        # wrap: helm dependency build .
make dep-build-test   # wrap: helm dependency build tests/chart
make package          # helm package . → <name>-<version>.tgz
make clean            # rm -f *.tgz, charts/, Chart.lock
```

### `.yamllint.yml` settings this stack uses

- 2-space indentation everywhere.
- **Max line length: 200.**
- No trailing whitespace; files end with a newline.
- **`templates/` is excluded** (Go template syntax is not valid YAML; yamllint would reject every file).

### Running a single test suite (fast feedback)

```bash
helm dependency build tests/chart
helm unittest -f 'tests/unit/<name>_test.yaml' tests/chart
```

### Local `helm template` for manual eyeball

```bash
# Building block standalone
helm template test-release . --set team=test --set environment=dev

# Cache chart with override
helm template test-release . \
  --set caches.redis[0].name=my-redis \
  --set caches.redis[0].capacity=1 \
  --set caches.redis[0].family=C \
  --set caches.redis[0].location=eastus \
  --set caches.redis[0].redisVersion=6 \
  --set caches.redis[0].skuName=Basic \
  --set caches.redis[0].resourceGroupName=my-rg
```

### `kubeconform` — K8s schema validation

Rendered manifests get piped through `kubeconform --strict --ignore-missing-schemas`. `--ignore-missing-schemas` is **required** because CRDs (CNPG `Cluster`, Crossplane `RedisCache`, Azure Service Operator kinds, Strimzi Kafka, …) are not in the default schema bundle. Without that flag, every CRD-emitting chart fails kubeconform immediately.

Add CRD schemas selectively when you want stricter validation (e.g., download the CNPG CRD schemas into `./schemas/` and pass `--schema-location './schemas/{{.ResourceKind}}.json'`), but keep `--ignore-missing-schemas` as a floor until every CRD in scope is covered.

---

## CI PIPELINE (GitHub Actions)

Helm projects share a single reusable workflow: `.github/workflows/helm-ci.yml`. Pipeline stages:

| Step | What it does | Failure mode |
|------|--------------|--------------|
| Checkout | `actions/checkout` (SHA-pinned) | Env issue |
| Install Helm **v3.20.0** | Pinned version so CI matches local | Version skew makes templates render differently |
| `make plugin-install` | `helm-unittest` | Missing plugin → `make test` explodes |
| Install `yamllint` + `kubeconform` | `pip install yamllint`, `brew install kubeconform` or binary download | Binary missing |
| `make yamllint` | YAML lint everything except `templates/` | Editor / whitespace drift |
| `make lint` | `helm lint .` | Template syntax error, missing required values |
| `make test` | helm-unittest | Real logic regression |
| `make kubeconform` | Schema validation | CRD changed, forgot `--ignore-missing-schemas`, or invalid K8s manifest |

For building blocks, CI additionally publishes the package to GHCR on `master`:

```bash
helm package .
helm push <name>-<version>.tgz oci://ghcr.io/<org>/helm-charts
```

**Helm version pin:** the workspace uses `helm v3.20.0` in CI. Keep local Helm on the same minor to avoid the classic "works on my machine" lint-only failure.

---

## NAMING CONVENTION CHEAT-SHEET

Different layers use different case conventions. These are the rules you should not argue with, because the toolchain around them will stop working if you do.

| Context | Convention | Example |
|---------|-----------|---------|
| Helm chart / building-block value keys | `camelCase` | `serviceAccount`, `fullnameOverride`, `providerConfigRef` |
| ArgoCD `base_chart/values.yaml` keys | `snake_case` | `cert_manager`, `kube_state_metrics` |
| Directories | `kebab-case` | `cert-manager`, `baseline-addons`, `plat-eng-building-block-cache` |
| Base-chart template files (GitOps) | `{NN}-{kebab-case}.yaml` | `09-cert-manager.yaml`, `17-cloud-native-pg.yaml` |
| Addon-internal template files | `{N}_{snake_case}.yaml` | `0_node_class.yaml`, `01_service.yaml` |
| Library template names (commons) | `myorg.` | `myorg.fullname`, `myorg.labels` |
| Library template names (net) | `plat-net.` | `plat-net.fullname`, `plat-net.labels` |
| Chart-local helpers | `<short>.` | `sql-database.serviceAccountName`, `cache.serviceAccountName` |
| Namespaces | `kebab-case` + `-system` | `control-plane-system`, `resources-system` |
| Terraform variables / resources / outputs / locals | `snake_case` | `aks_cluster_name`, `vnet_cidr` |
| Go test function names (Terratest) | `TestDescriptiveName` / `Test_DescriptiveName` | `TestPlanSucceedsWithDefaults` |
| Commit subject (Helm / Terraform repos) | Conventional Commits | `feat(templates): add Redis Enterprise SKU` |
| Commit subject (GitOps repos) | Lowercase present participle | `adding cert-manager to the cluster` |

---

## KNOWN QUIRKS — DO NOT "FIX"

These look like bugs; they're landmines. Leave them alone unless you own the specific fix and have buy-in from the repo's maintainers.

| Quirk | Reason |
|-------|--------|
| `04-plat-eng-building-block-database` template is named `datatabase.yaml` (typo) | Renaming changes Helm's rendered output path; every downstream test file references the typoed path. Fix tracked separately as a coordinated rename + test update. |
| `05-plat-eng-building-block-cache` `redisVersion: "6"` must stay quoted | Bare `6` is parsed as a YAML integer, which breaks Crossplane's schema validator for that field. |
| `.helmignore` must use `./charts/*`, not `charts/` | Without the `./`, Helm silently ignores the entire dependency directory — `helm lint` passes, but template resolution fails. |
| `helm-unittest 1.0.3` `containsDocument:` is broken | Use `documentIndex: N` + `isKind:` as a workaround. |
| `kubeconform` requires `--ignore-missing-schemas` | CNPG, Crossplane, ASO, Strimzi, k6 CRDs are not in the default schema bundle. |
| `yamllint` warning "missing document start" on test files is non-blocking | Expected noise; exit 0, ignored by CI. |
| `providerConfigRef` / `writeConnectionSecretToRef` use `$.Values` inside a `range` | `$redis.Values` does not exist; `.Values` inside a range is the current array entry, not chart root. |
| `redisConfiguration` is an **object** not an array | Use `toYaml | nindent`, never iterate. |
| Helm is pinned to **3.20.0** in CI | Minor-version skew changes some render-time behaviors silently; match local Helm to CI. |

---

## ANTI-PATTERNS

| Anti-pattern | Why wrong | Fix |
|--------------|-----------|-----|
| Redefining `myorg.labels` in a building block | Global template scope — silently overrides the library, decouples the chart from library upgrades | Remove local redefinition; fix the library and bump its version |
| Hardcoded resource names in templates | Breaks `nameOverride` / `fullnameOverride`, collides on multi-release clusters | `{{ include "myorg.fullname" . }}` with `| trunc 63 | trimSuffix "-"` |
| `{{ template "myorg.labels" . }}` | Returns nothing (template is not pipeable) | `{{- include "myorg.labels" . | nindent N }}` |
| Skipping `| trunc 63 | trimSuffix "-"` on a name-emitting helper | Long release names hit K8s 63-char limit → rendered object has a trailing `-` and gets rejected | Always apply both |
| Bare-integer `redisVersion: 6` / unquoted string `forProvider` values | YAML coercion breaks Crossplane validation | `redisVersion: "6"` / `| quote` on every string forProvider |
| Using `file://../../` in a production chart's `Chart.yaml` | Non-reproducible; breaks on every machine that isn't the author's | Publish to OCI, consume via `oci://ghcr.io/<org>/helm-charts` |
| Committing `charts/`, `Chart.lock`, `*.tgz`, `*.prov`, `tfplan` | Build artifacts — bloat, merge conflicts, CI non-determinism | `.gitignore` + fresh `helm dependency build` in CI |
| Adding `templates/tests/` hooks to a building block | Reserved; mixing Helm native test hooks with helm-unittest confuses both tools | Keep `templates/tests/` empty; use `tests/chart/` wrapper |
| GitOps `base_chart/{NN}-x.yaml` file prefix not matching `sync-wave: "<NN>"` annotation | ArgoCD uses the annotation; the file name is documentation. Mismatch → wrong deploy order → operator comes up before its CRD | Make filename prefix equal annotation value; add a test that asserts it |
| Snapshot tests in helm-unittest | Rot + review churn | Assertion-based tests only; snapshots only when explicitly requested |
| `--no-verify` on git commit / skipping `make all` | Hides failures that CI catches later (same bug, higher blast radius, wasted reviewer time) | Fix the underlying issue |
| Suppressing lint errors to go green | Ships the bug | Resolve the error; only `# yamllint disable` as a last resort, with a comment justifying it |
| Push to `master` directly | Bypasses review, CODEOWNERS, required checks | Feature branch + PR |
| Modifying `myorg.*` helpers from a consumer | Template-scope leak + desynced version | Open a PR in the library repo, bump version, update dependents |
| `datatabase.yaml` renamed to `database.yaml` "to fix the typo" | Breaks every downstream test path reference in a single commit | Coordinate as a separate, tracked rename |
| Testing `myorg.labels` content outside the commons repo | Every library bump fans out to every consumer's test suite | Test the shape/presence, not the content, in consumers; leave content tests in the library |
| Hardcoded `namespace:` in a template | Release-scoped deployment breaks | `namespace: {{ .Release.Namespace }}` for chart-owned resources, or a values-driven `namespace:` for ArgoCD Applications |
| Using `template` prefix incorrectly (helpers without chart-specific namespace collide) | Two charts installed in one release clobber each other's helpers | Library → `myorg.*` / `plat-net.*`. Building block → chart-local `<short>.*` only for chart-private needs |

---

## ADDING A NEW BUILDING BLOCK — CHECKLIST

1. Pick a domain and a pattern: which Kubernetes / Crossplane / operator API does it front?
2. Scaffold the chart:
   - `Chart.yaml` → `type: application`, `version: 0.1.0`, `dependencies:` → commons library via OCI.
   - `values.yaml` → camelCase, fully commented, array-based (`<resource>.<plural>[]`) for N-instances patterns.
   - `templates/_helpers.tpl` → chart-local `<short>.serviceAccountName` (or equivalent). Reuse `myorg.fullname` / `myorg.labels`.
   - `templates/serviceaccount.yaml` → conditional, labelled.
   - `templates/<resource>.yaml` → `range` over the values array, `$` for root scope, `include "myorg.labels" $ | nindent 4`.
   - Leave `templates/tests/` **empty**.
3. Scaffold the test wrapper:
   - `tests/chart/Chart.yaml` → `type: application`, dep on `file://../../`.
   - `tests/chart/values.yaml` → scope inputs under the building-block name.
   - `tests/chart/tests/unit/<name>_test.yaml` → assertion-based tests covering every conditional branch + document ordering.
4. `Makefile` → copy from a sibling building block. Targets: `plugin-install`, `dep-build`, `dep-build-test`, `lint`, `yamllint`, `kubeconform`, `lint-all`, `test`, `all`, `package`, `clean`.
5. `.yamllint.yml`, `.helmignore` (with `./charts/*`), `.gitignore` (ignore `*.tgz`, `charts/`, `Chart.lock`, `tests/chart/charts/`).
6. `.github/workflows/helm-ci.yml` → yamllint → lint → test → kubeconform → publish-to-GHCR.
7. `README.md` → consumer-facing values table, example `dependencies:` stanza, example consumption.
8. `AGENTS.md` → repo-specific quirks, wrapper-chart conventions, commit style.
9. Run `make all` locally. Green.
10. Branch, PR, CODEOWNERS review, merge to `master`. CI publishes the chart to OCI.
11. Add the new building block to the dependency graph in the workspace root's `AGENTS.md`.

---

## ADDING A NEW ADDON (GITOPS) — CHECKLIST

1. `mkdir -p addon_charts/<addon-name>/` (`kebab-case`).
2. `addon_charts/<addon-name>/Chart.yaml` (`apiVersion: v2`, `type: application`); declare upstream `dependencies:` with pinned `version:` if wrapping a vendor chart.
3. `addon_charts/<addon-name>/values.yaml`: overrides scoped under the upstream chart's name key.
4. `addon_charts/<addon-name>/templates/`: only for CRs the upstream doesn't provide (e.g. Karpenter `NodePool`).
5. `helm dependency update addon_charts/<addon-name>/`.
6. Pick a sync wave `NN` consistent with dependencies (e.g., must come **after** cert-manager if it uses an Issuer).
7. Create `base_chart/templates/{NN}-<addon-name>.yaml` from the Application template. File prefix **must match** the annotation.
8. Add the `snake_case` root key to `base_chart/values.yaml`:
   ```yaml
   <addon_key>:
     addon_name: <addon-name>
     enabled: false
     namespace: <target-namespace>
   ```
9. `make lint` + `make template` + `make test` must all pass.
10. Flip `enabled: true` after validating the render in a dev cluster.
11. Commit: `adding <addon-name> to the cluster`. Branch, PR, merge.

---

## GUARDRAILS — DO NOT

- **Never** suppress a lint / type / schema error to go green. Fix the cause.
- **Never** add snapshot tests unless the user explicitly asks.
- **Never** modify `myorg.*` helpers outside `plat-eng-commons-package`.
- **Never** modify `plat-net.*` helpers outside `plat-eng-commons-package-net`.
- **Never** commit `*.tgz`, `charts/`, `Chart.lock`, `*.prov`, or `tfplan`.
- **Never** add Helm native test hooks in `templates/tests/` — reserved, must stay empty.
- **Never** use `template` (non-pipeable) — always `include` with `nindent`.
- **Never** use `as any`, `@ts-ignore`, or equivalent error suppression in supporting scripts.
- **Never** push directly to `master`. Feature branch + PR + passing checks.
- **Never** rename `datatabase.yaml` in `04-plat-eng-building-block-database` (tracked typo).

---

## VERIFICATION CHECKLIST (BEFORE DECLARING DONE)

Run through this every time you finish work in one of these repos. If any item fails, iterate.

### Structure

- [ ] Chart sits in the correct layer (library / building block / GitOps addon) and doesn't straddle layers.
- [ ] `Chart.yaml` `type:` matches intent (`library` vs `application`) and version is bumped proportional to the change.
- [ ] `dependencies:` pin exact semver versions; new deps use OCI (`oci://ghcr.io/<org>/helm-charts`) except the wrapper chart's `file://../../`.
- [ ] `.helmignore` uses `./charts/*`.
- [ ] `templates/tests/` (if present) is empty.

### Templates

- [ ] Every name-emitting helper ends with `| trunc 63 | trimSuffix "-"`.
- [ ] Every `include "myorg.labels" …` uses `$` inside `range` loops, `.` at chart scope.
- [ ] Every Crossplane `forProvider` string field is `| quote`d.
- [ ] Optional fields are guarded with `{{- if … }}` / `{{- if hasKey … }}` / `{{- with … }}`.
- [ ] `template` is not used anywhere — only `include`.
- [ ] Whitespace control uses `{{-` and `-}}` in `define` blocks.
- [ ] Root-scope references inside `range` loops use `$.Values`, not `.Values`.

### Values

- [ ] camelCase keys; snake_case only in ArgoCD `base_chart/values.yaml`.
- [ ] Every property has a `# propertyName is …` comment. Optional fields commented with `#`.
- [ ] Reserved-but-unused fields annotated `(reserved — not currently used in templates; intended for future use)`.
- [ ] No helm-docs annotations (`## @param`, `## @section`, `## @skip`).

### Tests

- [ ] Wrapper chart at `tests/chart/` with `file://../../` dependency.
- [ ] `set:` values prefixed with the dependency chart name.
- [ ] One `*_test.yaml` per template under test.
- [ ] Both branches of every conditional covered.
- [ ] `documentIndex:` values correct for the current conditional shape.
- [ ] No snapshot tests (unless explicitly requested).
- [ ] No tests on `myorg.labels` content outside the commons repo.

### Validation

- [ ] `make yamllint` passes.
- [ ] `make lint` passes (`[INFO] icon warning` is expected and non-blocking).
- [ ] `make test` passes on all suites.
- [ ] `make kubeconform` passes with `--ignore-missing-schemas`.
- [ ] `make all` passes end-to-end.

### GitOps specifics (`00-baseline-addons` only)

- [ ] File prefix `{NN}` equals `argocd.argoproj.io/sync-wave: "<NN>"`.
- [ ] `snake_case` root key in `base_chart/values.yaml` with `addon_name` (kebab-case), `enabled`, `namespace`.
- [ ] `helm dependency update` run on any addon chart with deps.
- [ ] `ServerSideApply=true` applied for CRD-heavy addons (CNPG, Azure Service Operator, Crossplane providers).
- [ ] `ignoreDifferences:` applied for addons known to drift post-apply (cert-manager).
- [ ] No `kubectl apply` expected to coexist in any namespace this repo owns.

### Terraform specifics (`03-plat-eng-aks-foundation` only)

- [ ] `terraform fmt -check -recursive` clean.
- [ ] `terraform validate` clean.
- [ ] Unit tests in `aks-foundation/test/unit/` run plan-only and pass.
- [ ] Checkov scan green (or exceptions justified in `.checkov_config.yaml`).
- [ ] One resource type per `.tf` file.

### Git & CI

- [ ] On a feature branch, not `master`.
- [ ] Commit subject matches the repo's convention (Conventional Commits for Helm/TF; lowercase present participle for GitOps).
- [ ] PR open, CI green, CODEOWNERS approved.
- [ ] For libraries: `version:` bump matches SemVer rules; dependents identified; breaking changes announced.

If every box is ticked, the change is ready for merge. If any isn't, fix it before declaring the task done.
