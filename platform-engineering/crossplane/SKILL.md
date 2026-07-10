---
name: crossplane
description: >-
  MUST USE when authoring, reviewing, installing, or operating a **Crossplane
  control plane** — building Managed Resources, Composite Resources (XRs),
  CompositeResourceDefinitions (XRDs), Compositions, Composition Functions,
  Providers, Configurations, and packages with the `crossplane` CLI and
  `pkg.crossplane.io` / `apiextensions.crossplane.io` APIs. Covers Crossplane
  v2 (current, GA) first — namespaced XRs (`scope` Namespaced), the removal of
  Claims, namespaced Managed Resources (the `.m.` API-group infix), namespaced
  ProviderConfig plus ClusterProviderConfig, and functions-only composition
  (`mode` Pipeline, native patch-and-transform removed) — and flags v1
  differences plus migration (`crossplane beta upgrade check`). Use for —
  installing Crossplane (Helm into crossplane-system), installing a Provider and
  wiring ProviderConfig credentials (Secret / IRSA / GKE & AKS workload
  identity), writing a Managed Resource (`forProvider`, `managementPolicies`,
  `deletionPolicy`, importing existing cloud resources), designing an XRD as a
  versioned API, writing a Composition function pipeline (`function-patch-and-transform`,
  `function-auto-ready`, `function-environment-configs`, `function-go-templating`,
  `function-kcl`), building and signing packages (`crossplane xpkg build` / `push`,
  `crossplane.yaml`, ImageConfig + Cosign), delivering Crossplane via GitOps
  (ArgoCD / Flux), safe-start MR activation (`ManagedResourceDefinition` +
  `ManagedResourceActivationPolicy`), developing a provider (Upjet vs native,
  `provider-template`), the in-cluster on-ramp (`provider-kubernetes` `Object` +
  `InjectedIdentity`), testing compositions (`crossplane composition render` /
  `resource validate` / `resource trace`, formerly `render` / `validate` / `beta
  trace`), and day-2 Operations. Triggers on phrases — "crossplane", "control
  plane kubernetes", "composite resource", "XRD", "CompositeResourceDefinition",
  "crossplane composition", "composition function", "function pipeline",
  "managed resource", "provider config", "crossplane provider", "crossplane
  package", "configuration package", "xpkg", "crossplane render", "composition
  render", "resource validate", "claim to XR", "namespaced XR", "managementPolicies",
  "providerConfigRef", "safe start", "ManagedResourceDefinition", "MRD",
  "ManagedResourceActivationPolicy", "MRAP", "provider development",
  "provider-template", "upjet", "provider-kubernetes", "Object managed resource",
  "InjectedIdentity", "observability as code", "x-generation". Triggers on file
  patterns — `crossplane.yaml`, `**/*composition*.yaml`, `**/*xrd*.yaml`,
  `**/definition.yaml`, YAML with `apiextensions.crossplane.io` /
  `pkg.crossplane.io` / `forProvider:` / `compositeTypeRef:`, `**/functions.yaml`.
  This is about BUILDING a Crossplane control plane; for merely *consuming*
  provider-shipped Managed Resources inside Helm building blocks + ArgoCD see
  `addons-and-building-blocks`. Authored by a distinguished Platform Engineer —
  emphasizes v2-native namespaced multi-tenancy, functions-first composition,
  least-privilege provider credentials, provider families over monoliths, and
  GitOps-delivered control planes.
license: BSD-3-Clause
compatibility: opencode
metadata:
  domain: platform-engineering
  pattern: kubernetes-control-plane
  platform: kubernetes
  stack: crossplane-v2 + compositions + functions + packages + olm-free-gitops
  frameworks: crossplane, composition-functions, upbound-providers, upjet, provider-kubernetes, argocd
  version: crossplane-v2-first-v1-flagged
  use_cases: platform-api-authoring, infrastructure-composition, control-plane-operations, provider-development, observability-as-code
---

# Crossplane

You are a Platform Engineer building and operating a **Crossplane control
plane**. Crossplane turns a Kubernetes cluster into a **universal control plane**:
you extend the Kubernetes API with your own resources, and Crossplane runs the
**reconcile loop** that drives external systems (cloud APIs, SaaS, in-cluster
workloads) toward the declared desired state. You give application teams a
**self-service, opinionated platform API** instead of raw cloud primitives.

This skill is **Crossplane v2-first** (v2 is GA — the current `latest` docs).
v2 changed the model substantially versus v1; every v1 difference is flagged
inline so you can author for v2 and still recognize/maintain v1 control planes.

> **Scope boundary.** This skill is about **building** the control plane — Managed
> Resources, XRDs, Compositions, Functions, packages, install, GitOps delivery.
> For *consuming* a provider's Managed Resources from inside a Helm building-block
> chart (the `| quote` rules, ServerSideApply, ArgoCD App-of-Apps wiring), see the
> sibling skill **`addons-and-building-blocks`**. Don't duplicate that here.

---

## CORE PRINCIPLES (NON-NEGOTIABLE)

> Violating any of these is an automatic review failure.

### 1. Crossplane is a control plane, not a one-shot provisioner
Every resource is **continuously reconciled**: Crossplane observes actual external
state and converges it to `spec`. It corrects drift, retries, and re-derives
desired state every loop. Design declaratively — never imperative "run once" logic.

### 2. The control plane manages convergence; it is not in the data path
If Crossplane (or a provider) is down, **already-created external resources keep
running** — you only lose reconciliation, drift correction, and new provisioning.
Treat the control-plane cluster as **tier-0 infra**, but never put the operand's
runtime traffic through it.

### 3. The XRD is a stable, versioned, public API
A `CompositeResourceDefinition` is a contract application teams build on. Version
it (`v1alpha1 → v1beta1 → v1`), validate input at the boundary (OpenAPI + CEL),
and **never make a breaking schema change in place**. Resources created against v1
outlive the people who wrote it.

### 4. Compose with FUNCTIONS (v2) — patch-and-transform is a function now
In v2 every Composition is `mode: Pipeline`; the legacy native patch-and-transform
(`mode: Resources` / `spec.resources`) is **removed**. Patch-and-transform survives
only as `function-patch-and-transform`. Each pipeline step **must copy all prior
desired state into its response** — anything not copied is dropped (and deleted if
it already exists).

### 5. Least-privilege provider credentials
Prefer **workload identity** (EKS IRSA, GKE Workload Identity, AKS Workload
Identity) over static Kubernetes Secrets. Never commit provider credentials to Git.
Restrict who can install Providers/Functions and create XRDs/Compositions
(platform team) versus who can create XRs (namespace users).

### 6. Provider families, never monoliths
Monolithic providers install hundreds–thousands of CRDs (`provider-aws` > 900),
bloating the API server and tanking GitOps UIs. Install **family members**
(`provider-aws-s3`, `provider-aws-rds`, …) and/or use v2 **ManagedResourceActivationPolicy**
to activate only the CRDs you use.

