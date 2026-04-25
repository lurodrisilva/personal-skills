---
name: wiremock-api-mocks
description: MUST USE when authoring, reviewing, or modifying anything that runs **WireMock as a shared, cluster-wide API mock server** in a Kubernetes platform. Covers — packaging WireMock as a baseline addon (`addon_charts/wiremock/`) deployed via the App-of-Apps pattern from `addons-and-building-blocks`; running a single multi-tenant WireMock instance in the dedicated `testing-system` namespace (never a per-pod sidecar); declaring stub mappings in **consumer applications' Helm values** and registering them at install/upgrade time via the WireMock Admin API (`POST /__admin/mappings`, `POST /__admin/mappings/remove`); per-release ownership via `metadata.owner=<release>` for atomic delete-and-replace; URL-prefix isolation `/__mocks__/<release>/...` to prevent stub collisions on a shared instance; library helper `myorg.wiremock.syncJob` rendered into a Helm `pre-install,post-install,post-upgrade,pre-delete`-hooked Job; consuming the shared instance from .NET, Go, Node, JVM apps via DNS `wiremock.testing-system.svc.cluster.local:8080`; the **separate** `WireMock.Net` library used in-process for unit tests (xUnit/NUnit fixtures, `WireMockServer.Start()`, `Given(Request.Create()…)`); response templating, request matching, stateful scenarios, fault injection, and recording/playback (disabled on the shared instance for safety); the four-tier validation gate (`yamllint` → `helm lint` → `helm-unittest` → `kubeconform`) inherited from the parent skill; production-cluster gating (defaulted off outside test/preview environments via `enabled=false`); NetworkPolicy restriction to namespaces labelled `wiremock.io/consumer=true`. Triggers on phrases — "add wiremock", "set up shared mock server", "mock external apis", "register stub mappings", "wiremock helm chart", "shared wiremock instance", "testing-system namespace", "mock APIs in cluster", "wiremock.net unit tests", "stub mappings via values", "WireMockServer.Start", "POST /__admin/mappings". Triggers on file patterns — `addon_charts/wiremock/**`, `base_chart/templates/{NN}-wiremock.yaml`, `mappings/*.json`, `__files/`, `tests/chart/**` containing `wiremock`, `Stub.cs`, `WireMockFixture.cs`, `appsettings.*.json` with `Wiremock`/`WireMock` keys. Authored by a distinguished Platform Engineer — emphasizes **one shared instance, many tenants, declarative stubs, reproducible from values**, never sidecars, never recordings on shared infrastructure. Inherits and never violates the non-negotiables of `addons-and-building-blocks`.
license: BSD-3-Clause
compatibility: opencode
metadata:
  domain: platform-engineering
  pattern: shared-mock-server-addon
  platform: kubernetes
  stack: wiremock + helm + argocd
  language: dotnet + jvm + polyglot
  depends_on: addons-and-building-blocks
---

# WireMock API Mocks — Shared Cluster Mock Server Playbook

You are a Platform Engineer adding **shared, cluster-wide HTTP API mocking** to a Kubernetes-based Internal Developer Platform. WireMock is delivered as a **baseline addon** — one Deployment, one Service, one Admin API — that every test/preview-tier application points at instead of real third-party HTTP dependencies. Stubs are owned by the consuming applications, declared in their Helm values, and registered atomically at install/upgrade time. There is **never** a per-app WireMock pod, never a sidecar, never a long-lived stub baked into the addon image.

This skill **inherits** the layer cake, helper namespacing, OCI consumption, four-tier validation, and GitOps conventions of `addons-and-building-blocks`. If anything below contradicts that skill, the parent wins — fix this skill, do not weaken the parent.

**Non-negotiables encoded in this skill:**

