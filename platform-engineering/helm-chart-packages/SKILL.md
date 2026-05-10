---
name: helm-chart-packages
description: 'MUST USE when authoring, reviewing, or modifying any Helm chart artifact — `Chart.yaml`, `values.yaml`, `values.schema.json`, `templates/*.yaml`, `templates/_*.tpl`, `templates/NOTES.txt`, `templates/tests/*`, `crds/*`, `charts/*`, `.helmignore`, `*.tgz`, `*.tgz.prov`, `requirements.lock`, `Chart.lock`, or any file under a `helm/`, `charts/`, or `chart/` directory. Use when the user asks to "create a Helm chart", "package a Helm chart", "publish a chart", "push to OCI registry", "sign a chart", "verify a chart", "write chart hooks", "add chart tests", "build a library chart", "split into subcharts", "add Helm dependencies", "lint a chart", "debug a template", "render templates locally", "rollback a release", "upgrade a release", "write helmfile", "convert kubectl manifests to a chart", "add app.kubernetes.io labels", or any "helm install/upgrade/template/package/push/lint" operation. Covers Chart.yaml v2 contract, SemVer 2 versioning + appVersion split, values.yaml conventions, JSON-Schema-validated values, Go template + Sprig idioms, named templates (`define` / `include` / `template`), standard labels (`app.kubernetes.io/*`, `helm.sh/chart`), subcharts + globals + import-values, library charts (`type: library`), chart hooks (`helm.sh/hook` events, `hook-weight`, `hook-delete-policy`), chart tests (`helm.sh/hook: test`), CRD handling (`crds/` vs `templates/`), RBAC layout, pod template hygiene, packaging (`helm package`), provenance signing (PGP `.prov` + `helm package --sign` + `helm verify`), OCI registry distribution (`helm push oci://`, `oci://...@sha256:` digest pinning), lifecycle commands (install / upgrade / rollback / uninstall / list / history / status), linting + debugging (`helm lint`, `helm template --debug`, `helm install --dry-run --debug`, `helm get manifest`), and `.helmignore`. Authored by a distinguished Platform Engineer — emphasizes supply-chain integrity, immutable references, fleet-wide labelling consistency, and rollback-safe upgrade patterns over one-off convenience.'
license: BSD-3-Clause
compatibility: opencode
metadata:
  domain: platform-engineering
  pattern: kubernetes-package-management
  platform: helm
  artifact: chart
---

# Helm Chart Packages Skill — Distinguished Platform Engineer's Playbook

You are a Platform Engineer responsible for the Helm charts an organization ships to its fleet of Kubernetes clusters. Your job is to enforce **a chart contract**, **supply-chain integrity** (signing + immutable digests), **rollback safety**, and **fleet-wide consistency** (standard labels, SemVer discipline, JSON-schema-validated values) while keeping the developer experience simple. This skill synthesizes the official Helm reference — Chart.yaml fields, the Chart Template Guide, Best Practices, hooks, tests, library charts, OCI registries, provenance — into rules you apply every time a chart, release operation, or distribution artifact is touched.

---

## 0. Non-negotiable rules

These hold for every chart you author or review. They are listed first because most reviews are about catching their absence, not their presence.

1. **`apiVersion: v2`** in `Chart.yaml`. `v1` is Helm 2 legacy. The `dependencies:` block must live in `Chart.yaml` (not in a separate `requirements.yaml`).
2. **SemVer 2 for `version:`**, even pre-1.0. Bump `version` on every chart change — even a YAML whitespace edit. `appVersion` is a **separate** field that tracks the upstream application's version and is **not required** to be SemVer.
3. **One chart, one purpose.** A chart deploys *one* application. Multi-app stacks are composed via subcharts, never via a single mega-chart.
4. **Render must be deterministic.** Avoid `randAlphaNum`, `now`, `uuidv4`, and other non-deterministic functions in the *value* of a manifest field — they break `helm upgrade`'s diff (the value changes every render). They are acceptable in `metadata.annotations` used as cache-busters.
5. **Standard labels everywhere.** Every Kubernetes resource carries the seven `app.kubernetes.io/*` + `helm.sh/chart` labels (see §8). Selectors (Service `selector`, Deployment `spec.selector.matchLabels`) use the *immutable* subset — `app.kubernetes.io/name` + `app.kubernetes.io/instance` — never the mutable ones (`app.kubernetes.io/version`, `helm.sh/chart`).
6. **`values.yaml` is documented**, ships sane defaults, and is paired with **`values.schema.json`** so `helm install / upgrade / lint / template` can fail-fast on bad inputs.
7. **CRDs go in `crds/`, not `templates/`.** Helm installs `crds/` once and then **never upgrades or deletes them**. If the chart needs CRD upgrade lifecycles, document the manual `kubectl apply` workflow in `NOTES.txt`.
8. **No secrets in `values.yaml`.** Use SealedSecrets / SOPS / external-secrets / Helm Secrets — never commit plaintext passwords or API keys to a chart's defaults.
9. **Pin every dependency.** `dependencies[*].version` is an exact SemVer or a tilde range — never `*` or `>=`. Run `helm dependency update` and **commit `Chart.lock`** alongside `Chart.yaml`.
10. **Sign packaged charts** for any chart that crosses a trust boundary (public repo, GHCR, ECR, Artifactory). `helm package --sign` produces a `.prov` provenance file; downstream installs use `--verify`. For OCI distribution, additionally pin by **immutable digest** (`oci://repo/chart@sha256:…`) in production, not by mutable tag.
11. **Lint and dry-run before publish.** `helm lint` + `helm template --debug` + `helm install --dry-run=server --debug` are not optional. CI runs all three.
12. **Hooks own their lifecycle.** Every hook resource declares `helm.sh/hook-delete-policy` so abandoned `Job` / `Pod` resources do not accumulate. Test hooks use `helm.sh/hook: test` and live under `templates/tests/`.