### 7. Quote string-typed `forProvider` fields
Unquoted YAML scalars get coerced: a region `"012345"` becomes an int, a version
`"1.20"` becomes a float, `on`/`true` becomes a bool — and the provider's schema
validation rejects it. This is the #1 Managed-Resource bug.

### 8. Fully-qualified package URLs, pinned
v2 removed the implicit default registry. Always use a full OCI reference
(`xpkg.crossplane.io/crossplane-contrib/provider-aws-s3:v2.0.0`), and prefer a
`@sha256:` digest in production. Sign and verify packages with `ImageConfig`.

---

## VERSION MAP — Crossplane v1 ↔ v2 (READ THIS FIRST)

v2.0 went GA in **August 2025**; the current series is **v2.x** (pin examples to
the version you actually run — don't hardcode a patch number). The deltas below
are the highest-blast-radius facts in this skill:

| Concern | v1 | v2 (current, GA) |
|---|---|---|
| **XRD apiVersion** | `apiextensions.crossplane.io/v1` | **`apiextensions.crossplane.io/v2`** |
| **Composition apiVersion** | `apiextensions.crossplane.io/v1` | **`apiextensions.crossplane.io/v1`** (UNCHANGED — see note) |
| **XR scope** | Cluster-scoped only | new `spec.scope`: **`Namespaced`** (default) \| `Cluster` \| `LegacyCluster` |
| **Claims (XRC)** | core pattern (namespaced Claim → cluster XR) | **REMOVED**; `claimNames` deprecated. Create the XR directly (namespaced). Claims survive only under `scope: LegacyCluster` |
| **XR kind naming** | XR = `XApp` (X-prefix), Claim = `App` | XR = `App` directly — no proxy object |
| **Managed Resources** | cluster-scoped (`s3.aws.upbound.io`) | **namespaced** via the `.m.` infix (`s3.aws.m.upbound.io`, `metadata.namespace`) — provider-dependent |
| **ProviderConfig** | cluster-scoped `ProviderConfig` only | namespaced **`ProviderConfig`** + cluster-wide **`ClusterProviderConfig`** |
| **Composition mode** | `Resources` (native P&T) or `Pipeline` | **`Pipeline` only**; native P&T removed |
| **Patch & transform** | built into the Composition | **`function-patch-and-transform`** |
| **Pod runtime config** | `ControllerConfig` (deprecated) | **`DeploymentRuntimeConfig`** (`pkg.crossplane.io/v1beta1`) |
| **`spec.crossplane`** | machinery at XR top level | Crossplane machinery moved under **`spec.crossplane`** on the XR |
| **Removed in v2** | — | external secret stores, composite-level connection details, implicit default registry |
| **MR activation** | all provider CRDs active | **`ManagedResourceDefinition` + `ManagedResourceActivationPolicy`** (`...v1alpha1`, alpha) |
| **Day-2 ops** | — | **`Operation` / `CronOperation` / `WatchOperation`** (`ops.crossplane.io/v1alpha1`, alpha) |

> ⚠️ **Counterintuitive but correct:** the **XRD** moved to
> `apiextensions.crossplane.io/v2`, but the **`Composition`** stays on
> `apiextensions.crossplane.io/v1`. Do **NOT** "fix" a Composition to `/v2` — that
> apiVersion does not exist for `Composition`. (Corroborated against the API
> reference and the official composition examples.)

**Migration:** run **`crossplane beta upgrade check`** (v1.20+) before upgrading;
it flags use of removed/deprecated features (native P&T, ControllerConfig,
external secret stores). Most v1 control planes upgrade cleanly; `scope:
LegacyCluster` keeps cluster XRs + Claims working during transition.

**Provider-dependency caveat:** namespaced Managed Resources are GA for AWS at v2;
Azure / GCP / Terraform / Helm provider families were still migrating at GA — check
the specific provider's CRDs (does it expose a `.m.` group?) before relying on
namespaced MRs.

---

## INSTALL & CONTROL-PLANE TOPOLOGY

Run Crossplane on a **dedicated control-plane cluster**, separate from workload
clusters. Install via Helm into `crossplane-system`:

```bash
helm repo add crossplane-stable https://charts.crossplane.io/stable
helm repo update
helm install crossplane \
  --namespace crossplane-system --create-namespace \
  crossplane-stable/crossplane
kubectl get pods -n crossplane-system   # core + RBAC manager + package manager
```

Install the **`crossplane` CLI** (separate from the chart — used for packaging and
local testing, mostly cluster-free):

```bash
curl -sfL https://cli.crossplane.io/install.sh | sh
# pin: ... | XP_VERSION=v2.3.0 sh
```

The core deployment runs the **package manager** (Provider/Function/Configuration
lifecycle) and the **RBAC manager**. Each installed Provider/Function runs as its
own Deployment in `crossplane-system`. Prereqs: a supported Kubernetes version and
Helm v3.2+.

> **Pause the control plane** for maintenance:
> `kubectl -n crossplane-system scale deploy/crossplane --replicas=0` (stops
> management; external resources keep running). Scale back to `1` to resume.

---

## PHASE A — PROVIDERS & CREDENTIALS

### A.1 Install a Provider (family member, pinned, fully-qualified)

```yaml
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-aws-s3
spec:
  package: xpkg.crossplane.io/crossplane-contrib/provider-aws-s3:v2.0.0
  # production: pin a digest → xpkg.crossplane.io/.../provider-aws-s3@sha256:ee6b...
  packagePullPolicy: IfNotPresent       # IfNotPresent (default) | Always | Never
  revisionActivationPolicy: Automatic   # Automatic (default) | Manual
  revisionHistoryLimit: 1
```

`kubectl get providers` / `kubectl get providerrevisions` — exactly one revision is
`Active`; roll back by activating a prior revision. The package manager
auto-resolves dependencies unless `skipDependencyResolution: true`.

> Install **family members** (`provider-aws-s3`, `provider-aws-rds`), not the
> monolithic `provider-aws`. Family members share auth via the family config
> provider and install only their service's CRDs (Principle 6).

### A.2 ProviderConfig — credentials (v2: namespaced + cluster-wide)

```yaml
# Namespaced — applies to MRs in this namespace only
apiVersion: aws.m.upbound.io/v1beta1
kind: ProviderConfig
metadata:
  namespace: default
  name: aws-provider
spec:
  credentials:
    source: Secret
    secretRef: { namespace: crossplane-system, name: aws-creds, key: creds }
---
# Cluster-wide — the default an MR uses when providerConfigRef is omitted
apiVersion: aws.m.upbound.io/v1beta1
kind: ClusterProviderConfig
metadata: { name: default }
spec:
  credentials: { source: Secret, secretRef: { namespace: crossplane-system, name: aws-creds, key: creds } }
```

A Managed Resource selects its config by name **and kind**:

```yaml
spec:
  providerConfigRef: { name: aws-provider, kind: ProviderConfig }  # or ClusterProviderConfig
```

### A.3 Credential strategies (prefer workload identity)

| Platform | Strategy | Wiring |
|---|---|---|
| Any | **Static Secret** (fallback) | `Secret` + `credentials.source: Secret`. Rotate manually, never in Git. |
| AWS EKS | **IRSA** | Annotate the provider ServiceAccount `eks.amazonaws.com/role-arn: <role-arn>`; `source: IRSA`/`WebIdentity` (provider-specific). Needs cluster OIDC + IAM trust to the SA. |
| GCP GKE | **Workload Identity** | Annotate SA `iam.gke.io/gcp-service-account: <gsa>`; `source: InjectedIdentity`; bind GSA↔KSA. |
| Azure AKS | **Workload Identity** | Annotate SA `azure.workload.identity/client-id`+`tenant-id`, label pod `azure.workload.identity/use: "true"`; federated credential MI↔KSA. |

> The exact non-`Secret` `source` enum is **provider-specific** — confirm in the
> provider family's docs.

> **Two-step image-pull gotcha:** workload identity on the Crossplane SA covers
> pulling *package* content, but **the node/kubelet independently pulls the
> provider's runtime image** and needs its own registry access (node IAM role /
> kubelet identity). WI on the SA alone won't fix `ImagePullBackOff` on the
> controller pod.