1. **One instance, one namespace.** WireMock runs as a single Deployment in `testing-system`. Never a per-app sidecar; never multiple WireMock Deployments fighting over the same Admin API.
2. **Java WireMock for the cluster, `WireMock.Net` only in-process.** The shared cluster instance uses the canonical `wiremock/wiremock` OCI image. `WireMock.Net` is a separate library for in-process .NET unit tests — do **not** containerize it as the cluster instance just because the calling apps are .NET.
3. **Stubs are declared in consumer apps' Helm values, never baked into the addon image.** A sync Job per consumer release POSTs them to the Admin API at install/upgrade.
4. **Every stub mapping is tagged `metadata.owner=<release-fullname>`.** This is what makes atomic per-release replace possible on a shared instance via `POST /__admin/mappings/remove` with a metadata matcher.
5. **Every stub URL is namespaced `/__mocks__/<release-fullname>/...`.** No app may register a stub on a path that does not start with its release-scoped prefix. Collisions are a configuration bug, not a runtime concern.
6. **Persistence is OFF.** The addon does not mount a PVC for stubs. All mappings are reproducible from consumer values; on a fresh deploy, every consumer's sync Job re-registers its own stubs.
7. **Recording/playback is DISABLED on the shared instance.** `recordingMode: never` in values; the Admin API endpoint `/__admin/recordings/start` returns 403 via NetworkPolicy + auth. Recording on a multi-tenant instance is a data-leak vector.
8. **Production gating is hard-coded.** The base chart's wiremock value defaults to `enabled: false`. It is opt-in per environment in `values-<env>.yaml`, and `values-prod.yaml` MUST never enable it. CI enforces this with a kubeconform-equivalent grep gate.
9. **NetworkPolicy is mandatory.** Only namespaces carrying the label `wiremock.io/consumer=true` may reach `wiremock.testing-system.svc.cluster.local`. Default-deny in `testing-system`; explicit allow per consumer namespace.
10. **The library helper is `myorg.wiremock.syncJob`.** It lives in `plat-eng-commons-package` (or its sibling) — never redefined inside a consuming chart, never copy-pasted between repos.
11. **Helm hook ordering is fixed.** Sync Job hooks: `pre-install,post-install,post-upgrade` for register; `pre-delete` for cleanup. Never `post-delete` (the Service may already be torn down).
12. **`make all` parity, Helm v3.20.0 pinned, four-tier gate runs locally and in CI.** Same rule as the parent skill — there is no "WireMock CI is special".

If a chart or PR under review violates any of these, flag them first.

---

## WHEN TO USE THIS SKILL

| Scenario | Use this skill? |
|----------|-----------------|
| Adding a new `addon_charts/wiremock/` chart to a baseline GitOps repo | **Yes** |
| Wiring a consumer app's chart to register stubs in the shared WireMock | **Yes** |
| Reviewing a PR that adds `mocks.wiremock.stubs:` entries to an app's `values.yaml` | **Yes** |
| Reviewing a PR that defines or modifies the `myorg.wiremock.*` library helpers | **Yes** |
| Debugging why an app's stubs disappeared after another app's upgrade | **Yes** — the metadata-owner contract is at fault somewhere |
| Choosing between sidecar WireMock vs shared WireMock for the platform | **Yes** — and the answer is always shared |
| Setting up `WireMock.Net` in-process for an xUnit test class | **Yes** — covered, but understand the boundary |
| Authoring a fresh WireMock deployment on a non-Kubernetes host | **No** — outside scope |
| Authoring a non-WireMock mock server (`mockserver`, `prism`, `httpmock`) | **No** — different tool, different invariants |
| One-off `docker run wiremock/wiremock` for a developer's laptop | **No** — wrong layer; this skill is platform-scope |

---

## ARCHITECTURE — WHERE WIREMOCK FITS IN THE LAYER CAKE

```
┌──────────────────────────────────────────────────────────────────┐
│ L5  PRODUCT CHARTS (consumers)                                   │
│     mocks.wiremock.enabled: true                                 │
│     mocks.wiremock.stubs: [ ... ]                                │
│     -> emits: per-release sync Job + pre-delete cleanup Job      │
└──────────────────────────────────────────┬───────────────────────┘
                                           │   POST /__admin/mappings
                                           │   (with metadata.owner=<release>)
                                           ▼
┌──────────────────────────────────────────────────────────────────┐
│ L2  BASELINE ADDON: addon_charts/wiremock/                       │
│     - Deployment (1 replica, no PVC)                             │
│     - Service ClusterIP :8080  (HTTP) :8443 (mTLS, optional)     │
│     - NetworkPolicy: allow-from `wiremock.io/consumer=true`      │
│     - ServiceMonitor on /__admin/metrics                         │
│     Namespace: testing-system                                    │
└──────────────────────────────────────────┬───────────────────────┘
                                           │
                                           ▼
┌──────────────────────────────────────────────────────────────────┐
│ L1  COMMONS LIBRARY  plat-eng-commons-package                    │
│     myorg.wiremock.syncJob       — registers/deletes stubs       │
│     myorg.wiremock.stubsConfigMap — renders stubs as JSON         │
│     myorg.wiremock.consumerLabel  — adds consumer label to ns    │
└──────────────────────────────────────────────────────────────────┘
```

**One-way dependency flow** (same rule as the parent skill): consumers depend on the library; the library knows nothing about any individual consumer; the WireMock addon knows nothing about any consumer's stubs.

---

## CHART STRUCTURE — `addon_charts/wiremock/`

```
addon_charts/wiremock/
├── Chart.yaml
├── values.yaml
├── .helmignore
├── templates/
│   ├── _helpers.tpl                   # only chart-local helpers; reuse myorg.* via dep
│   ├── 00-namespace.yaml              # testing-system, with wiremock.io/owner label
│   ├── 10-deployment.yaml
│   ├── 20-service.yaml
│   ├── 30-networkpolicy.yaml          # default-deny + allow consumer label
│   ├── 40-servicemonitor.yaml         # /__admin/metrics scrape
│   ├── 50-poddisruptionbudget.yaml
│   └── 60-prometheusrule.yaml         # admin-api-down alert
└── tests/
    └── chart/                         # wrapper-chart helm-unittest pattern
        ├── Chart.yaml
        ├── values.yaml
        └── tests/
            └── deployment_test.yaml
```