---

## 1. Chart skeleton

```text
mychart/
├── Chart.yaml              # chart metadata (REQUIRED)
├── Chart.lock              # generated by `helm dependency update`; commit it
├── values.yaml             # default values (REQUIRED — even if empty {})
├── values.schema.json      # JSON Schema validating .Values (REC)
├── README.md               # human docs (REC)
├── LICENSE                 # OSS license text (REC)
├── .helmignore             # files excluded from package + .Files
├── crds/                   # raw CRD YAML — installed once, never upgraded
│   └── mycrd.yaml
├── templates/
│   ├── _helpers.tpl        # named templates (define / include)
│   ├── NOTES.txt           # post-install message (rendered as template)
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── serviceaccount.yaml
│   ├── configmap.yaml
│   ├── networkpolicy.yaml
│   ├── poddisruptionbudget.yaml
│   ├── hpa.yaml
│   └── tests/
│       └── test-connection.yaml   # `helm.sh/hook: test`
└── charts/                 # subchart copies — populated by `helm dep update`
    └── (do not commit downloaded subchart tgz; commit Chart.lock instead)
```

Hidden rules:

- **`templates/` filenames** beginning with `_` (`_helpers.tpl`) are **never rendered** as standalone manifests. Use that prefix for partials.
- **`templates/NOTES.txt`** is the *only* file in `templates/` that is rendered as plain text rather than YAML. It is printed after `helm install / upgrade`.
- **`charts/` is generated.** Treat it like `node_modules` — exclude `*.tgz` from VCS, commit `Chart.lock` only. CI runs `helm dependency update` to repopulate.
- **`.helmignore`** uses the same syntax as `.gitignore`. Default ignores: `.git/`, `*.swp`, `OWNERS`, `.idea/`, `*.tmproj`. Anything not ignored is included in the packaged tarball **and** appears under `.Files` for templates.

---

## 2. `Chart.yaml` — the contract

```yaml
apiVersion: v2                  # REQUIRED — v2 is Helm 3+
name: mychart                   # REQUIRED — must match the directory name
version: 1.4.2                  # REQUIRED — SemVer 2; bump on every change
type: application               # application (default) | library

# Optional but expected in production charts:
appVersion: "1.27.3"            # quoted — non-SemVer values are valid
kubeVersion: ">=1.27.0-0"       # SemVer range; failed at install time if unmet
description: A short, single-sentence description of what this chart deploys
home: https://example.com/mychart
icon: https://example.com/mychart.png
keywords:
  - kubernetes
  - operator
sources:
  - https://github.com/example/mychart
maintainers:
  - name: Platform Team
    email: platform@example.com
    url: https://example.com/team
deprecated: false               # set true to warn on `helm install`
annotations:
  # Free-form metadata — used by Artifact Hub, Renovate, etc.
  artifacthub.io/changes: |
    - kind: added
      description: NetworkPolicy support
  artifacthub.io/license: Apache-2.0

dependencies:
  - name: postgresql
    version: 13.2.24            # exact SemVer pin — never `*` or `>=`
    repository: oci://registry-1.docker.io/bitnamicharts
    condition: postgresql.enabled
    tags:
      - database
    alias: pg                   # subchart accessed via .Values.pg
    import-values:
      - child: tls
        parent: tls
```

Field discipline:

- `appVersion` should be **quoted**. Two-segment values (`1.27`) parse as **floats** in YAML; date-shaped values (`2024-05-15`) parse as **dates**. Both lose their string identity. `1.27.3` happens to be safe (three-segment dotted strings stay strings) but quote it anyway for consistency: `appVersion: "1.27.3"`.
- `kubeVersion` ranges follow Masterminds/semver — use `>=1.27.0-0` (the `-0` lets pre-release Kubernetes versions like `1.28.0-rc.1` satisfy the constraint).
- `dependencies[*].condition` references a values path that resolves to a boolean — pair with `enabled: true|false` keys in `values.yaml`. `tags` are coarser (group enable/disable). **`condition` overrides `tags`** when both apply.
- `import-values` lifts subchart values into the parent's `.Values` namespace — useful for sharing TLS config across charts without duplicating defaults.

---

## 3. Versioning discipline

Two versions live in `Chart.yaml`. Treat them differently.

| Field | What it tracks | Bump on |
|-------|----------------|---------|
| `version` | The chart itself (template + values changes) | **Every** chart edit. SemVer 2. Major = breaking values schema. Minor = new feature, backward compatible. Patch = bug fix only. |
| `appVersion` | The bundled application image | Image / binary bump. May be non-SemVer (e.g. `2024-05-15`, `1.27.3-distroless`). Always quote. |

Common mistakes:

- Bumping only `appVersion` when `image.tag` defaults change. Wrong — chart consumers pin by `version`, not `appVersion`. Bump both.
- Reusing a `version` after a release. Charts are content-addressable in OCI — any byte change requires a new `version`.
- Releasing `0.x` indefinitely. Once charts have downstream consumers, cut a `1.0.0` to commit to a stable values schema. Schema changes after `1.0.0` are major bumps.

---

## 4. `values.yaml` conventions

Defaults are part of the contract. Every key the templates consume must have a default in `values.yaml`, even if `null`, so `helm template` does not blow up with `nil pointer evaluating interface {}`.

```yaml
# values.yaml
replicaCount: 1

image:
  repository: ghcr.io/example/mychart
  tag: ""                     # empty defaults to .Chart.AppVersion (see §6)
  pullPolicy: IfNotPresent
  pullSecrets: []

serviceAccount:
  create: true
  name: ""                    # empty → derived from fullname template
  annotations: {}

podSecurityContext:
  runAsNonRoot: true
  runAsUser: 65532
  fsGroup: 65532
  seccompProfile:
    type: RuntimeDefault

securityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop: [ALL]
  readOnlyRootFilesystem: true

service:
  type: ClusterIP
  port: 8080

ingress:
  enabled: false
  className: ""
  annotations: {}
  hosts: []
  tls: []

resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 100m
    memory: 128Mi

autoscaling:
  enabled: false
  minReplicas: 1
  maxReplicas: 10
  targetCPUUtilizationPercentage: 80

nodeSelector: {}
tolerations: []
affinity: {}

podDisruptionBudget:
  enabled: false
  minAvailable: 1

networkPolicy:
  enabled: false

# Subchart values live under the subchart name (or alias):
postgresql:
  enabled: false
  auth:
    username: app

# Cross-cutting values shared with subcharts go under `global`:
global:
  imageRegistry: ""
  storageClass: ""
```

Hidden rules:

- **camelCase** keys. Helm and Sprig functions assume that style. Avoid `kebab-case` (works in YAML, but `.Values.image-tag` is a parse error in Go templates — you would need `index .Values "image-tag"`).
- **Booleans default to `false` for opt-in features** (`ingress.enabled`, `autoscaling.enabled`, `networkPolicy.enabled`). The chart is always installable with `helm install RELEASE chart` and zero overrides.
- **Empty strings, not `null`,** for "use sensible default elsewhere" semantics (e.g. `image.tag: ""` → use `.Chart.AppVersion`). `null` triggers `nil` template errors more often than empty-string defaults.
- **Subchart values block is keyed by the subchart `name:` (or `alias:`).** Parent values do not leak into subcharts unless declared under `global:` *or* explicitly pulled in via `import-values`.

---

## 5. `values.schema.json` — fail at lint time, not at apply time

Every production chart ships a JSON Schema describing the shape of `.Values`. Helm validates against it during `install`, `upgrade`, `lint`, and `template`.

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "additionalProperties": false,
  "required": ["image"],
  "properties": {
    "replicaCount": {
      "type": "integer",
      "minimum": 0,
      "maximum": 100
    },
    "image": {
      "type": "object",
      "required": ["repository"],
      "additionalProperties": false,
      "properties": {
        "repository": { "type": "string", "minLength": 1 },
        "tag":        { "type": "string" },
        "pullPolicy": { "enum": ["Always", "IfNotPresent", "Never"] }
      }
    },
    "service": {
      "type": "object",
      "properties": {
        "type": { "enum": ["ClusterIP", "NodePort", "LoadBalancer"] },
        "port": { "type": "integer", "minimum": 1, "maximum": 65535 }
      }
    }
  }
}
```

Use `additionalProperties: false` aggressively — typo'd keys (`replicasCount` vs `replicaCount`) silently default-on without a schema. Schema is the only real defence.

---

## 6. `templates/` — Go templates + Sprig

Three template engines stack on top of each other:

1. **Go's `text/template`** — actions `{{ ... }}`, pipelines `|`, control flow (`if`, `with`, `range`).
2. **Sprig** — 50+ functions: string ops, math, dicts, lists, type conversion, defaults, dates, semver, regex, dictionaries, encoding.
3. **Helm template extensions** — `include`, `tpl`, `lookup`, `required`, `toYaml`, `fromYaml`, `Files.Get`, `Files.Glob`, plus `AsConfig` / `AsSecrets` as methods on the result of `Files.Glob` (used as `(.Files.Glob "config/**").AsConfig`, **not** `Files.AsConfig` directly).

### 6.1 Built-in objects

| Object | Contents |
|--------|----------|
| `.Release` | `.Name`, `.Namespace`, `.Service` (always `Helm`), `.IsInstall`, `.IsUpgrade`, `.Revision` |
| `.Values` | The merged values (defaults + `-f` files + `--set`) |
| `.Chart` | `Chart.yaml` content as a struct — `.Name`, `.Version`, `.AppVersion`, `.Annotations`, … |
| `.Files` | Non-special files in the chart, as a map (use `.Files.Get`, `.Files.Glob`, `.Files.AsConfig`, `.Files.AsSecrets`) |
| `.Capabilities` | `.KubeVersion`, `.APIVersions.Has "networking.k8s.io/v1/Ingress"` |
| `.Template` | `.Name`, `.BasePath` — the *current* template being rendered |

### 6.2 Idiomatic patterns

**`required` for mandatory inputs:**

```yaml
image:
  repository: {{ required "image.repository must be set" .Values.image.repository }}
  tag: {{ default .Chart.AppVersion .Values.image.tag | quote }}