### A.4 DeploymentRuntimeConfig (pod customization — replaces v1 ControllerConfig)

```yaml
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata: { name: provider-gcp-iam }
spec:
  package: xpkg.crossplane.io/crossplane-contrib/provider-gcp-iam:v2.0.0
  runtimeConfigRef: { name: tuned }
---
apiVersion: pkg.crossplane.io/v1beta1
kind: DeploymentRuntimeConfig
metadata: { name: tuned }
spec:
  deploymentTemplate:
    spec:
      selector: {}
      template:
        spec:
          containers:
          - name: package-runtime        # required name; first container
            args: ["--debug"]
```

Use for replicas, resource limits, tolerations/nodeSelector, securityContext
(defaults `runAsNonRoot: true`, `runAsUser: 2000`), and provider flags. Unset →
the `default` runtime config.

> **Runtime container must be named `package-runtime`** — any other container name
> is treated as a **sidecar**, not the provider/function process.

### A.5 `provider-kubernetes` — the in-cluster on-ramp (no cloud creds)

The fastest way to learn Crossplane without a cloud account: `provider-kubernetes`
manages **arbitrary Kubernetes objects** (in-cluster or remote) as Managed Resources,
and authenticates to its *own* cluster via `InjectedIdentity` (its ServiceAccount —
no external kubeconfig).

```yaml
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata: { name: provider-kubernetes }
spec:
  package: xpkg.crossplane.io/crossplane-contrib/provider-kubernetes:v0.18.0  # pin to your version
---
apiVersion: kubernetes.crossplane.io/v1alpha1
kind: ProviderConfig
metadata: { name: default }
spec:
  credentials: { source: InjectedIdentity }   # authenticate as the provider's own SA
```

The provider's ServiceAccount needs RBAC on the objects it manages. **Grant a
least-privilege ClusterRole** scoped to the specific kinds — do **not** copy the
`cluster-admin` binding from beginner tutorials into anything real:

```bash
# find the provider SA (read-only)
kubectl -n crossplane-system get sa -o name | grep provider-kubernetes
# then bind a NARROW ClusterRole you authored (not cluster-admin) to it
```

An `Object` MR embeds any manifest under `spec.forProvider.manifest` (see B.4).

---

## PHASE B — MANAGED RESOURCES (MRs)

A Managed Resource is a provider CRD instance representing **one external
resource**. Its apiVersion is the **provider's** API group, not Crossplane's.

### B.1 Anatomy (v2 namespaced)

```yaml
apiVersion: s3.aws.m.upbound.io/v1beta1   # ".m." = namespaced (v2); ".upbound.io" = cluster (v1)
kind: Bucket
metadata:
  namespace: default                       # v2 MRs are namespaced
  name: my-bucket
spec:
  forProvider:                             # desired external state (quote string scalars!)
    region: "us-east-2"
  initProvider: {}                         # one-time-only fields (don't fight drift after create)
  providerConfigRef: { name: aws-provider, kind: ProviderConfig }
  managementPolicies: ["*"]                # what Crossplane may do (see B.2); "*" = full control (default)
  deletionPolicy: Delete                   # Delete (default) | Orphan
  writeConnectionSecretToRef:              # v2 namespaced MR: name only, written to MR's namespace
    name: my-bucket-conn
status:
  atProvider: {}                           # observed external state, written by the provider
  conditions: []                           # Ready / Synced
```

### B.2 Lifecycle — `managementPolicies` (the modern control)

Array of: `Create`, `Update`, `Delete`, `Observe`, `LateInitialize`, or `*`.

| Goal | Policy |
|---|---|
| Full control (default) | `["*"]` |
| **Pause** reconciliation | `[]` (empty) |
| Read-only / **import** | `["Observe"]` |
| Stop drift correction | drop `Update` |
| Stop importing provider-set values | drop `LateInitialize` |
| Don't delete the external resource on MR delete | drop `Delete` (or `deletionPolicy: Orphan`) |

`forProvider` is the source of truth — when `Update` is active, Crossplane corrects
drift back to it. Set `deletionPolicy: Orphan` for stateful/shared resources you
must not accidentally destroy.

### B.3 Importing existing cloud resources

1. Create the MR with `managementPolicies: ["Observe"]`.
2. Set `metadata.annotations.crossplane.io/external-name: <cloud-id>`.
3. Add disambiguating `spec.forProvider` fields (e.g. region) if needed.
4. Apply; read discovered values from `status.atProvider`.
5. To take over: copy needed `status.atProvider` values into `spec.forProvider`,
   then switch to `managementPolicies: ["*"]`.

> Importing is error-prone — Crossplane works best when it **creates** everything.
> Import deliberately; verify the diff before flipping to `*`.

### B.4 MRs beyond cloud infra — in-cluster objects & config-as-code

Managed Resources aren't only cloud APIs. Two common non-cloud uses:

**In-cluster Kubernetes objects** (`provider-kubernetes`, from A.5) — an `Object`
MR reconciles any embedded manifest, so Namespaces / ConfigMaps / Deployments
become composable platform-API building blocks:

```yaml
apiVersion: kubernetes.crossplane.io/v1alpha2
kind: Object
metadata: { name: team-a-namespace }
spec:
  forProvider:
    manifest:                                  # any Kubernetes object
      apiVersion: v1
      kind: Namespace
      metadata: { name: team-a, labels: { managed-by: crossplane } }
  providerConfigRef: { name: default }
```

**Observability-as-code** — an **Upjet-generated** provider (Upjet wraps an existing
Terraform provider into a Crossplane provider; each reconcile runs `terraform
plan/apply` internally) lets you manage SaaS/observability config as MRs. E.g.
`provider-dynatrace` (wrapping `dynatrace-oss/dynatrace`) models Dashboards,
Alerting rules, and Metric events as Managed Resources reconciled from Git — one
tooling model for apps + infra + observability. (For Dynatrace API/DQL specifics
see the `dynatrace` skill.)