### `Chart.yaml`

```yaml
apiVersion: v2
name: wiremock
description: Shared WireMock mock server for the testing-system namespace.
type: application
version: 0.1.0
appVersion: "3.9.1"
dependencies:
  - name: plat-eng-commons-package
    version: ">=2.0.0,<3.0.0"
    repository: oci://ghcr.io/<org>/helm-charts
```

### `values.yaml` (annotated)

```yaml
# Default OFF. Enable per-environment in values-<env>.yaml.
# values-prod.yaml MUST keep this false.
enabled: false

image:
  repository: wiremock/wiremock
  # Pin by digest in production overlays:
  # tag: "3.9.1@sha256:..."
  tag: "3.9.1"
  pullPolicy: IfNotPresent

namespace:
  name: testing-system
  create: true
  labels:
    wiremock.io/owner: "platform"

replicaCount: 1   # Multi-tenant — never scale beyond 1 without sticky-session affinity;
                  # WireMock state (in-memory mappings) is not shared across replicas.

service:
  type: ClusterIP
  ports:
    http: 8080
    admin: 8080  # WireMock serves stubs and admin on the same port

resources:
  requests: { cpu: 100m, memory: 256Mi }
  limits:   { cpu: 1,    memory: 1Gi }

# Hardcoded safety: never enable on a shared instance.
recordingMode: never

# Empty default; consumers register their own stubs.
extraArgs:
  - "--no-request-journal"          # bounded memory under high traffic
  - "--max-request-journal-entries=1000"
  - "--disable-banner"

networkPolicy:
  enabled: true
  consumerLabel: "wiremock.io/consumer=true"

serviceMonitor:
  enabled: true
  interval: 30s

podDisruptionBudget:
  minAvailable: 0   # single-replica + multi-tenant; voluntary disruption is acceptable
```

### `templates/10-deployment.yaml`

```yaml
{{- if .Values.enabled }}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "myorg.fullname" . }}
  namespace: {{ .Values.namespace.name }}
  labels:
    {{- include "myorg.labels" . | nindent 4 }}
spec:
  replicas: {{ .Values.replicaCount }}
  strategy:
    type: Recreate    # Single replica + in-memory state — RollingUpdate would
                      # briefly run two replicas with diverging stub maps.
  selector:
    matchLabels:
      {{- include "myorg.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "myorg.selectorLabels" . | nindent 8 }}
    spec:
      automountServiceAccountToken: false
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 1000
        fsGroup: 1000
      containers:
        - name: wiremock
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          args:
            - "--port=8080"
            - "--root-dir=/home/wiremock"
            {{- with .Values.extraArgs }}
            {{- toYaml . | nindent 12 }}
            {{- end }}
          ports:
            - name: http
              containerPort: 8080
          readinessProbe:
            httpGet:
              path: /__admin/health
              port: http
            initialDelaySeconds: 5
            periodSeconds: 10
          livenessProbe:
            httpGet:
              path: /__admin/health
              port: http
            initialDelaySeconds: 30
            periodSeconds: 30
          resources: {{- toYaml .Values.resources | nindent 12 }}
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop: ["ALL"]
          volumeMounts:
            - name: tmp
              mountPath: /tmp
            - name: home
              mountPath: /home/wiremock
      volumes:
        - name: tmp
          emptyDir: {}
        - name: home
          emptyDir: {}
{{- end }}
```

### `templates/30-networkpolicy.yaml`

```yaml
{{- if and .Values.enabled .Values.networkPolicy.enabled }}
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: {{ include "myorg.fullname" . }}-allow-consumers
  namespace: {{ .Values.namespace.name }}
spec:
  podSelector:
    matchLabels:
      {{- include "myorg.selectorLabels" . | nindent 6 }}
  policyTypes: [Ingress]
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              wiremock.io/consumer: "true"
      ports:
        - port: 8080
          protocol: TCP
{{- end }}
```

> **Why a NetworkPolicy and not just RBAC on the Admin API?** WireMock has no built-in auth on `/__admin/*`. Anyone who can reach the Service can wipe every stub via `POST /__admin/mappings/remove`. NetworkPolicy is the only realistic enforcement boundary on a shared cluster instance.

---

## BASE-CHART INTEGRATION — `base_chart/templates/{NN}-wiremock.yaml`

WireMock is wave **5** by default (after cert-manager wave 1, ingress-controller wave 2, monitoring wave 3, namespaces wave 4). Pick the next free wave in your repo if 5 is taken — and rename the file to match.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: wiremock
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "5"
spec:
  project: default
  source:
    repoURL: {{ .Values.repo_url | quote }}
    targetRevision: {{ .Values.target_revision | quote }}
    path: {{ printf "addon_charts/%s" .Values.wiremock.addon_name }}
    helm:
      valueFiles:
        - values.yaml
        - values-{{ .Values.environment }}.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: {{ .Values.wiremock.namespace }}
  syncPolicy:
    syncOptions:
      - ServerSideApply=true
      - CreateNamespace=true
    automated:
      prune: true
      selfHeal: true