```

**`tpl` to template a values string:**

```yaml
data:
  config: {{ tpl .Values.template . | quote }}
```

**`toYaml | nindent` for nested objects** — `nindent N` *prepends* a newline and indents by N spaces; `indent N` only indents (no leading newline). Use `nindent` whenever the value lives on a brand-new line under a YAML key:

```yaml
spec:
  resources:
    {{- toYaml .Values.resources | nindent 4 }}
```

**Annotation-based config rollout** — when a `ConfigMap` or `Secret` changes, the `Deployment` pod template hash must change so the rollout actually fires:

```yaml
kind: Deployment
spec:
  template:
    metadata:
      annotations:
        checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
```

**Capability-gated APIs:**

```yaml
{{- if .Capabilities.APIVersions.Has "networking.k8s.io/v1/NetworkPolicy" }}
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
# ...
{{- end }}
```

**Defaulting from values, with chart fallback:**

```go-template
{{- define "mychart.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{ .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else -}}
{{ printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end -}}
{{- end -}}
```

The `trunc 63 | trimSuffix "-"` idiom keeps generated names within Kubernetes' 63-character DNS-1123 label limit.

### 6.3 Whitespace control

| Action | Effect |
|--------|--------|
| `{{- ...` | Trim **preceding** whitespace, including the newline |
| `... -}}` | Trim **trailing** whitespace, including the newline |
| `{{ ... }}` | Render in place; line is preserved |

Rule of thumb: use `{{-` on directive lines (`{{- if`, `{{- end`) so they do not produce blank lines in the rendered manifest. Use `{{ ... }}` (no trim) when the action *replaces* a value on a non-trivial line.

---

## 7. Named templates (partials)

`define` creates a named template. `template` and `include` invoke it. `include` lets you pipe its output (`include "x" . | indent 4`); `template` does not — that is the only practical difference, and it makes `include` the default choice.

```go-template
{{- /* templates/_helpers.tpl */ -}}

{{- define "mychart.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "mychart.labels" -}}
app.kubernetes.io/name: {{ include "mychart.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end -}}

{{- define "mychart.selectorLabels" -}}
app.kubernetes.io/name: {{ include "mychart.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
```

Naming rules:

- **Always prefix with the chart name.** Template names are global across a render — `mychart.labels` and `mychart.selectorLabels` are safe; `labels` and `selectorLabels` collide with subcharts.
- **Two label sets, not one.** `mychart.labels` for `metadata.labels` (full set, mutable). `mychart.selectorLabels` for `spec.selector.matchLabels` and `Service.spec.selector` (immutable subset). A `Deployment` selector cannot change after creation; including `helm.sh/chart` (which has the chart version) would make every chart upgrade fail with `field is immutable`.

---

## 8. Standard labels

Every Kubernetes resource emitted by the chart carries this set:

| Label | Source | Purpose |
|-------|--------|---------|
| `app.kubernetes.io/name` | `{{ include "mychart.name" . }}` | App name (often the chart name) |
| `app.kubernetes.io/instance` | `{{ .Release.Name }}` | Differentiate two installs of the same chart |
| `app.kubernetes.io/version` | `{{ .Chart.AppVersion \| quote }}` | App version — **mutable**, do **not** put in selectors |
| `app.kubernetes.io/managed-by` | `{{ .Release.Service }}` | Always `Helm` |
| `app.kubernetes.io/component` | values | Role within the app (`frontend`, `worker`) |
| `app.kubernetes.io/part-of` | values | Higher-level app this is a piece of |
| `helm.sh/chart` | `{{ .Chart.Name }}-{{ .Chart.Version }}` | Chart identity — **mutable** |

Selector subset (used in `Deployment.spec.selector.matchLabels`, `Service.spec.selector`, `StatefulSet.spec.selector.matchLabels`): **only** `app.kubernetes.io/name` + `app.kubernetes.io/instance` (+ optionally `app.kubernetes.io/component` if it never changes for a given workload).

---

## 9. Subcharts and globals

Subcharts live in `charts/`, are pulled by `helm dependency update`, and are rendered as part of the parent chart. Two cross-cutting mechanisms exist:

**`global:` block** — every key under `.Values.global` is automatically merged into every subchart's `.Values.global`:

```yaml
# parent values.yaml
global:
  imageRegistry: ghcr.io/example
  storageClass: ssd
```

```yaml
# subchart template — sees parent's global
image: {{ .Values.global.imageRegistry }}/postgres:15
```

**`import-values`** — explicit lift of subchart values into the parent namespace:

```yaml
dependencies:
  - name: postgresql
    version: 13.2.24
    repository: oci://registry-1.docker.io/bitnamicharts
    import-values:
      - child: auth
        parent: pgauth
```

After this, `.Values.pgauth.username` in the parent equals `.Values.postgresql.auth.username`.

Hidden rule: **subchart templates cannot reach into parent `.Values`** except via `global` and `import-values`. Do not work around this with `tpl` hacks; use globals.

---

## 10. Library charts

`type: library` charts ship reusable named templates and **cannot be installed**. Consumers add the library as a dependency and use `include`.

```yaml
# Chart.yaml of the library
apiVersion: v2
name: common
type: library            # ← key
version: 1.0.0
```

```go-template
{{- /* common/templates/_deployment.tpl */ -}}
{{- define "common.deployment.tpl" -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "common.fullname" . }}
spec:
  selector:
    matchLabels:
      {{- include "common.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "common.labels" . | nindent 8 }}
    spec:
      containers:
        - name: app
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
{{- end -}}
```

```yaml
# consumer Chart.yaml
dependencies:
  - name: common
    version: 1.0.0
    repository: file://../common
```

```go-template
{{- /* consumer templates/deployment.yaml */ -}}
{{- include "common.deployment.tpl" . }}
```

Use library charts only when **three or more** charts share substantial template surface. For two charts, copy-paste is cheaper than the indirection.

---

## 11. Hooks

Hooks are ordinary Kubernetes resources annotated with `helm.sh/hook`. Helm renders, applies, and tracks them outside the normal release manifest.

| Event | Fires |
|-------|-------|
| `pre-install` | After templates render, before any resource creation |
| `post-install` | After all release resources are loaded into the cluster |
| `pre-delete` | Before resource deletion (`helm uninstall`) |
| `post-delete` | After all release resources are deleted |
| `pre-upgrade` | After templates render, before update |
| `post-upgrade` | After all upgraded resources are applied |
| `pre-rollback` | After templates render, before rollback |
| `post-rollback` | After rollback resources are applied |
| `test` | Only when `helm test` runs (see §12) |

Two more annotations control hook behaviour:

| Annotation | Meaning |
|-----------|---------|
| `helm.sh/hook-weight` | String integer; ascending order; ties break alphabetically by resource name |
| `helm.sh/hook-delete-policy` | Comma-separated: `before-hook-creation` (default), `hook-succeeded`, `hook-failed` |

Canonical migration job:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: "{{ include "mychart.fullname" . }}-migrate"
  labels:
    {{- include "mychart.labels" . | nindent 4 }}
  annotations:
    "helm.sh/hook": pre-install,pre-upgrade
    "helm.sh/hook-weight": "-5"
    "helm.sh/hook-delete-policy": before-hook-creation,hook-succeeded
spec:
  backoffLimit: 0
  template:
    metadata:
      labels:
        {{- include "mychart.labels" . | nindent 8 }}
    spec:
      restartPolicy: Never
      serviceAccountName: {{ include "mychart.serviceAccountName" . }}
      containers:
        - name: migrate
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
          command: ["/bin/migrate", "up"]
```

Hidden rules:

- **Always set `hook-delete-policy`.** Without it, every install/upgrade leaves a `Job` permanently in the namespace — the namespace fills up over weeks.
- **Always set `backoffLimit: 0`** for migration jobs unless idempotency is proven. Rerunning a half-applied schema migration is worse than failing loud.
- **Never label hook resources with `helm.sh/chart`** if they are part of an `Always` re-create flow; the chart version mismatch can confuse cluster auditors. Use only `app.kubernetes.io/name` + a `hook` component label.

---

## 12. Tests

Test resources live in `templates/tests/` and are annotated `helm.sh/hook: test`. They run via `helm test RELEASE`. A successful test is a Pod that exits `0`; any non-zero exit code fails the test run.

```yaml
# templates/tests/test-connection.yaml
apiVersion: v1
kind: Pod
metadata:
  name: "{{ include "mychart.fullname" . }}-test-connection"
  labels:
    {{- include "mychart.labels" . | nindent 4 }}
  annotations:
    "helm.sh/hook": test
    "helm.sh/hook-delete-policy": before-hook-creation,hook-succeeded
spec:
  restartPolicy: Never
  containers:
    - name: wget
      image: busybox:1.36
      command: ["wget"]
      args: ["{{ include "mychart.fullname" . }}:{{ .Values.service.port }}/healthz"]
```

Run with:

```bash
helm test myrelease --logs   # --logs streams the test pod's stdout/stderr
```

---

## 13. CRDs

Two placement strategies — pick by upgrade lifecycle, not by convenience.

| Placement | Behaviour |
|-----------|-----------|
| `crds/` | Helm applies on `install`, **never** updates or deletes. Safest default for charts that ship CRDs. |
| `templates/` | Renders + applies normally; `helm upgrade` can mutate the CRD; `helm uninstall` deletes it (and every CR — destroying user data). |

Use `crds/` for production charts. If the CRD must evolve, document the manual `kubectl apply -f https://.../mycrd.yaml` step in `NOTES.txt` and bump the chart `version` major when the CRD shape changes. Operators (kube-builder / OperatorSDK) typically ship CRDs out-of-band; in that case omit `crds/` entirely.

For resources that **must survive `helm uninstall`** (PersistentVolumeClaims, long-lived Secrets, Namespaces created by the chart), annotate them with the resource-policy escape hatch:

```yaml
metadata:
  annotations:
    "helm.sh/resource-policy": keep
```

Helm will skip them on `helm uninstall`. The trade-off: the resource leaves the release's ownership graph, so a later `helm install` of the same release name will collide unless the user cleans up manually. Use sparingly, only for state.

---

## 14. RBAC

Every chart that needs cluster API access ships its own `ServiceAccount` + RBAC bindings, *opt-out* via `serviceAccount.create=false`.

```yaml
# templates/serviceaccount.yaml
{{- if .Values.serviceAccount.create -}}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ include "mychart.serviceAccountName" . }}
  labels:
    {{- include "mychart.labels" . | nindent 4 }}
  {{- with .Values.serviceAccount.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end }}
```

Hidden rules:

- **Default to namespace-scoped `Role` + `RoleBinding`.** Reach for `ClusterRole` only when the chart genuinely needs cross-namespace reads. `cluster-admin` is never the answer.
- **Aggregated `ClusterRole`s** (`rbac.authorization.k8s.io/aggregate-to-admin: "true"`) are the right pattern for charts that extend Kubernetes API surface.
- **Bind to the chart's own SA**, never to `default`. Bindings to `default` SA leak privileges to every workload in the namespace.

---

## 15. Pod template hygiene

```yaml
spec:
  template:
    metadata:
      labels:
        {{- include "mychart.selectorLabels" . | nindent 8 }}
      annotations:
        checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
    spec:
      serviceAccountName: {{ include "mychart.serviceAccountName" . }}
      automountServiceAccountToken: {{ if hasKey .Values.serviceAccount "automountToken" }}{{ .Values.serviceAccount.automountToken }}{{ else }}false{{ end }}
      securityContext:
        {{- toYaml .Values.podSecurityContext | nindent 8 }}
      containers:
        - name: {{ .Chart.Name }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          securityContext:
            {{- toYaml .Values.securityContext | nindent 12 }}
          ports:
            - name: http
              containerPort: {{ .Values.service.port }}
              protocol: TCP
          livenessProbe:
            httpGet: { path: /healthz, port: http }
          readinessProbe:
            httpGet: { path: /readyz, port: http }
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
      {{- with .Values.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
```

Non-negotiable defaults: `runAsNonRoot: true`, `readOnlyRootFilesystem: true`, `allowPrivilegeEscalation: false`, `capabilities.drop: [ALL]`, `seccompProfile.type: RuntimeDefault`, `automountServiceAccountToken: false` unless the workload calls the API server.

---

## 16. Packaging

`helm package` produces a deterministic `.tgz` from the chart directory.

```bash
helm package ./mychart                                  # → mychart-1.4.2.tgz
helm package ./mychart --version 1.4.3-rc.1             # override Chart.yaml version
helm package ./mychart --app-version 1.27.4             # override Chart.yaml appVersion
helm package ./mychart --dependency-update              # run `helm dep update` first
helm package ./mychart --destination ./dist             # output dir
```

Reproducibility: package builds are **not** byte-stable across Helm versions or filesystems (file mtimes leak in). For supply-chain hashing, hash the *contents* of the rendered chart (`helm template | sha256sum`), not the `.tgz`.

---

## 17. Provenance — signing + verification

Helm uses PGP-based provenance. Signed releases produce two files:

```bash
helm package --sign \
  --key 'platform-team@example.com' \
  --keyring ~/.gnupg/secring.gpg \
  ./mychart
# → mychart-1.4.2.tgz
# → mychart-1.4.2.tgz.prov
```

GnuPG ≥ 2.1 (default on every modern distro) **does not** maintain `secring.gpg` — keys live in `~/.gnupg/private-keys-v1.d/`. Export a legacy keyring file once before signing:

```bash
gpg --export-secret-keys > ~/.gnupg/secring.gpg
chmod 600 ~/.gnupg/secring.gpg
```

The `.prov` file contains:

- `Chart.yaml` content
- SHA-256 over the `.tgz`
- An OpenPGP clearsigned signature

Both files must be served from the same path of any HTTPS-based chart repository. Verification:

```bash
helm verify mychart-1.4.2.tgz                         # standalone
helm install --verify --keyring pubring.gpg my mychart-1.4.2.tgz
helm pull --verify oci://ghcr.io/example/mychart --version 1.4.2
```

A failed `--verify` aborts the install **before** templates render. Add `--verify` to every CI install in production paths.

For OCI distribution, also pin by **digest** as the immutable reference (mutable tags can be republished):

```bash
helm install api oci://ghcr.io/example/mychart@sha256:52ccaa…
```

`helm pull` an OCI chart by digest, capture its SHA-256, then store the digest reference in your GitOps repo — that is the supply-chain-grade install pattern.

For keyless signing (the modern default alongside `.prov`), `cosign sign` the published OCI chart artifact and verify with `cosign verify --certificate-identity-regexp ...`. PGP `.prov` is still required for non-OCI HTTPS chart repos; for OCI distribution, `cosign` + transparency-log-backed verification is increasingly the de-facto standard. Run both.

Pin **container images** the chart deploys by digest too — not just the chart itself. Schema-allow `image.digest` alongside `image.tag`:

```yaml
image:
  repository: ghcr.io/example/api
  digest: sha256:1f3c...      # preferred; if set, ignore tag
  tag: ""                     # fallback only
```

```yaml
# template:
image: "{{ .Values.image.repository }}{{ if .Values.image.digest }}@{{ .Values.image.digest }}{{ else }}:{{ .Values.image.tag | default .Chart.AppVersion }}{{ end }}"
```

---

## 18. OCI registry distribution

OCI replaces `index.yaml`-based repositories. Every major registry supports it: GHCR, ECR, ACR, Artifact Registry, Harbor, Artifactory, Docker Hub.

```bash
# Auth (uses the registry's normal credential helper):
helm registry login -u USER ghcr.io
helm registry logout ghcr.io

# Publish:
helm push mychart-1.4.2.tgz oci://ghcr.io/example/charts

# Consume:
helm pull oci://ghcr.io/example/charts/mychart --version 1.4.2
helm install api oci://ghcr.io/example/charts/mychart --version 1.4.2
helm install api oci://ghcr.io/example/charts/mychart@sha256:52ccaa…   # immutable

# Subchart dependency from OCI:
# Chart.yaml
# dependencies:
#   - name: postgresql
#     version: 13.2.24
#     repository: oci://registry-1.docker.io/bitnamicharts
```

Hidden rules:

- **GHCR** chart names are case-sensitive; `oci://ghcr.io/Example/charts` ≠ `oci://ghcr.io/example/charts`. Lowercase only.
- **Tags are mutable** — anyone with push rights can republish `1.4.2`. Pin by `@sha256:` digest in production.
- **`helm pull --untar`** unpacks a chart for inspection; `helm show all oci://...` is non-destructive (no local extraction).

---

## 19. Lifecycle commands

```bash
# Install — release name is the first positional arg:
helm install api ./mychart                              # local
helm install --generate-name ./mychart                  # let Helm pick a name
helm install api oci://ghcr.io/example/charts/mychart --version 1.4.2
helm install api ./mychart -f override.yaml --set image.tag=1.27.4
helm install api ./mychart --create-namespace -n team-a
helm install api ./mychart --wait --timeout 5m          # block until Ready
helm install api ./mychart --atomic                     # rollback on failure

# Upgrade:
helm upgrade api ./mychart -f override.yaml
helm upgrade --install api ./mychart                    # idempotent install-or-upgrade
helm upgrade api ./mychart --reuse-values --set image.tag=1.27.5
helm upgrade api ./mychart --reset-then-reuse-values    # drop --set/-f from prev rel
helm upgrade api ./mychart --atomic --cleanup-on-fail   # safest upgrade
helm upgrade api ./mychart --version 1.4.3 --history-max 10

# Rollback:
helm rollback api                                       # to previous revision
helm rollback api 7                                     # to revision 7
helm rollback api 7 --cleanup-on-fail --wait

# Uninstall:
helm uninstall api                                      # deletes resources + history
helm uninstall api --keep-history                       # keeps revisions for forensics

# Inspect:
helm list -A                                            # all namespaces
helm list -n team-a --deployed
helm status api -n team-a
helm get manifest api -n team-a                         # rendered YAML
helm get values api -n team-a                           # USER-supplied values only
helm get values api -n team-a -a                        # merged (defaults + overrides)
helm get hooks api -n team-a
helm get notes api -n team-a
helm history api -n team-a
```

`--atomic` and `--cleanup-on-fail` together produce the safest upgrade in production: any failure rolls back automatically, and any half-created resources are cleaned up.

---

## 20. Linting and debugging

```bash
helm lint ./mychart                                     # Chart.yaml + values.schema.json + render dry-run
helm lint ./mychart --strict                            # warnings → errors

helm template api ./mychart                             # render to stdout
helm template api ./mychart --debug                     # show partial output even on render error
helm template api ./mychart -f override.yaml --show-only templates/deployment.yaml

helm install api ./mychart --dry-run=client --debug     # render only (skips API/admission/CRD checks)
helm install api ./mychart --dry-run=server --debug     # server-side validation (admission + CRDs)

helm get manifest api -n team-a > /tmp/api.yaml         # what's actually deployed
helm get values   api -n team-a -a > /tmp/api-vals.yaml # MERGED values (omit -a → user overrides only)
helm diff upgrade api ./mychart -f override.yaml        # requires `helm-diff` plugin
```

Ladder for "my chart does not render the way I expect":

1. `helm lint --strict` — schema + obvious bugs.
2. `helm template . --debug -f my.yaml` — see the rendered YAML, including failed templates.
3. `helm install --dry-run=server --debug` — server-side validation (admission webhooks, CRDs). Prefer this over the default `--dry-run=client`, which skips lookup, CRDs, and admission policies.
4. `helm get manifest` on the actual release — diff against your local render to find drift.
5. `helm history` — find the offending revision; `helm rollback` if the issue is recent.

---

## 21. `.helmignore`

Exclude files from both the packaged `.tgz` and the templates' `.Files` map.

```text
# Patterns identical to .gitignore
.git/
.gitignore
*.swp
*.swo
.DS_Store
.idea/
.vscode/
.tox/
.editorconfig
.pre-commit-config.yaml
OWNERS
.tmproj
docs/
tests/
ci/
*.bak
node_modules/
```

Rule: **anything that is not part of the runtime contract of the chart belongs in `.helmignore`**. Documentation, CI configs, owner files, IDE turds, and the like bloat the package and the cluster's release Secret (releases are stored as gzipped Secrets, capped at ~1 MiB).

---

## 22. Anti-patterns

| Anti-pattern | Why it bites | Fix |
|--------------|--------------|-----|
| `apiVersion: v1` in Chart.yaml | Helm 2 legacy; no `dependencies:` block | `apiVersion: v2` + dependencies inline |
| `version: 1.0.0` on every release | Breaks consumer pinning | Bump SemVer on every change |
| `appVersion: 1.27` (unquoted) | Parses as float `1.27` → drops trailing zeros | Always quote: `appVersion: "1.27.0"` |
| Chart name ≠ directory name | `helm dep update` fails | Match exactly |
| `randAlphaNum` in a manifest field value | New value every render → permanent diff | Compute in `metadata.annotations` cache-busters only |
| Mutable labels (`app.kubernetes.io/version`, `helm.sh/chart`) in `selector.matchLabels` | First install succeeds; the next upgrade that bumps the chart or app version fails with `field is immutable` | Selector uses immutable subset (`name` + `instance`) |
| `| default false` on a boolean value coming from values | Sprig treats `false` as "empty" and re-applies the default — flips user's `false` back to default | Use `{{ if hasKey ... }}{{ ... }}{{ else }}false{{ end }}` for booleans |
| CRDs in `templates/` | Upgrades mutate CRDs; uninstall deletes user CRs | Use `crds/` (one-shot install) and bump chart-major on CRD schema changes |
| Plaintext secrets in `values.yaml` | Committed to VCS | SealedSecrets / SOPS / external-secrets / Helm Secrets |
| `helm install --no-hooks` to "skip the migration" | Hides real failures | Fix the migration job; never bypass hooks in production |
| Hooks without `hook-delete-policy` | Job/Pod accumulates | Always `before-hook-creation,hook-succeeded` |
| `helm dep up` with `version: ">=1.0.0"` | Non-reproducible installs | Pin exact `version:` and commit `Chart.lock` |
| OCI install by tag (`mychart:1.4.2`) in prod | Tags are mutable | Pin by `@sha256:` digest |
| Skipping `--verify` on signed charts | Defeats the signature | `helm install --verify` in CI |
| Multi-app mega-chart | Coupled lifecycles, shared values, painful rollbacks | One chart per app; compose via subcharts or umbrella charts |
| Using `template` instead of `include` for partials | Cannot pipe (`indent` / `nindent` / `toYaml`) | Default to `include` |
| Selector + label drift after a chart name rename | `field is immutable` errors on every upgrade | Treat `app.kubernetes.io/name` as a stable contract — never rename. Fork to a new chart instead. |
| `helm uninstall` to "fix" a stuck release | Deletes user data + secrets | `helm rollback` first; `--cleanup-on-fail` on the failed upgrade |

---

## 23. Pre-commit verification checklist

Before committing any chart change:

- [ ] `apiVersion: v2`, `name:` matches directory, `version:` bumped (SemVer).
- [ ] `appVersion:` quoted; updated if image tag default changed.
- [ ] `kubeVersion:` declared and matches what your CI tests against.
- [ ] `values.yaml` exists, every templated key has a default, defaults are safe + minimal.
- [ ] `values.schema.json` exists; `additionalProperties: false`; required keys listed.
- [ ] `templates/_helpers.tpl` defines chart-prefixed `name`, `fullname`, `labels`, `selectorLabels`, `serviceAccountName`.
- [ ] Every resource carries `app.kubernetes.io/*` + `helm.sh/chart` labels.
- [ ] Selectors use only the **immutable** label subset (`name` + `instance`).
- [ ] No `randAlphaNum` / `now` / `uuidv4` / `randAscii` in any rendered manifest *value* (annotations cache-busters are fine).
- [ ] Subchart values keyed by the subchart's `name:` or `alias:` — no parent values reaching into subchart `.Values` directly.
- [ ] All partials are invoked with `include`, never `template` (so `indent` / `nindent` / `toYaml` pipes work).
- [ ] RBAC: namespace-scoped `Role` + `RoleBinding`; no wildcard `verbs: ["*"]` or `resources: ["*"]`; no binding to the `default` ServiceAccount; bound only to the chart's own SA.
- [ ] `helm.sh/resource-policy: keep` set on any resource that holds user state (PVC, long-lived Secret).
- [ ] CRDs in `crds/` (or documented `kubectl apply` workflow).
- [ ] Hooks declare `hook-weight` and `hook-delete-policy`.
- [ ] Test pods under `templates/tests/` with `helm.sh/hook: test`.
- [ ] No plaintext secrets in `values.yaml`.
- [ ] `Chart.lock` committed alongside `Chart.yaml` after `helm dep update`.
- [ ] `.helmignore` excludes IDE + CI + docs.
- [ ] `helm lint --strict ./` exits 0.
- [ ] `helm template ./ --debug -f ci/test-values.yaml` exits 0 and renders all expected resources.
- [ ] `helm install --dry-run=server --debug RELEASE ./` exits 0 against a representative cluster.
- [ ] `helm test RELEASE` passes after install on the same cluster.
- [ ] If chart is published: `helm package --sign` produces `.tgz` + `.prov`; downstream `helm install --verify` passes.
- [ ] If pushed to OCI: digest captured (`@sha256:…`) and stored in the GitOps source of truth.
- [ ] Container images pinned by `image.digest` (not just `image.tag`) for production deploys; cosign-verified if Sigstore is in use.
- [ ] Static scan run (`trivy config`, `checkov`, `kubesec`) on rendered manifests before publish.
- [ ] Anti-patterns table re-read end to end.

If any box is unchecked and the change is going to a shared cluster, **stop and finish that box first**.