```yaml
apiVersion: dashboard.crossplane.io/v1alpha1
kind: Dashboard
metadata: { namespace: crossplane-system, name: example-dashboard }
spec:
  forProvider:
    contents: |
      {"dashboardMetadata":{"name":"team-a","preset":true},"tiles":[]}
  providerConfigRef: { name: default }
```

> **Upjet caveat:** a per-reconcile `terraform apply` is compute-heavy at large
> resource counts, and you now reason about **two state stores** (etcd + the TF
> backend). Auto-generated providers usually need some hand customization.

---

## PHASE C — COMPOSITION (XRD + Composition + the XR)

The composition trio: an **XRD** declares the API → a **Composition** implements it
via a function pipeline → a user creates an **XR** (v2, namespaced, directly).

### C.1 CompositeResourceDefinition (XRD) — v2

```yaml
apiVersion: apiextensions.crossplane.io/v2     # v2
kind: CompositeResourceDefinition
metadata:
  name: apps.example.crossplane.io             # must be <plural>.<group>
spec:
  scope: Namespaced                            # v2: Namespaced (default) | Cluster | LegacyCluster
  group: example.crossplane.io
  names:
    kind: App                                  # v2: the XR kind directly — no X-prefix, no claim
    plural: apps
  # NO claimNames in v2 (claims removed)
  versions:
  - name: v1
    served: true
    referenceable: true                        # a Composition may target this version
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              image: { type: string, description: The app's OCI image. }
              replicas: { type: integer, default: 2, minimum: 1 }
            required: [image]
            # CEL cross-field validation at the API boundary:
            x-kubernetes-validations:
            - rule: "self.replicas <= 10"
              message: "replicas must be <= 10"
          status:
            type: object
            properties:
              address: { type: string }
```

Other XRD fields: `connectionSecretKeys[]`, `defaultCompositionRef`,
`defaultCompositionUpdatePolicy` (`Automatic` \| `Manual` — controls auto-adoption
of a new Composition revision), `enforcedCompositionRef` (pin every XR to one
Composition), the `scale` subresource (enables `kubectl scale` / HPA / KEDA on the
XR), and `conversion` (version conversion). **v2-deprecated:** `claimNames`,
`defaultCompositeDeletePolicy`.

> **XRD gotchas (from the official docs):**
> - You **cannot change** an XRD's `group` or `names` after creation — delete and
>   recreate. Plan them once.
> - Crossplane **ignores** reserved fields if you declare them in the schema:
>   `spec.crossplane.*`, `status.crossplane.*`, `status.conditions`.
> - **Restart the Crossplane pod** after a schema change for it to take effect.
> - Only **one** version may be `referenceable: true`; a version needs both
>   `served: true` + `referenceable: true` to be usable.
> - For a **breaking** change, Crossplane recommends shipping a **brand-new XRD**
>   over a conversion webhook (Principle 3).

### C.1a XRD API-design rules (the API is forever)

An XRD is a public contract; treat schema design like public-API design:

| Rule | Why |
|---|---|
| Use **required fields sparingly** | A required field can never be safely removed later. |
| **Prefer an `enum` over a `bool`** | `engine: PostgreSQL\|MySQL` extends cleanly; `usePostgres: true` traps you. |
| **When in doubt, use an array** | Scalar→array migrations need ugly double-field workarounds. |
| **Leave room for variants** | Nest engine-specific fields (`spec.postgresql`, `spec.mysql`). |
| **Expose only what teams need** | The platform team controls real specs in the Composition; the XRD surface stays minimal and opinionated. |
| **`matchControllerRef: true`** in resource selectors | Scopes a selector to resources this XR owns — avoids binding unrelated resources. |

### C.2 Composition — v2 (Pipeline only)

```yaml
apiVersion: apiextensions.crossplane.io/v1     # ← STAYS v1 even though the XRD is v2. Do NOT bump.
kind: Composition
metadata:
  name: app
spec:
  compositeTypeRef:                            # which XR this satisfies
    apiVersion: example.crossplane.io/v1
    kind: App
  mode: Pipeline                               # the only mode in v2
  pipeline:
  - step: resources                            # ordered steps; each calls an installed Function
    functionRef: { name: function-patch-and-transform }
    input:
      apiVersion: pt.fn.crossplane.io/v1beta1
      kind: Resources
      resources:                               # what used to be spec.resources lives here now
      - name: bucket
        base:
          apiVersion: s3.aws.m.upbound.io/v1beta1
          kind: Bucket
          spec:
            forProvider: { region: "us-east-2" }
        patches:
        - type: FromCompositeFieldPath
          fromFieldPath: spec.image
          toFieldPath: metadata.annotations[example.crossplane.io/image]
        - type: ToCompositeFieldPath
          fromFieldPath: status.atProvider.arn
          toFieldPath: status.address
  - step: ready                                # typical final step
    functionRef: { name: function-auto-ready }
```

### C.3 Consuming the abstraction — XR (v2) vs Claim (v1)

```yaml
# v2: create the XR directly (namespaced). No proxy, no claim.
apiVersion: example.crossplane.io/v1
kind: App
metadata: { namespace: team-a, name: my-app }
spec:
  image: nginx
  replicas: 3
  # v2: Crossplane machinery (compositionRef etc.) lives under spec.crossplane
  crossplane:
    compositionRef: { name: app }
```

```yaml
# v1 (legacy): user creates a namespaced Claim (kind = claimNames.kind);
# Crossplane auto-creates a cluster-scoped XApp. Only under scope: LegacyCluster in v2.
apiVersion: example.crossplane.io/v1
kind: App
metadata: { namespace: team-a, name: my-app }
spec:
  image: nginx
  compositionRef: { name: app }                # v1: compositionRef at spec top level
  writeConnectionSecretToRef: { name: my-app-conn }
```

> **v2 multi-tenancy:** namespaced XRs + namespaced MRs replace the v1
> Claim-per-namespace pattern. Scope teams to namespaces with RBAC + quotas; the
> XR *is* the user-facing abstraction.

### C.4 Generating XRDs + Compositions (x-generation)

Hand-scaffolding an XRD + Composition for every provider CRD is tedious.
**`crossplane-contrib/x-generation`** introspects a provider's CRDs and emits the
XRD + Composition (Pipeline mode, `function-patch-and-transform`) from a two-file
config: a global `generator-config.yaml` (provider `baseURL`/`name`/`version`,
`labels`/`tags`, `usePipeline: true`, `additionalPipelineSteps`) and a
per-composition `generate.yaml` (`group`/`name`/`version`, the CRD file+version,
`overrideFieldsInClaim` to rename/reshape fields).

> **v2 caveat:** x-generation predates the v2 Claim-less model — its output is still
> **v1 Claim/XRD-shaped**. Treat it as a *starting scaffold*: regenerate, then adapt
> to v2 (namespaced XRs, drop `claimNames`, keep Pipeline mode) before shipping.
> `tags.fromLabels` entries must also exist in `labels.fromCRD`.

---

## PHASE D — COMPOSITION FUNCTIONS