```

`base_chart/values.yaml`:

```yaml
wiremock:
  addon_name: wiremock        # kebab-case, matches addon_charts/<dir>
  namespace: testing-system
```

> **Filename = sync wave.** `05-wiremock.yaml` → `sync-wave: "5"`. A mismatch is the single most common addon bug.

---

## LIBRARY HELPERS — `plat-eng-commons-package`

Three helpers are added to the commons library. They live alongside `myorg.fullname`/`myorg.labels` and follow the same `{{- define -}}` whitespace contract.

### `myorg.wiremock.adminUrl`

```yaml
{{- define "myorg.wiremock.adminUrl" -}}
{{- $url := default "http://wiremock.testing-system.svc.cluster.local:8080" .Values.mocks.wiremock.adminUrl -}}
{{- $url | trimSuffix "/" -}}
{{- end }}
```

### `myorg.wiremock.stubsConfigMap`

Renders the consumer's stubs as a single JSON document, prefixing every `urlPath`/`urlPattern`/`url` with `/__mocks__/<fullname>/` and tagging every mapping with `metadata.owner=<fullname>`. Consumers must NOT override the prefix or the owner — they are added by the helper.

```yaml
{{- define "myorg.wiremock.stubsConfigMap" -}}
{{- $owner := include "myorg.fullname" . -}}
{{- $prefix := printf "/__mocks__/%s" $owner -}}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ $owner }}-wiremock-stubs
  labels:
    {{- include "myorg.labels" . | nindent 4 }}
  annotations:
    helm.sh/hook: pre-install,pre-upgrade
    helm.sh/hook-weight: "-5"
data:
  stubs.json: |-
    {
      "mappings": [
        {{- range $i, $stub := .Values.mocks.wiremock.stubs }}
        {{- if $i }},{{ end }}
        {
          "request": {{- $stub.request | toJson -}},
          "response": {{- $stub.response | toJson -}},
          "priority": {{ default 5 $stub.priority }},
          "metadata": { "owner": {{ $owner | quote }} }
        }
        {{- end }}
      ]
    }
{{- end }}
```

> **Why a ConfigMap and not env-vars on the Job?** Stub mappings can be large (response bodies, JSON schemas). ConfigMaps cap at 1 MiB — generous for stubs, hard wall for response payloads (use `__files/` mounted via a separate ConfigMap if a single stub body is > 256 KiB). Env-var size limits are kernel-dependent and surprise you in production.

### `myorg.wiremock.syncJob`

The Job is the workhorse. It runs as a Helm hook on every install/upgrade and reconciles **only this release's mappings**. It does **NOT** call `/__admin/reset` — that would wipe every other consumer.

```yaml
{{- define "myorg.wiremock.syncJob" -}}
{{- $owner := include "myorg.fullname" . -}}
{{- $admin := include "myorg.wiremock.adminUrl" . -}}
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ $owner }}-wiremock-sync
  labels:
    {{- include "myorg.labels" . | nindent 4 }}
  annotations:
    helm.sh/hook: post-install,post-upgrade
    helm.sh/hook-weight: "5"
    helm.sh/hook-delete-policy: before-hook-creation,hook-succeeded
spec:
  backoffLimit: 3
  ttlSecondsAfterFinished: 300
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: sync
          image: curlimages/curl:8.10.1
          command: ["/bin/sh", "-c"]
          args:
            - |
              set -eu
              echo "Waiting for WireMock admin API..."
              until curl -fsS "{{ $admin }}/__admin/health" >/dev/null; do sleep 2; done
              echo "Removing existing mappings owned by {{ $owner }}..."
              curl -fsS -X POST "{{ $admin }}/__admin/mappings/remove" \
                -H "Content-Type: application/json" \
                -d '{"metadata": {"owner": {"equalTo": "{{ $owner }}"}}}'
              echo "Importing new mappings for {{ $owner }}..."
              curl -fsS -X POST "{{ $admin }}/__admin/mappings/import" \
                -H "Content-Type: application/json" \
                --data-binary @/stubs/stubs.json
              echo "Done."
          volumeMounts:
            - name: stubs
              mountPath: /stubs
              readOnly: true
      volumes:
        - name: stubs
          configMap:
            name: {{ $owner }}-wiremock-stubs
{{- end }}
```

A sibling helper renders the **pre-delete** cleanup Job:

```yaml
{{- define "myorg.wiremock.cleanupJob" -}}
{{- $owner := include "myorg.fullname" . -}}
{{- $admin := include "myorg.wiremock.adminUrl" . -}}
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ $owner }}-wiremock-cleanup
  annotations:
    helm.sh/hook: pre-delete
    helm.sh/hook-weight: "5"
    helm.sh/hook-delete-policy: before-hook-creation,hook-succeeded