Functions are gRPC servers (packaged as `Function` packages) that the pipeline
calls each reconcile. **Composition is functions-only in v2.**

### D.1 Install a Function

```yaml
apiVersion: pkg.crossplane.io/v1
kind: Function
metadata:
  name: function-patch-and-transform           # functionRef.name must match THIS metadata.name
spec:
  package: xpkg.crossplane.io/crossplane-contrib/function-patch-and-transform:v0.8.2
```

### D.2 The pipeline / desired-state model (critical)

- Steps run **in order**. Each step receives the desired state accumulated so far,
  its own `input`, and a shared writable **Context**, and returns the desired state.
- **A step MUST copy all prior desired state into its response** — anything it omits
  is dropped, and if that resource already exists Crossplane **deletes** it.
- `functionRef.name` references the **installed `Function` object's name**, not the
  package image.
- **Readiness:** end most pipelines with `function-auto-ready`, which marks the XR
  `Ready` once all composed resources report ready. Don't hand-roll readiness.

### D.3 `function-patch-and-transform` vocabulary

Input: `apiVersion: pt.fn.crossplane.io/v1beta1`, `kind: Resources`.

**Patch types:**

```yaml
patches:
- type: FromCompositeFieldPath          # XR → composed resource
  fromFieldPath: spec.region
  toFieldPath: spec.forProvider.region
- type: ToCompositeFieldPath            # composed resource → XR status
  fromFieldPath: status.atProvider.id
  toFieldPath: status.id
- type: CombineFromComposite           # many XR fields → one target
  combine:
    variables: [{ fromFieldPath: spec.a }, { fromFieldPath: spec.b }]
    strategy: string
    string: { fmt: "res-%s-%s" }
  toFieldPath: metadata.name
# also: CombineToComposite (many composed fields → one XR field)
```