spec:
  backoffLimit: 1
  ttlSecondsAfterFinished: 60
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: cleanup
          image: curlimages/curl:8.10.1
          command: ["/bin/sh", "-c"]
          args:
            - |
              set -eu
              curl -fsS -X POST "{{ $admin }}/__admin/mappings/remove" \
                -H "Content-Type: application/json" \
                -d '{"metadata": {"owner": {"equalTo": "{{ $owner }}"}}}' || true
{{- end }}
```

The trailing `|| true` is intentional: if WireMock is already gone, the consumer's `helm uninstall` should still succeed.

---

## CONSUMER APPLICATION CONTRACT

A consumer chart that wants mocked dependencies adds three things — and **nothing else** — to its chart:

### 1. `values.yaml`

```yaml
mocks:
  wiremock:
    enabled: false        # Default OFF. Enable in values-test.yaml / values-preview.yaml only.
    # adminUrl override is permitted only for migration scenarios; default is the in-cluster DNS.
    stubs: []
```

### 2. `values-test.yaml` (or `values-preview.yaml`)

```yaml
mocks:
  wiremock:
    enabled: true
    stubs:
      - request:
          method: GET
          urlPath: /v1/customers/42
        response:
          status: 200
          jsonBody: { id: 42, name: "Test Customer", tier: "gold" }
          headers:
            Content-Type: application/json
      - request:
          method: POST
          urlPath: /v1/payments
          bodyPatterns:
            - matchesJsonPath: "$.amount"
        response:
          status: 201
          jsonBody: { id: "pay_test_001", status: "succeeded" }
        priority: 1
```

> The consumer writes **only the mock-relative path** (`/v1/customers/42`). The library helper rewrites it to `/__mocks__/<release-fullname>/v1/customers/42` automatically. **Never** prefix paths manually in values — collisions WILL happen.

### 3. `templates/wiremock-sync.yaml`

```yaml
{{- if .Values.mocks.wiremock.enabled }}
{{- include "myorg.wiremock.stubsConfigMap" . }}
---
{{- include "myorg.wiremock.syncJob" . }}
---
{{- include "myorg.wiremock.cleanupJob" . }}
{{- end }}
```

That is the entire consumer surface area. Three lines of include.

### 4. App configuration points at the shared instance

Show the runtime container how to reach its mocks. Two patterns — choose one consistent with the existing chart's config style:

**Environment variables** (simplest):

```yaml
env:
  - name: EXTERNAL_API_BASE_URL
    value: "http://wiremock.testing-system.svc.cluster.local:8080/__mocks__/{{ include "myorg.fullname" . }}"
```

**`appsettings.Test.json`** (.NET conventions):

```json
{
  "ExternalApi": {
    "BaseUrl": "http://wiremock.testing-system.svc.cluster.local:8080/__mocks__/<release-fullname>"
  }
}
```

Render `<release-fullname>` from the chart at build time; do not hardcode it.

### 5. The consumer namespace MUST carry the consumer label

Without `wiremock.io/consumer=true` on the consuming app's namespace, the NetworkPolicy in `testing-system` blocks the request. Two options:

- **Recommended:** the namespace is created elsewhere (a separate namespaces addon) and the label is asserted there.
- **Inline:** the consumer chart patches the namespace via `myorg.wiremock.consumerLabel` (a fourth helper, optional, that emits a `kubectl-style` patch via a Helm post-install Job).

---

## STUB AUTHORING CONVENTIONS

| Concern | Rule |
|---------|------|
| URL prefix | Never write `/__mocks__/...` in values — the helper adds it. Write the **mock-relative** path. |
| Path matchers | Prefer `urlPath` (exact) and `urlPathPattern` (regex on path) over `url` (matches path + query). |
| Query params | Use `queryParameters: { foo: { equalTo: "bar" } }` — never bake `?foo=bar` into `url`. |
| Body matchers | `bodyPatterns:` with `matchesJsonPath`, `equalToJson { ignoreExtraElements: true }`, or `matchesXPath`. |
| Response templating | Enable per-stub: `"response": { "transformers": ["response-template"], "body": "{{request.path.[2]}}" }`. |
| Priority | Always set explicitly when stubs overlap. WireMock's default priority is 5; lower number = higher priority. |
| Stateful scenarios | Allowed but `scenarioName` MUST start with `<release-fullname>-` — collisions across consumers create non-deterministic flakes. |
| Fault injection | Allowed: `"fault": "EMPTY_RESPONSE" | "RANDOM_DATA_THEN_CLOSE" | "MALFORMED_RESPONSE_CHUNK" | "CONNECTION_RESET_BY_PEER"`. Use sparingly — chaos mocks pollute logs. |
| Large bodies | Bodies > 256 KiB go in a separate `__files` ConfigMap; reference from stub via `"bodyFileName"`. Bodies > 1 MiB do not fit in a ConfigMap — use object storage and `proxyBaseUrl` instead. |
| Recording mode | Forbidden — the addon disables it. If a consumer attempts `POST /__admin/recordings/start`, WireMock will accept it but `policy/controller`-style admission should reject any change to that endpoint at the platform level. |

### Example: stub with templated response

```json
{
  "request": {
    "method": "GET",
    "urlPathPattern": "/v1/orders/([0-9]+)"
  },
  "response": {
    "status": 200,
    "transformers": ["response-template"],
    "headers": { "Content-Type": "application/json" },
    "jsonBody": {
      "id": "{{request.path.[2]}}",
      "status": "shipped",
      "now": "{{now offset='-1 days' format='yyyy-MM-dd'}}"
    }
  }
}
```

---

## CONSUMING WIREMOCK FROM APPLICATION CODE

The cluster instance is just HTTP. No client library is required.

### .NET (`HttpClient` against the cluster instance)

```csharp
// Program.cs — typed client, base URL from configuration
builder.Services.AddHttpClient<ICustomersClient, CustomersClient>(c =>
{
    c.BaseAddress = new Uri(builder.Configuration["ExternalApi:BaseUrl"]!);
    c.Timeout = TimeSpan.FromSeconds(5);
});
```

`appsettings.Test.json`:

```json
{
  "ExternalApi": {
    "BaseUrl": "http://wiremock.testing-system.svc.cluster.local:8080/__mocks__/customer-service-test/"
  }
}
```

> The trailing slash matters — `HttpClient.BaseAddress + "v1/customers"` only concatenates correctly when the base URL ends with `/`.

### Go

```go
baseURL := os.Getenv("EXTERNAL_API_BASE_URL") // injected by Helm
client := &http.Client{Timeout: 5 * time.Second}
resp, err := client.Get(baseURL + "/v1/customers/42")
```

### Node / TypeScript

```ts
const baseURL = process.env.EXTERNAL_API_BASE_URL!;
const res = await fetch(`${baseURL}/v1/customers/42`);
```

---

## `WireMock.Net` — IN-PROCESS UNIT TESTS (DIFFERENT TOOL, DIFFERENT SCOPE)

`WireMock.Net` is a separate library — not the cluster instance, not deployed via Helm. It runs in the test process. Use it for:

- Pure unit tests where the SUT is a typed `HttpClient`-using class.
- Tests that must verify **outgoing** request shape (method, headers, body) without coordinating a multi-tenant admin API.
- Tests that need a sub-second startup and zero cluster dependency.

Do **not** use `WireMock.Net` for integration tests that run inside the cluster — they should hit the shared instance via DNS like the production app does.

### xUnit fixture (`WireMockFixture.cs`)

```csharp
using WireMock.Server;
using WireMock.Settings;

public sealed class WireMockFixture : IAsyncLifetime
{
    public WireMockServer Server { get; private set; } = null!;

    public Task InitializeAsync()
    {
        Server = WireMockServer.Start(new WireMockServerSettings
        {
            Port = 0,                  // ephemeral port; read Server.Url after start
            StartAdminInterface = false // tests stub via .Given(...) — no admin needed
        });
        return Task.CompletedTask;
    }

    public Task DisposeAsync()
    {
        Server.Stop();
        Server.Dispose();
        return Task.CompletedTask;
    }
}
```

### Stubbing a request

```csharp
using WireMock.RequestBuilders;
using WireMock.ResponseBuilders;

public class CustomersClientTests : IClassFixture<WireMockFixture>
{
    private readonly WireMockFixture _fx;

    public CustomersClientTests(WireMockFixture fx) => _fx = fx;