**Transforms** (under a patch's `transforms:`): `map` (lookup table), `match`
(literal/regexp with fallback), `math` (multiply / clampMin / clampMax), `string`
(Format / ToUpper / ToLower / ToBase64 / TrimPrefix / TrimSuffix / Replace),
`convert` (`toType: int|string|float64|bool|object`).

**Connection details** (per composed resource): `FromConnectionSecretKey`,
`FromFieldPath`, `FromValue`.

### D.4 EnvironmentConfigs (shared platform config)

`EnvironmentConfig` (`apiextensions.crossplane.io/v1beta1`) is a cluster-scoped,
ConfigMap-like store (region maps, shared tags, network CIDRs). Load it with
`function-environment-configs` (select by `Reference` name or `Selector`
matchLabels); the merged result lands in pipeline **Context** under
`apiextensions.crossplane.io/environment`. Each XR gets an isolated in-memory
environment (no cross-XR leakage).

### D.5 The official function toolbox

| Function | Use |
|---|---|
| `function-patch-and-transform` | P&T as a function — the v2 replacement for native P&T |
| `function-auto-ready` | derive XR readiness from composed-resource readiness (usual last step) |
| `function-environment-configs` | inject `EnvironmentConfig` data into Context |
| `function-go-templating` | Helm/Go-template-style resource rendering |
| `function-kcl` / `function-cue` | KCL / CUE composition languages |
| `function-extra-resources` | fetch arbitrary existing cluster resources into the pipeline |

Write **custom functions in Go or Python** (official gRPC SDKs); test with golden
`RunFunctionRequest`/`Response` fixtures + end-to-end `crossplane composition render`.

---

## PHASE E — PACKAGES & DISTRIBUTION

Three package types, each an **OCI image** (xpkg format) managed by the package
manager. Deploy them with `pkg.crossplane.io`; author metadata with
`meta.pkg.crossplane.io`.

| Type | Deploy kind | Meta kind | Revision | Contains |
|---|---|---|---|---|
| **Provider** | `Provider` | `Provider` | `ProviderRevision` | controllers + MR CRDs |
| **Configuration** | `Configuration` | `Configuration` | `ConfigurationRevision` | XRDs + Compositions (+ deps) |
| **Function** | `Function` | `Function` | `FunctionRevision` | a composition function |

### E.1 Configuration packages — bundle your platform API

`crossplane.yaml` (authoring metadata):

```yaml
apiVersion: meta.pkg.crossplane.io/v1
kind: Configuration
metadata: { name: platform-apis }
spec:
  crossplane: { version: ">=v2.0.0-0" }
  dependsOn:
  - apiVersion: pkg.crossplane.io/v1
    kind: Provider
    package: xpkg.crossplane.io/crossplane-contrib/provider-aws-s3
    version: ">=v2.0.0"
  - apiVersion: pkg.crossplane.io/v1
    kind: Function
    package: xpkg.crossplane.io/crossplane-contrib/function-patch-and-transform
    version: ">=v0.8.0"
```

Build & push (CLI):

```bash
crossplane xpkg build --package-root=. --package-file=platform-apis.xpkg
crossplane xpkg push  xpkg.crossplane.io/<org>/platform-apis:v0.1.0
```

Install in-cluster:

```yaml
apiVersion: pkg.crossplane.io/v1
kind: Configuration
metadata: { name: platform-apis }
spec: { package: xpkg.crossplane.io/<org>/platform-apis:v0.1.0 }
```

### E.2 ImageConfig — registry auth, mirroring, and signing

```yaml
# Restrict to signed first-party packages (alpha: --enable-signature-verification)
apiVersion: pkg.crossplane.io/v1beta1
kind: ImageConfig
metadata: { name: verify-platform }
spec:
  matchImages:                              # longest-prefix match wins; only type: Prefix
  - { type: Prefix, prefix: xpkg.crossplane.io/<org>/ }
  registry:
    authentication:
      pullSecretRef: { name: registry-creds }   # dockerconfigjson in crossplane-system
  verification:
    provider: Cosign                        # only Cosign supported
    cosign:
      authorities:
      - name: org-signing
        keyless:
          identities:
          - issuer: https://token.actions.githubusercontent.com
            subject: https://github.com/<org>/packages/.github/workflows/release.yml@refs/heads/main
```

`ImageConfig` also does **image rewrite/mirror** (`spec.rewriteImage.prefix` — runs
first, then pull-secret/signature apply to the rewritten path) for air-gapped/proxy
registries. Result in `status.resolvedPackage`; a `Verified` condition reports
signature status.

### E.3 Safe-start — MRD + activation policy (alpha, on by default in v2)

Large providers install hundreds of MR CRDs, costing 300+ MiB of API-server memory.
**Safe-start** installs a provider but keeps its CRDs uncreated until you activate
the ones you use. Both kinds are `apiextensions.crossplane.io/v1alpha1` (**alpha**),
require Crossplane + crossplane-runtime **v2.0+**, and are **on by default**.

- **`ManagedResourceDefinition` (MRD)** — the schema for one MR (`spec.group`,
  `spec.names`, `spec.scope`, `spec.versions[]`, `spec.connectionDetails[]`,
  **`spec.state`** = `Inactive` \| `Active`). In v2.0+ Crossplane **auto-converts
  every provider CRD into an MRD on install** (disable with the core flag
  `--enable-custom-to-managed-resource-conversion=false`). Activating an MRD creates
  its CRD — so **`Inactive → Active` is ONE-WAY** (you can't un-create by flipping
  back).
- **`ManagedResourceActivationPolicy` (MRAP)** — declares which MRDs to activate.
  The field is **`spec.activate[]`** (a list of exact plural CRD names, e.g.
  `buckets.s3.aws.m.crossplane.io`, **or a prefix-only wildcard**
  `*.s3.aws.m.crossplane.io` — mid-string wildcards like `s3.*.aws...` are invalid).
  MRAPs are **additive**: an MRD is active if it matches ≥1 pattern in *any* MRAP.

**safe-start is a provider *capability*, not a core flag.** A provider whose
`package/crossplane.yaml` declares `spec.capabilities: [safe-start]` defaults its
MRDs to `Inactive` (opt-in activation); a provider **without** the capability
defaults them to `Active` (all CRDs created, legacy behavior). The Helm chart also
creates a default MRAP with `spec.activate: ["*"]` (activates everything) unless you
override `--set provider.defaultActivations={}`.

```yaml
apiVersion: apiextensions.crossplane.io/v1alpha1
kind: ManagedResourceActivationPolicy
metadata: { name: activate-s3 }
spec:
  activate:
  - buckets.s3.aws.m.crossplane.io          # exact plural name
  - "*.s3.aws.m.crossplane.io"              # prefix-only wildcard
```

Inspect: `kubectl get mrds -o wide` (find `Inactive`), `kubectl describe mrap <n>`,
`kubectl get providerrevision <n> -o jsonpath='{.status.capabilities}'` (does the
provider even support safe-start?). Combine safe-start with **provider families** to
keep the API server lean. There are no `crossplane` CLI subcommands for MRD/MRAP —
manage them via `kubectl`.

---

## PHASE F — GITOPS DELIVERY (ArgoCD / Flux)

Deliver Providers, ProviderConfigs, Functions, XRDs, Compositions, and
Configurations from Git. Crossplane needs specific ArgoCD settings — these are
**required**, not optional:

- `application.resourceTrackingMethod: annotation` in `argocd-cm` (label tracking
  breaks on Crossplane resources).
- **Custom Lua health checks** for `*.crossplane.io/*` and `*.upbound.io/*` (evaluate
  `Ready`/`Synced`/`Healthy`/`Established`/`Installed`); special-case
  `ProviderConfig`/`ClusterProviderConfig` (may have no status).
- **Exclude `ProviderConfigUsage`** from the UI (`resource.exclusions`) — they
  multiply and tank ArgoCD reactivity.
- `ARGOCD_K8S_CLIENT_QPS=300` (default 50) — large provider CRD counts blow past it.
- ArgoCD ≥ 2.4.8.

**Ordering** (use ArgoCD sync waves / Flux `dependsOn`):
`Provider` (+ wait `Healthy`/`Installed`) → `ProviderConfig` → `XRD`+`Composition`+`Function`
→ `XR`. Use **ServerSideApply** for provider/CRD manifests — official providers ship
hundreds of large CRDs that exceed the client-side-apply annotation limit (262 KB).

> Sync waves + SSA are practitioner convention (the official ArgoCD guide documents
> tracking/health/exclusions/QPS but not these) — verify against your ArgoCD version.

---

## PHASE G — TESTING & VALIDATION (the CI gate)

All cluster-free; wire `composition render | resource validate` into CI as the
Composition test gate. The CLI verbs were **renamed off `beta`** — current names
lead below, older aliases in comments:

```bash
# Render an XR through the function pipeline locally (Docker by default):
crossplane composition render xr.yaml composition.yaml functions.yaml \
  --observed-resources=observed/   # -o: feed mock observed MRs → test UPDATE/drift paths
  --required-resources=extra/      # -e: mock EnvironmentConfigs / extra resources
  --include-full-xr                # -x
  # older CLI: `crossplane render …`

# Schema + CEL validation (pipe render output via stdin):
crossplane composition render xr.yaml composition.yaml functions.yaml --include-full-xr \
  | crossplane resource validate schemas.yaml -
  # older CLI: `crossplane validate …`

# Live debugging — relationship tree of an XR and its composed resources:
crossplane resource trace App my-app -n team-a -o wide
# older CLI: `crossplane beta trace …`
```

- **Render against observed resources** (`-o`) to test update/drift, not just
  create. `--context-values KEY=VALUE` injects pipeline context.
- `crossplane resource validate` checks MRs/XRs/render output against
  Provider/XRD/CRD/Function schemas and evaluates XRD CEL rules.

> **CLI subcommand paths are version-sensitive.** Current: `crossplane composition
> render`, `crossplane resource validate`, `crossplane resource trace`, `crossplane
> xpkg install`. Older versions used `render` / `validate` / `beta trace`. Always
> check `crossplane --help` for the version you actually run.

---

## PHASE H — DEVELOPING A PROVIDER (when none exists)

Most work uses existing providers (Phase A). When no provider covers your external
API, you build one. **First decision — Upjet vs native:**

- **A Terraform provider exists** → generate with **Upjet** (the Crossplane
  code-gen project that wraps a Terraform provider into a Crossplane provider; each
  reconcile runs `terraform plan/apply` internally). Fastest path; most Official
  providers are Upjet-generated. AWS has a dedicated code-gen guide.
- **No Terraform provider** → write a **native** provider in Go on
  **`crossplane-runtime/v2`** — the golden path for full control / no TF dependency.

### H.1 Scaffold from `provider-template`

```bash
git clone https://github.com/crossplane/provider-template
make submodules
export provider_name=MyProvider            # CamelCase, e.g. GitHub
make provider.prepare provider=${provider_name}
export group=sample                        # lower: core/cache/database/storage
export type=Bucket                         # CamelCase kind
make provider.addtype provider=${provider_name} group=${group} kind=${type}
```

Layout: `apis/` (types) · `internal/controller/` (controllers + `register.go`) ·
`cmd/` (entrypoint) · `examples/` · `package/` (`crossplane.yaml` + CRDs) ·
`Makefile` · `build/` submodule. Then define types with kubebuilder, e.g.
`kubebuilder create api --group example --version v1alpha1 --kind Bucket
--resource=true --controller=false`.

### H.2 Implement the external client

Each MR type implements the reconcile contract via crossplane-runtime:

- **`ExternalConnecter`** → produces an **`ExternalClient`** in `Connect` (using the
  MR's `ProviderConfig` credentials).
- **`ExternalClient`** implements **`Observe` / `Create` / `Update` / `Delete`**.
  `Observe` returns `managed.ExternalObservation{ResourceExists, ResourceUpToDate,
  ConnectionDetails}`; set well-known conditions (`xpv1.Creating()` / `Available()`
  / `Deleting()`).
- **Ignore expected errors**: `resource.Ignore(IsNotFound, err)` on `Delete`,
  `resource.Ignore(IsAlreadyExists, err)` on `Create` — otherwise reconcile wedges.
- Wire with `managed.NewReconciler(...)` in `SetupWithManager`, and register the
  controller in `internal/controller/register.go` via **`SetupGated`** so the
  controller only starts once its CRD is **activated** (safe-start aware — E.3).

### H.3 Build, test, and package

- **`make reviewable`** — runs codegen (CRDs + `angryjet` runtime-method helpers),
  lint, and tests. Then `make build`.
- **Table-driven tests** with Go's stdlib `testing` — the Crossplane convention is
  **NOT Ginkgo** for provider unit tests.
- Declare `spec.capabilities: [safe-start]` in `package/crossplane.yaml` so your
  MRDs default to `Inactive` (E.3). Package doc comments go in **`doc.go`**.
- Build/push the provider package exactly like any Provider package (Phase E:
  `crossplane xpkg build` / `push`).

> **Provider-dev anti-patterns:** accidentally "adopting" an unrelated external
> resource (guard your external-name lookup); blindly accepting kubebuilder
> scaffolding instead of copying an existing v1beta1 resource's Crossplane patterns;
> `Delete`/`Create` erroring on not-found/already-exists; adding Ginkgo; putting
> package docs anywhere but `doc.go`. Open a **draft PR early** for maintainer review
> before writing the controller.

---

## DAY-2 OPERATIONS & TROUBLESHOOTING

- **Operations (alpha, `ops.crossplane.io/v1alpha1`):** `Operation` (run a function
  pipeline to completion like a Job), `CronOperation` (scheduled), `WatchOperation`
  (on resource changes) — for day-2 tasks that don't fit create/reconcile.
- **Diagnose an MR:** `kubectl describe <mr> <name>` → read the **`Ready`/`Synced`**
  conditions + Events (e.g. "cannot get referenced ProviderConfig").
- **Logs:** `kubectl -n crossplane-system logs -l app=crossplane` (core) and the
  provider/function pods; enable `--debug` via `DeploymentRuntimeConfig`.
- **Observability gap:** Crossplane only sees the Kubernetes view — a failing
  resource may be Crossplane *or* the cloud API. Check MR conditions/events **and**
  cloud-side logs.
- **Stuck resource (last resort):** `kubectl patch <res> -p '{"metadata":{"finalizers":[]}}' --type=merge`
  — may orphan the external resource; understand before doing it.

---

## ANTI-PATTERNS (each one fails review)

| Anti-pattern | Why it breaks | Do instead |
|---|---|---|
| Unquoted string `forProvider` values | YAML coerces `"012345"`→int, `"1.20"`→float, `on`→bool; schema rejects | Quote every string-typed field (Principle 7) |
| Authoring **Claims** in a v2-native control plane | Claims removed in v2 (`claimNames` deprecated) | Create namespaced XRs directly; Claims only under `scope: LegacyCluster` |
| Bumping `Composition` to `apiextensions.crossplane.io/v2` | That apiVersion doesn't exist for Composition | Composition stays `/v1`; only the XRD is `/v2` |
| `mode: Resources` / native patch-and-transform | Removed in v2 | `mode: Pipeline` + `function-patch-and-transform` |
| A pipeline step that drops prior desired state | Crossplane deletes the omitted composed resources | Each step copies all prior desired state into its response |
| Monolithic provider (`provider-aws`) | 900+ CRDs; API-server + GitOps-UI pain | Provider families + MRD/MRAP activation |
| Non-fully-qualified / unpinned package URLs | v2 removed the default registry; drift risk | Full `xpkg.crossplane.io/...` ref, `@sha256` in prod |
| Static Secret credentials by default | Leak risk; manual rotation | Workload identity (IRSA / GKE WI / AKS WI) |
| Breaking an XRD schema in place | Breaks every stored XR | New version + conversion (Principle 3) |
| Hand-rolling XR readiness | Brittle | `function-auto-ready` |
| `ControllerConfig` for pod tuning | Removed in v2 | `DeploymentRuntimeConfig` |
| Deleting a Provider/Composition while XRs/MRs depend on it | Orphans/wedges resources | Delete XRs/MRs first; order teardown |
| Label-based ArgoCD tracking for Crossplane | Breaks on Crossplane resources | `resourceTrackingMethod: annotation` + Lua health checks |
| Over-abstraction (giant catch-all XRD) | Defeats the platform-API purpose | Narrow, opinionated XRDs per capability |
| Scripting `crossplane render` / `validate` / `beta trace` as the only names | Renamed off `beta`; may not exist on current CLI | Lead with `composition render` / `resource validate` / `resource trace`; check `crossplane --help` |
| MRAP `spec.activations:` or a mid-string wildcard (`s3.*.aws…`) | Field is `spec.activate[]`; only prefix wildcards (`*.s3.aws…`) match | Use `spec.activate` with exact plural names or a prefix `*` wildcard |
| Expecting to flip an MRD `Active → Inactive` | Activation creates the CRD; the transition is one-way | Activate deliberately; only `Inactive → Active` |
| `cluster-admin` for the `provider-kubernetes` SA | Grants the control plane full cluster write | Author a narrow least-privilege ClusterRole for the kinds it manages |
| Shipping x-generation output as-is | Output is v1 Claim/XRD-shaped | Adapt to v2 (namespaced XRs, drop `claimNames`, keep Pipeline) before merge |
| Ginkgo / blind kubebuilder scaffolding in a provider | Breaks Crossplane conventions; table-driven tests are the norm | Copy an existing v1beta1 resource's patterns; stdlib `testing`; `doc.go` for docs |

---

## PRE-DONE VERIFICATION CHECKLIST

**Providers & credentials**
- [ ] Provider is a **family member**, fully-qualified + pinned (digest in prod); `Healthy`/`Installed`.
- [ ] Credentials via workload identity where possible; no secrets in Git; node-level image pull works.

**Managed Resources**
- [ ] All string `forProvider` fields quoted; `managementPolicies`/`deletionPolicy` intentional.
- [ ] Imports done via `Observe` + `crossplane.io/external-name`, diff verified before `*`.

**Composition**
- [ ] XRD is `apiextensions.crossplane.io/v2`, versioned, CEL-validated; **Composition is `/v1`**.
- [ ] `mode: Pipeline`; every step copies prior desired state; pipeline ends with readiness.
- [ ] Functions installed and `functionRef.name` matches the `Function` object name.
- [ ] v2: users create namespaced XRs directly (no Claims unless `LegacyCluster`).

**Packages & delivery**
- [ ] Configuration `crossplane.yaml` lists provider + function deps; `xpkg build`/`push` clean.
- [ ] `ImageConfig` for registry auth/signing where required.
- [ ] GitOps: annotation tracking, Lua health checks, `ProviderConfigUsage` excluded, QPS raised, SSA, ordered sync waves.

**Safe start & activation**
- [ ] Safe-start providers declare `capabilities: [safe-start]`; MRAP `spec.activate[]` lists exact plural names or prefix `*` wildcards; activation is intentional (one-way).

**Provider development (if building one)**
- [ ] Upjet-vs-native chosen deliberately; scaffolded from `provider-template`; `ExternalClient` CRUD ignores not-found/already-exists; registered via `SetupGated`; table-driven tests; `make reviewable` clean.

**Testing**
- [ ] `crossplane composition render` (incl. `-o` observed) + `crossplane resource validate` pass in CI; `resource trace` clean live (verify verb path with `crossplane --help`).

---

## REFERENCE

### API kinds & apiVersions (verify against your installed version)
| Kind | apiVersion | Notes |
|---|---|---|
| `CompositeResourceDefinition` | `apiextensions.crossplane.io/v2` | v1 in legacy |
| `Composition` | `apiextensions.crossplane.io/v1` | **stays v1** |
| `CompositionRevision` | `apiextensions.crossplane.io/v1` | Crossplane-managed |
| `EnvironmentConfig` | `apiextensions.crossplane.io/v1beta1` | shared config |
| `ManagedResourceDefinition` / `ManagedResourceActivationPolicy` | `apiextensions.crossplane.io/v1alpha1` | alpha |
| `Provider` / `Configuration` / `Function` (deploy) | `pkg.crossplane.io/v1` | `spec.package` OCI ref |
| `DeploymentRuntimeConfig` / `ImageConfig` | `pkg.crossplane.io/v1beta1` | runtime / registry policy |
| `Provider`/`Configuration`/`Function` (authoring) | `meta.pkg.crossplane.io/v1` | in `crossplane.yaml` |
| `Lock` | `pkg.crossplane.io/v1beta1` | package-manager dependency lock |
| `ControllerConfig` | `pkg.crossplane.io/v1alpha1` | **deprecated** → `DeploymentRuntimeConfig` |
| `Usage` / `ClusterUsage` | `protection.crossplane.io/v1beta1` | deletion-ordering; moved here from apiextensions (deprecated there) |
| `Object` (provider-kubernetes) | `kubernetes.crossplane.io/v1alpha2` | in-cluster k8s object as an MR |
| `Operation` / `CronOperation` / `WatchOperation` | `ops.crossplane.io/v1alpha1` | day-2, alpha |

### CLI map (subcommand path is version-sensitive — check `crossplane --help`)
Current names: `crossplane composition render` (older: `render`) · `crossplane
resource validate` (older: `validate`) · `crossplane resource trace` (older: `beta
trace`) · `crossplane xpkg build` / `push` / `install` (older: `beta`-prefixed) ·
`crossplane beta upgrade check` (v1→v2 migration). MRD/MRAP have **no** CLI
subcommands — manage via `kubectl`.

### Ecosystem
Providers + Functions come from the **Upbound Marketplace** (`marketplace.upbound.io`)
and the community **`crossplane-contrib`** org. Images are served from
**`xpkg.crossplane.io`** (proxying GHCR `ghcr.io/crossplane-contrib`) — the old
`xpkg.upbound.io` default is gone. **Upbound** builds the Official (Upjet/Terraform-
generated) providers + the managed control-plane product; upstream Crossplane is the
CNCF project. Pin every example to the provider/function versions you run.

---

## MCP SURFACE (read-only)

Crossplane **is** a Kubernetes API extension — every inspection is a `kubectl
get/describe/explain/logs`, so a read-only Kubernetes MCP server is the natural
agent surface. Keep it read-only: a sync / `xpkg push` / apply / rollback is always
a separate, human-approved action.

| Server | Use | Notes |
|---|---|---|
| **containers/kubernetes-mcp-server** (`--read-only`) | inspect Providers / ProviderRevisions / Functions / Compositions / XRDs / XRs / MRs / **MRDs / MRAPs**, the `.crossplane.io` + `.upbound.io` CRDs, conditions (`Ready`/`Synced`/`Installed`/`Healthy`/`Established`), events, and provider/function pod logs | `--read-only` blocks create/update/delete/apply. The primary surface — the `tools/` scripts below cover the same reads as plain `kubectl`. |
| **github/github-mcp-server** (`--read-only`, scoped to `repos`/`pull_requests`) | the **GitOps PR-gated** delivery of packages / XRDs / Compositions — read the promotion PR, checks, diffs | The PR is the approval gate; the MCP only reads it. |
| **context7** (optional) | pull current Crossplane / provider docs (apiVersions + CLI verbs are version-sensitive) | discovery aid, not a control surface. |

This skill *drives* the Kubernetes MCP read-only; the agentic tool-belt +
blast-radius doctrine lives in the `agentic-k8s-ops` skill — it is not owned here.

---

## TOOLS (read-only audit scripts)

`tools/` ships small `bash` + `kubectl get` scripts (no `jq`, no mutation) — review
before running; each only reads. See `tools/AGENTS.md`.

| Script | Surfaces |
|---|---|
| `crossplane-health-check.sh` | core pods; `providers` (INSTALLED/HEALTHY); `functions`; `configurations`; `providerrevisions` (one Active); `lock` |
| `crossplane-resource-audit.sh` | MRs (`kubectl get managed`) not Ready/Synced; `deletionPolicy`/`managementPolicies`; XRs; provider-kubernetes `objects` |
| `crossplane-activation-audit.sh` | safe-start posture: `mrds -o wide` (Inactive vs Active); `mrap` `spec.activate`/`status.activated`; providerrevision capabilities |
| `crossplane-package-audit.sh` | Provider/Function/Configuration `spec.package` fully-qualified + pinned + `@sha256` digest; `imageconfig` presence |

---

## SUBAGENT ORCHESTRATION

When this repo's Crossplane subagents are installed (`.claude/agents/`), delegate
phase work to the specialist; this skill is the shared contract. The subagents are
**repo-scoped** — installing only this `SKILL.md` elsewhere will not carry them.

| Phase | Subagent | Owns |
|---|---|---|
| Install / A / F | `crossplane-control-plane-operator` | install, Providers, ProviderConfig credentials, GitOps (ArgoCD/Flux) delivery, troubleshooting; `crossplane-health-check.sh` |
| B | `crossplane-managed-resource-author` | Managed Resources, `managementPolicies`/`deletionPolicy`, importing, provider-kubernetes `Object`s; `crossplane-resource-audit.sh` |
| C / D | `crossplane-composition-author` | XRDs, Compositions (Pipeline), function pipelines, EnvironmentConfigs, x-generation |
| E | `crossplane-package-publisher` | Provider/Configuration/Function packages, `crossplane.yaml`, `xpkg build/push`, ImageConfig signing, safe-start MRD/MRAP; `crossplane-activation-audit.sh` + `crossplane-package-audit.sh` |
| H | `crossplane-provider-developer` | building a provider (Upjet vs native, `provider-template`, `ExternalClient` CRUD, `SetupGated` safe-start) |
| G | `crossplane-tester` | `crossplane composition render`/`resource validate`/`resource trace`, CI gate |

Every subagent enforces the **CORE PRINCIPLES** and the **VERSION MAP** above, and
treats the MCP surface as read-only. For end-to-end work, run
control-plane-operator → managed-resource-author → composition-author →
package-publisher → tester; add provider-developer up front when no provider exists.