    [Fact]
    public async Task GetCustomer_ReturnsParsed()
    {
        _fx.Server
            .Given(Request.Create()
                .WithPath("/v1/customers/42")
                .UsingGet())
            .RespondWith(Response.Create()
                .WithStatusCode(200)
                .WithHeader("Content-Type", "application/json")
                .WithBodyAsJson(new { id = 42, name = "Test" }));

        var client = new CustomersClient(new HttpClient { BaseAddress = new Uri(_fx.Server.Url!) });
        var customer = await client.GetAsync(42);

        Assert.Equal(42, customer.Id);
        // Verify: method, headers, body shape on the recorded request
        var requests = _fx.Server.LogEntries.ToList();
        Assert.Single(requests);
    }
}
```

### Boundary: when to use which

| Scenario | Tool |
|----------|------|
| `dotnet test` against `CustomersClient` in isolation | `WireMock.Net` |
| Helm-deployed test pod calling its dependencies | Shared cluster WireMock |
| Verifying outgoing request body shape, header contract, retry behavior | `WireMock.Net` (`LogEntries`) |
| End-to-end preview environment with three apps stubbing each other | Shared cluster WireMock |
| Local developer loop without a cluster | `WireMock.Net` OR `docker run wiremock/wiremock` — both fine |

`WireMock.Net` mappings can also be loaded from the same JSON files the cluster Admin API consumes — they share a wire format. This means a stub written for cluster integration can be reused as-is in a `.NET` unit test:

```csharp
_fx.Server.WithMapping(File.ReadAllText("Stubs/customer-42.json"));
```

---

## OPERATIONS

### Upgrades

WireMock addon upgrade is a `Recreate` rollout. Existing in-memory mappings are lost — that is the point. Every consumer's sync Job re-registers its mappings on the next reconcile loop. ArgoCD `selfHeal: true` ensures consumers re-sync within a few minutes; if a consumer's app is not currently deployed, its stubs simply do not come back until that app is deployed.

> **Do not** add a PVC for stubs to "preserve them across upgrades". That breaks the reproducibility-from-values guarantee and silently masks consumer drift.

### Restart procedure (admin, by hand)

```bash
kubectl -n testing-system rollout restart deploy/wiremock
# Then trigger ArgoCD sync on consumers, OR just wait selfHeal interval:
argocd app list -l platform.io/wiremock-consumer=true | xargs -L1 argocd app sync
```

### Backup / restore

Intentionally none. Mocks are reproducible from consumer values. If consumer values are lost, you have a bigger problem than missing stubs.

### Resource sizing

- 1 replica is correct for the multi-tenant model. Multi-replica WireMock requires sticky-session affinity AND state-replication — not worth it for a test-tier dependency.
- `requests: 100m / 256Mi` covers ~50 stubs × 100 RPS comfortably. Bump `limits.memory` if `--max-request-journal-entries` is increased.
- Disable the request journal (`--no-request-journal`) under high load; re-enable only when actively debugging stub matches.

---

## VALIDATION GATES

Inherits the four-tier gate from `addons-and-building-blocks`:

```makefile
.PHONY: lint test
lint:
	yamllint -c .yamllint.yml addon_charts/wiremock/
	helm lint addon_charts/wiremock/ --strict
	helm-unittest addon_charts/wiremock/tests/chart/

test: lint
	helm template release-test addon_charts/wiremock/tests/chart/ \
	  | kubeconform -strict -summary -kubernetes-version 1.30.0
```

### `tests/chart/tests/deployment_test.yaml` (helm-unittest)

```yaml
suite: wiremock deployment
templates:
  - 10-deployment.yaml
tests:
  - it: renders nothing when disabled
    set: { wiremock.enabled: false }
    asserts:
      - hasDocuments: { count: 0 }

  - it: renders Recreate strategy when enabled
    set: { wiremock.enabled: true }
    asserts:
      - hasDocuments: { count: 1 }
      - equal:
          path: spec.strategy.type
          value: Recreate

  - it: pins recordingMode never via args
    set: { wiremock.enabled: true }
    asserts:
      - matchRegex:
          path: spec.template.spec.containers[0].args
          pattern: "--no-request-journal"
```

### Consumer-side helm-unittest (in the consumer chart's `tests/chart/`)

```yaml
suite: wiremock sync
templates:
  - wiremock-sync.yaml
tests:
  - it: emits sync job and configmap when enabled
    set:
      mocks.wiremock.enabled: true
      mocks.wiremock.stubs:
        - request: { method: GET, urlPath: /v1/foo }
          response: { status: 200 }
    asserts:
      - hasDocuments: { count: 3 }   # ConfigMap + sync Job + cleanup Job
      - matchRegex:
          path: data["stubs.json"]
          pattern: "/__mocks__/RELEASE-NAME-CHART"   # owner-prefixed automatically

  - it: tags every mapping with owner metadata
    set:
      mocks.wiremock.enabled: true
      mocks.wiremock.stubs:
        - request: { method: GET, urlPath: /v1/foo }
          response: { status: 200 }
    asserts:
      - matchRegex:
          path: data["stubs.json"]
          pattern: '"owner":\s*"RELEASE-NAME-CHART"'
```

---

## ANTI-PATTERNS

| Anti-pattern | Why it breaks the platform |
|--------------|----------------------------|
| WireMock as a sidecar in every consumer pod | Defeats the entire shared-instance design; multiplies cluster cost; no central observability of stub matches |
| Multiple WireMock Deployments in `testing-system` | Sync Jobs race; same Service load-balances across instances with diverging in-memory state |
| `replicaCount: 3` on the addon | In-memory mappings are not replicated; one instance answers "matched", the next answers "no stub" |
| Persistent volume for stubs | Masks consumer drift; on a fresh cluster the stubs disappear and nobody knows why; no source of truth |
| Calling `POST /__admin/reset` from a consumer Job | Wipes every other consumer's mappings — the most damaging single-action mistake on a shared instance |
| Hardcoding `/__mocks__/<release>` in consumer values | Defeats the helper's collision protection; any rename of the release breaks every stub silently |
| Recording mode enabled (`/__admin/recordings/start`) | Captures real third-party API responses on a multi-tenant instance — guaranteed PII/credentials leakage |
| Using `WireMock.Net` as the cluster image | It is in-process; the standalone Docker image is unofficial and lags the Java image on features/CVEs |
| Allowing the addon in `values-prod.yaml` | Production traffic occasionally hits mock endpoints by accident — exfiltration vector and silent data loss |
| Skipping the NetworkPolicy | `/__admin/*` has no auth; any pod in the cluster can wipe every stub via one curl |
| Stub bodies inlined > 1 MiB in values | ConfigMap render fails at apply time; debug message is unhelpful |
| `helm.sh/hook: post-delete` for cleanup | Service may be torn down before the Job runs; cleanup silently fails; orphaned mappings accumulate |
| Forgetting `wiremock.io/consumer=true` on the consumer namespace | Sync Job hangs on `curl /__admin/health`; backoffLimit eventually fails the install — appears as a phantom "WireMock down" |
| Different addon name in `Chart.yaml` vs `addon_charts/<dir>` vs `base_chart/values.yaml` | ArgoCD points at a non-existent path; sync fails with a misleading "manifest not found" |

---

## PRE-DONE VERIFICATION CHECKLIST

Before declaring a WireMock-related task complete, every box must be checked.

**Addon chart (`addon_charts/wiremock/`)**
- [ ] `Chart.yaml` declares `plat-eng-commons-package` as an OCI dependency in the version range used by the rest of the platform.
- [ ] `values.yaml` ships `enabled: false` as default.
- [ ] `values-prod.yaml` (if it exists at this layer) does NOT set `enabled: true`.
- [ ] Single-replica `Deployment` with `strategy.type: Recreate`.
- [ ] No PVC, no `volumeClaimTemplates`, no statefulness on disk.
- [ ] `--no-request-journal` and `--max-request-journal-entries` set to bounded values.
- [ ] `recordingMode: never` documented in values comments AND enforced by `extraArgs`.
- [ ] `securityContext` runs non-root, read-only root FS, drops `ALL` capabilities.
- [ ] NetworkPolicy default-deny + allow `wiremock.io/consumer=true` only.
- [ ] ServiceMonitor scraping `/__admin/metrics`.
- [ ] `tests/chart/` wrapper exists and exercises at least the Deployment, Service, NetworkPolicy templates.

**Base-chart wiring**
- [ ] `base_chart/templates/{NN}-wiremock.yaml` exists; `{NN}` matches `argocd.argoproj.io/sync-wave`.
- [ ] `base_chart/values.yaml` carries `wiremock.addon_name: wiremock` and `wiremock.namespace: testing-system`.
- [ ] `values-prod.yaml` overrides do not enable WireMock.

**Library helpers (`plat-eng-commons-package`)**
- [ ] `myorg.wiremock.adminUrl`, `myorg.wiremock.stubsConfigMap`, `myorg.wiremock.syncJob`, `myorg.wiremock.cleanupJob` exist.
- [ ] Every helper template ends with `| trunc 63 | trimSuffix "-"` on any name-emitting expression.
- [ ] `metadata.owner = include "myorg.fullname" .` is enforced by the helper, not the consumer.
- [ ] URL prefix `/__mocks__/<fullname>/` is added by the helper, not the consumer.
- [ ] No consumer chart redefines any `myorg.wiremock.*` template.

**Consumer chart**
- [ ] `mocks.wiremock.enabled: false` in default `values.yaml`.
- [ ] Stubs declared only in test/preview overlay `values-*.yaml`.
- [ ] `templates/wiremock-sync.yaml` is exactly the three-line include block.
- [ ] App config (env var or `appsettings.*.json`) points at `wiremock.testing-system.svc.cluster.local:8080/__mocks__/<fullname>/`.
- [ ] Consumer namespace carries label `wiremock.io/consumer=true` (asserted by namespace addon or patched by the chart).
- [ ] helm-unittest verifies the rendered ConfigMap contains `metadata.owner=<release>`.
- [ ] No stub URL written in values starts with `/__mocks__/` — they are mock-relative paths only.

**.NET unit tests with `WireMock.Net`**
- [ ] Fixture uses `WireMockServer.Start(new WireMockServerSettings { Port = 0 })` — no fixed port.
- [ ] Tests assert against `Server.LogEntries` for outgoing-request shape, not just response parsing.
- [ ] No `WireMock.Net` server is started inside cluster pods — only in `dotnet test`.

**Validation**
- [ ] `yamllint`, `helm lint --strict`, `helm-unittest`, `kubeconform -strict` all pass locally.
- [ ] `make all` parity with CI.
- [ ] CI pins Helm to v3.20.0 (per parent skill).
- [ ] PR not merged into `master` directly — feature branch + required checks + CODEOWNERS on `templates/**`.

If any box is unchecked, the task is not done.
