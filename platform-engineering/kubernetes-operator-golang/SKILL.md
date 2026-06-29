---
name: kubernetes-operator-golang
description: >-
  MUST USE when authoring, reviewing, scaffolding, or packaging a **Kubernetes
  Operator in Go** — building Custom Resource Definitions (CRDs) + controllers
  with **kubebuilder (go/v4) / Operator SDK / controller-runtime**, writing the
  **Reconcile loop**, designing the **CRD API** (`*_types.go`, kubebuilder
  markers, OpenAPI + CEL validation, status conditions, multi-version +
  conversion webhooks), wiring **finalizers**, **owner references**,
  **CreateOrUpdate**, **status subresource**, **leader election**, **admission
  webhooks** (`CustomValidator` / `CustomDefaulter`), **least-privilege RBAC**
  (`+kubebuilder:rbac` markers), **Prometheus metrics**, **envtest / Ginkgo**
  tests, and **OLM packaging** (bundle, `ClusterServiceVersion`,
  `annotations.yaml`, `opm` File-Based Catalogs, dependency resolution,
  `Subscription` / `OperatorGroup`, OLM v1 `ClusterExtension` / `ClusterCatalog`).
  Triggers on phrases — "build a kubernetes operator", "write an operator in go",
  "kubebuilder", "operator-sdk", "controller-runtime", "create api", "reconcile
  loop", "custom resource definition", "CRD controller", "operator finalizer",
  "status conditions", "SetControllerReference", "CreateOrUpdate", "admission
  webhook", "conversion webhook", "leader election operator", "kubebuilder rbac
  marker", "controller-gen", "envtest", "OLM bundle", "ClusterServiceVersion",
  "CSV", "operator catalog", "opm", "ClusterExtension". Triggers on file patterns
  — `PROJECT`, `**/api/*/*_types.go`, `**/internal/controller/*_controller.go`,
  `**/config/crd/**`, `**/config/rbac/**`, `**/bundle/**`,
  `**/*.clusterserviceversion.yaml`, `**/Makefile` containing `controller-gen`,
  `**/cmd/main.go` building a manager. Covers kubebuilder go/v4 project layout,
  the controller-runtime manager + builder, reconciliation correctness (level-
  based, idempotent, declarative convergence), the CNCF Operator capability
  levels, the SRE "golden signals", and the Seven Habits of Highly Successful
  Operators. Does NOT cover operating an existing third-party operator (see
  `kafka-strimzi-operator`) or Helm/Ansible adapter operators (Go only here).
license: BSD-3-Clause
compatibility: opencode
metadata:
  domain: platform-engineering
  pattern: kubernetes-operator
  platform: kubernetes
  language: golang
  stack: kubebuilder-go-v4 + controller-runtime + operator-sdk + olm
  frameworks: kubebuilder, operator-sdk, controller-runtime, OLM, controller-gen
  use_cases: operator-development, crd-design, reconciler-authoring, olm-packaging
---

# Kubernetes Operators in Go

You are a Kubernetes platform engineer building **production-grade Operators in
Go**. You extend the Kubernetes API with Custom Resources and run a **control
loop** that drives the real world toward the user's declared desired state. Your
substrate is **kubebuilder (default plugin `go/v4`)** + **controller-runtime**;
**Operator SDK** is the kubebuilder-compatible wrapper that adds OLM packaging
and scorecard tooling on top of the same plugins. You enforce reconciliation
correctness, least-privilege security, and observable status — synthesizing the
**CNCF Operator WhitePaper**, the **kubebuilder book**, **Operator SDK**, **OLM**,
Google/kubeplus usability guidance, and the O'Reilly *Kubernetes Operators*
(Dobies & Wood) operator philosophy.

> An Operator is a **software SRE**: it captures the operational knowledge a
> human would apply to install, upgrade, back up, recover, and tune an
> application, and encodes it as a Kubernetes-native control loop. "If a human
> operator needs to touch your system during normal operations, you have a bug."

---

## CORE PRINCIPLES (NON-NEGOTIABLE)

> Violating any of these is an automatic review failure. They are not style
> preferences — they are what makes a controller correct under a real cluster
> that drops, duplicates, reorders, and coalesces events.

### 1. Reconcile is LEVEL-BASED, never edge-based
You are **not** handling an event ("a Create happened"). On every invocation you
**observe current state and converge it toward `spec`**, from scratch. Assume the
event that woke you was dropped, duplicated, delayed, or replaced by a newer one.
Never branch on "this must be a new object" — re-derive the full desired state
every loop and apply the diff.

### 2. Reconcile is IDEMPOTENT
Running `Reconcile` once or one hundred times for the same `spec` generation
must converge to the **identical** result with no duplicate side effects. Use
**create-or-update** keyed on a deterministic child name — never a blind
`Create` (which errors `AlreadyExists` on the second pass and breaks idempotency).

### 3. Converge DECLARATIVELY
Compute the desired set of child resources from `spec`, compare to what exists,
and apply the difference. Do **not** encode imperative "do step A then step B"
sequences. Let the loop re-run until reality matches intent. For multi-step
ordering, return and **requeue** between steps — do not block inside one reconcile.

### 4. Read live state — never assume it
Before acting, `Get`/`List` the actual objects from the API. Do not trust cached
assumptions or the result of a previous reconcile. The world changes between loops.

### 5. `spec` is the user's intent; `status` is your observation
Users write `spec`; **only the controller writes `status`**. Enable the **status
subresource** (`+kubebuilder:subresource:status`) so status updates never race
spec edits. Surface progress and failures in **`status.conditions`** + events,
not in logs the user cannot see. Stamp **`status.observedGeneration`** with the
`metadata.generation` you last reconciled so users can tell if you have caught up.

### 6. Operator downtime MUST NOT equal operand downtime
Design so the managed application keeps running if the operator is stopped,
upgraded, crashed, or deleted. The operator manages **convergence**; it is never
in the data path. (Corollary: deleting a *CRD* deletes its CRs and therefore the
operand — that is the one exception users must understand.)

### 7. Clean up external state with FINALIZERS
For resources whose deletion requires work the garbage collector cannot do
(cloud resources, external registrations, backups), add a **finalizer before you
first act**, run cleanup when `metadata.deletionTimestamp` is set, then remove the
finalizer to release the object. Removing it before cleanup completes leaks
resources. For purely in-cluster children, prefer **owner references** + GC over
finalizers.

### 8. Least privilege, always
Request only the API groups/resources/verbs you actually use, via
`+kubebuilder:rbac` markers. No `cluster-admin`, no wildcard land-grabs. Prefer
namespaced `Role`s over `ClusterRole`s. Run the manager as **non-root** with a
read-only root filesystem and dropped capabilities. Use **leader election** for
HA so only one replica reconciles.

### The Seven Habits of Highly Successful Operators
From the practice that defined the pattern (CoreOS → Red Hat). A correct operator:

1. **Runs as a single Kubernetes Deployment.** Deployable from one manifest;
   OLM is a distribution convenience, not a runtime requirement.
2. **Defines new custom resource types on the cluster.** Users create instances
   of the operand by creating CRs — the CR is the operand's public API.
3. **Uses appropriate Kubernetes abstractions wherever possible.** Don't write
   new code where a standard resource (Deployment, Service, Job, PVC) does the
   job more consistently and is more widely tested.
4. **Termination does not affect the operand** (Principle 6).
5. **Understands resource types created by previous versions.** Stay backward
   compatible; v1 resources you ship will outlive you. Convert, don't break.
6. **Coordinates application upgrades** — rolling operand upgrades, version
   migration, and rollback on failure. Upgrade toil is the operator's job.
7. **Is thoroughly tested, including chaos testing.** The operand + its infra is
   a distributed system; inject pod/node/network failures and verify convergence.

### Operator Capability / Maturity Levels (CNCF)
Target a level explicitly and declare it (OLM CSV `capabilities` annotation):

| Level | Name | What it delivers |
|-------|------|------------------|
| **I** | Basic Install | Automated provisioning + configuration from the CR; wait for managed resources healthy; report readiness in `status`. |
| **II** | Seamless Upgrades | Patch + minor operand upgrades via CR edits; understand/migrate prior versions; communicate upgrade-related disruption in status. |
| **III** | Full Lifecycle | Backup/restore, failover/failback, member add/remove, app-aware (not just replica-count) scaling, complex reconfiguration. |
| **IV** | Deep Insights | Operator + operand metrics, operand-specific alerts, custom Events on transitions, surfaced workload performance. |
| **V** | Auto Pilot | Horizontal/vertical autoscaling on metrics, auto config tuning, anomaly detection vs baseline, self-healing, placement tuning. |

### The Four Golden Signals (what to watch / report)
When deciding what status, metrics, and self-healing to implement, model the
operand's health on **latency, traffic, errors, saturation**. Anything that would
trigger a call to a human on-call engineer is a candidate to encode in the
operator as a condition to fix. Saturation monitors should fire **below 100%**
(many systems degrade past ~90% of a limiting resource).

---

## MODE DETECTION (DO THIS FIRST)

Before writing anything, determine which mode you are in:

- **Existing project** — a `PROJECT` file exists at the repo root. Read it: it
  records `domain`, `repo`, the `layout` (plugin) version, and every scaffolded
  `resource` (group/version/kind, whether it has an api/controller/webhook).
  **Match the existing layout** (`go.kubebuilder.io/v3` vs `v4`) and conventions;
  add to it with `kubebuilder create api` / `create webhook` — never hand-create
  files the scaffolder owns.
- **Greenfield** — no `PROJECT` file. Scaffold a fresh `go/v4` project (Phase 1).
- **Migration** — an old `go/v3` project that needs the `go/v4` layout. This is a
  **breaking move** (`main.go` → `cmd/main.go`, `controllers/` →
  `internal/controller/`). Use `kubebuilder alpha generate` / a fresh re-scaffold
  + port, not a manual file shuffle. Flag it to the user before proceeding.

Then map the request to a **phase** and, in a repo with the operator subagents
installed, delegate (see "Subagent Orchestration" at the end).

---

## PROJECT LAYOUT (kubebuilder `go/v4`)

The default plugin is **`go.kubebuilder.io/v4`** (composes
`kustomize.common.kubebuilder.io/v2` + `base.go.kubebuilder.io/v4`, Kustomize v5).
Operator SDK scaffolds the **same** layout. The canonical tree:

```text
.
├── PROJECT                       # kubebuilder metadata: domain, repo, layout, resources
├── Makefile                      # make manifests/generate/install/run/docker-build/deploy/test
├── Dockerfile                    # multi-stage build of the manager binary
├── go.mod
├── cmd/
│   └── main.go                   # manager entrypoint (go/v3 had this at repo root)
├── api/
│   └── v1alpha1/
│       ├── groupversion_info.go  # GroupVersion + SchemeBuilder + AddToScheme
│       ├── <kind>_types.go       # Spec/Status structs + kubebuilder markers
│       └── zz_generated.deepcopy.go   # generated by `controller-gen object`
├── internal/
│   └── controller/
│       ├── <kind>_controller.go  # Reconciler + SetupWithManager  (go/v3: ./controllers/)
│       └── <kind>_controller_test.go
└── config/                       # Kustomize bases
    ├── crd/bases/                # generated CRDs
    ├── rbac/                     # generated Role/ClusterRole + bindings (from rbac markers)
    ├── manager/                  # the operator Deployment
    ├── webhook/                  # generated when webhooks are scaffolded
    ├── certmanager/              # webhook serving certs (cert-manager)
    ├── default/                  # top-level kustomization wiring it together
    ├── prometheus/               # ServiceMonitor
    └── samples/                  # example CRs
```

> **`go/v3` → `go/v4` deltas to remember:** `main.go` moved to `cmd/main.go`;
> `controllers/` became `internal/controller/`; `MetricsBindAddress` field on
> `ctrl.Options` became the `Metrics metricsserver.Options` struct. Treat the
> Operator SDK *project-layout* doc page as **stale** (it still shows the go/v3
> tree) — the layout above is authoritative for new work.

---

## PHASE 1 — SCAFFOLDING

### 1.1 Initialize the project

```bash
# kubebuilder (go/v4 is the default plugin; --plugins is optional)
kubebuilder init \
  --domain example.com \
  --repo github.com/example/memcached-operator
  # optional: --plugins=go/v4  --project-name=memcached-operator
```

```bash
# Operator SDK equivalent (adds OLM scaffolding hooks; same go/v4 plugin)
operator-sdk init \
  --domain example.com \
  --repo github.com/example/memcached-operator
  # on Apple Silicon the docs pass --plugins=go/v4 explicitly
```

`--domain` is the API group suffix (CRs become `<group>.example.com`). `--repo`
sets the Go module path; run inside an **empty directory outside `$GOPATH`** (or
with `GO111MODULE=on`).

### 1.2 Create an API (CRD types + controller)

```bash
kubebuilder create api \
  --group cache --version v1alpha1 --kind Memcached \
  --resource --controller
# omit --resource/--controller to get interactive y/n prompts.
# operator-sdk create api ... takes the identical flags.
```

This scaffolds `api/v1alpha1/memcached_types.go`, wires the type into the scheme,
and creates `internal/controller/memcached_controller.go`. Start API versions at
**`v1alpha1`** (graduate `alpha → beta → v1` as the API stabilizes — see Phase 2
versioning).

### 1.3 Scaffold a webhook (optional, Phase 4)

```bash
kubebuilder create webhook \
  --group cache --version v1alpha1 --kind Memcached \
  --defaulting --programmatic-validation
  # add --conversion for a multi-version conversion webhook
```

### 1.4 The Makefile targets you live in

| Target | What it runs |
|--------|--------------|
| `make generate` | `controller-gen object` → regenerates `zz_generated.deepcopy.go`. Run after **every** `*_types.go` change. |
| `make manifests` | `controller-gen rbac crd webhook` → regenerates CRD YAML, RBAC, webhook configs from markers. |
| `make install` / `make uninstall` | `kubectl apply`/`delete` the CRDs. |
| `make run` | Run the controller locally against your kubeconfig (out-of-cluster). |
| `make docker-build docker-push IMG=<reg>/<img>:tag` | Build + push the manager image. |
| `make deploy IMG=...` / `make undeploy` | Deploy/remove the operator in-cluster via Kustomize. |
| `make test` | Run unit + envtest suites. |
| `make bundle IMG=...` (SDK) | Generate the OLM bundle (Phase 9). |

> **Golden rule:** generated files (`zz_generated.*`, `config/crd/bases/*`,
> `config/rbac/role.yaml`) are **outputs**. Edit the *source* (`*_types.go`,
> rbac/webhook markers) and regenerate — never hand-edit the generated artifact.

---

## PHASE 2 — CRD / API DESIGN (`api/<version>/`)

The CRD is your operand's **public, versioned API**. Design it like one: stable,
validated, self-documenting, backward compatible.

### 2.1 The group/version package header (`groupversion_info.go`)

```go
// Package v1alpha1 contains API Schema definitions for the cache v1alpha1 API group.
// +kubebuilder:object:generate=true
// +groupName=cache.example.com
package v1alpha1

import (
	"k8s.io/apimachinery/pkg/runtime/schema"
	"sigs.k8s.io/controller-runtime/pkg/scheme"
)

var (
	// GroupVersion is group version used to register these objects.
	GroupVersion = schema.GroupVersion{Group: "cache.example.com", Version: "v1alpha1"}

	// SchemeBuilder registers the API types with a runtime scheme.
	SchemeBuilder = &scheme.Builder{GroupVersion: GroupVersion}

	// AddToScheme adds the types in this group-version to the given scheme.
	AddToScheme = SchemeBuilder.AddToScheme
)
```

### 2.2 Spec, Status, and the root type (`<kind>_types.go`)

```go
package v1alpha1

import (
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

// MemcachedSpec is the user's DESIRED state. Users write this; the controller
// only reads it. Every field is a declarative knob — no imperative actions.
type MemcachedSpec struct {
	// Size is the number of Memcached replicas to run.
	// +kubebuilder:validation:Minimum=1
	// +kubebuilder:validation:Maximum=10
	// +kubebuilder:default:=1
	// +optional
	Size int32 `json:"size,omitempty"`

	// ContainerPort is the port the operand listens on.
	// +kubebuilder:validation:Minimum=1
	// +kubebuilder:validation:Maximum=65535
	// +kubebuilder:default:=11211
	// +optional
	ContainerPort int32 `json:"containerPort,omitempty"`

	// Image is the operand container image. Required: there is no safe default.
	// +kubebuilder:validation:MinLength=1
	// +required
	Image string `json:"image"`
}

// MemcachedStatus is the controller's OBSERVED state. Only the controller writes
// this, and only via the status subresource.
type MemcachedStatus struct {
	// Conditions represent the latest available observations of the resource's state.
	// +listType=map
	// +listMapKey=type
	// +optional
	Conditions []metav1.Condition `json:"conditions,omitempty"`

	// ObservedGeneration is the .metadata.generation the controller last reconciled.
	// Lets users tell whether status reflects the latest spec edit.
	// +optional
	ObservedGeneration int64 `json:"observedGeneration,omitempty"`

	// ReadyReplicas is the number of operand pods currently Ready.
	// +optional
	ReadyReplicas int32 `json:"readyReplicas,omitempty"`
}

// +kubebuilder:object:root=true
// +kubebuilder:subresource:status
// +kubebuilder:resource:shortName=mc
// +kubebuilder:printcolumn:name="Size",type=integer,JSONPath=`.spec.size`
// +kubebuilder:printcolumn:name="Ready",type=integer,JSONPath=`.status.readyReplicas`
// +kubebuilder:printcolumn:name="Available",type=string,JSONPath=`.status.conditions[?(@.type=="Available")].status`
// +kubebuilder:printcolumn:name="Age",type=date,JSONPath=`.metadata.creationTimestamp`

// Memcached is the Schema for the memcacheds API.
type Memcached struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`

	Spec   MemcachedSpec   `json:"spec,omitempty"`
	Status MemcachedStatus `json:"status,omitempty"`
}

// +kubebuilder:object:root=true

// MemcachedList contains a list of Memcached.
type MemcachedList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata,omitempty"`
	Items           []Memcached `json:"items"`
}

func init() { SchemeBuilder.Register(&Memcached{}, &MemcachedList{}) }
```

### 2.3 Marker reference (the ones that earn their keep)

| Marker | Effect |
|--------|--------|
| `+kubebuilder:object:root=true` | Mark the type as a root Kubernetes object (generates `runtime.Object`). |
| `+kubebuilder:subresource:status` | Carve `/status` into its own subresource (spec/status write isolation). **Always set this.** |
| `+kubebuilder:subresource:scale:specpath=...,statuspath=...` | Enable `kubectl scale` + HPA on the CR. |
| `+kubebuilder:validation:Minimum/Maximum/MinLength/MaxLength/Pattern` | OpenAPI numeric/string validation. |
| `+kubebuilder:validation:Enum=A;B;C` | Restrict to an enumerated set. |
| `+kubebuilder:default:=<value>` | Server-side default applied at admission (requires structural schema). |
| `+required` / `+optional` | Field requiredness (current spellings; older code used `+kubebuilder:validation:Required/Optional`). |
| `+listType=map` + `+listMapKey=type` | Treat the slice as an associative list keyed by `type` — **required for `conditions`** so server-side apply merges by key, not by index. |
| `+listType=atomic` / `+listType=set` | Replace-whole-list / unique-scalar-set semantics. |
| `+kubebuilder:printcolumn:name=...,type=...,JSONPath=...` | Extra `kubectl get` columns. |
| `+kubebuilder:resource:shortName=...,scope=Cluster\|Namespaced,categories=...` | Resource-level CRD options. |
| `+kubebuilder:validation:XValidation:rule="...",message="..."` | **CEL** cross-field / invariant validation (see 2.5). |
| `+kubebuilder:storageversion` | Mark the storage version in a multi-version CRD (see 2.6). |

### 2.4 Status conditions — the standard pattern

Use `metav1.Condition` and the `apimachinery/pkg/api/meta` helpers. **`Type`,
`Status`, `Reason`, `Message`, and `LastTransitionTime` are required** (`Reason`
must be a non-empty CamelCase token); only `ObservedGeneration` is optional.

Standard condition types: **`Available`** (operand serving), **`Progressing`**
(actively converging), **`Degraded`** (something is wrong). The controller sets
them; never invent ad-hoc free-text status strings the user must parse.

```go
import "k8s.io/apimachinery/pkg/api/meta"

meta.SetStatusCondition(&memcached.Status.Conditions, metav1.Condition{
	Type:               "Available",
	Status:             metav1.ConditionTrue,
	Reason:             "Reconciled",          // machine-readable, CamelCase, required
	Message:            "Deployment has the desired number of ready replicas",
	ObservedGeneration: memcached.Generation,  // ties this condition to the spec gen it reflects
	// LastTransitionTime: leave zero — SetStatusCondition stamps it only on a Status change.
})
```

`meta` helpers (exact signatures):

```go
func SetStatusCondition(conditions *[]metav1.Condition, newCondition metav1.Condition) (changed bool)
func RemoveStatusCondition(conditions *[]metav1.Condition, conditionType string) (removed bool)
func FindStatusCondition(conditions []metav1.Condition, conditionType string) *metav1.Condition
func IsStatusConditionTrue(conditions []metav1.Condition, conditionType string) bool
func IsStatusConditionFalse(conditions []metav1.Condition, conditionType string) bool
func IsStatusConditionPresentAndEqual(conditions []metav1.Condition, conditionType string, status metav1.ConditionStatus) bool
```

### 2.5 Validation: push it to admission, not the reconciler

Catch bad specs **at the API boundary** so invalid CRs are rejected before they
ever reach your loop. Order of preference:

1. **OpenAPI markers** (2.3) for field-level shape, ranges, enums, patterns.
2. **CEL `XValidation`** for cross-field invariants — evaluated by the API server,
   no webhook needed:

```go
// +kubebuilder:validation:XValidation:rule="self.maxSize >= self.size",message="maxSize must be >= size"
type MemcachedSpec struct {
	// +kubebuilder:validation:Minimum=1
	Size int32 `json:"size"`
	// +kubebuilder:validation:Minimum=1
	MaxSize int32 `json:"maxSize"`
}
```

3. **Admission webhooks** (Phase 4) only for logic CEL can't express (e.g. cross-
   object lookups). Defaulting via markers/CEL is cheaper than a mutating webhook.

> **Never store secrets in `spec`.** Reference a `Secret` by name and read it in
> the reconciler. Spec is world-readable to anyone with `get` on the CR.

### 2.6 Versioning and conversion (Habit #5)

Resources you ship outlive their schema. To evolve safely:

- Serve multiple versions; mark exactly one `+kubebuilder:storageversion`.
- Per CRD version set `served: true/false` and `deprecated: true` as you sunset.
- For breaking schema changes, scaffold a **conversion webhook**
  (`kubebuilder create webhook --conversion`) and implement `Hub`/`Convertible`
  so old stored objects convert to the hub version on read.
- **Never add a required `spec` field to an existing version** — it breaks every
  already-stored CR. Add optional + defaulted, or bump the version.

### 2.7 Generate after every type change

```bash
make generate    # zz_generated.deepcopy.go   (controller-gen object)
make manifests   # config/crd/bases/*.yaml    (controller-gen crd) + RBAC + webhooks
```

---

## PHASE 3 — THE CONTROLLER / RECONCILER (`internal/controller/`)

### 3.1 Reconciler type and the canonical loop

```go
type MemcachedReconciler struct {
	client.Client                      // embedded: r.Get/List/Create/Update/Delete/Status()
	Scheme   *runtime.Scheme
	Recorder record.EventRecorder      // for Kubernetes Events
}

const memcachedFinalizer = "cache.example.com/finalizer"

// RBAC markers live on the reconciler — controller-gen turns them into config/rbac/role.yaml.
// +kubebuilder:rbac:groups=cache.example.com,resources=memcacheds,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=cache.example.com,resources=memcacheds/status,verbs=get;update;patch
// +kubebuilder:rbac:groups=cache.example.com,resources=memcacheds/finalizers,verbs=update
// +kubebuilder:rbac:groups=apps,resources=deployments,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups="",resources=events,verbs=create;patch

func (r *MemcachedReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	log := logf.FromContext(ctx)

	// 1. FETCH the primary resource. NotFound => it was deleted; nothing to do.
	var mc cachev1alpha1.Memcached
	if err := r.Get(ctx, req.NamespacedName, &mc); err != nil {
		return ctrl.Result{}, client.IgnoreNotFound(err)
	}

	// 2. HANDLE DELETION via finalizer (only if external cleanup is required).
	if !mc.DeletionTimestamp.IsZero() {
		if controllerutil.ContainsFinalizer(&mc, memcachedFinalizer) {
			if err := r.finalize(ctx, &mc); err != nil {
				return ctrl.Result{}, err // requeue; do NOT remove the finalizer yet
			}
			controllerutil.RemoveFinalizer(&mc, memcachedFinalizer)
			if err := r.Update(ctx, &mc); err != nil {
				return ctrl.Result{}, err
			}
		}
		return ctrl.Result{}, nil
	}

	// 3. ENSURE the finalizer is present before we create external state.
	if controllerutil.AddFinalizer(&mc, memcachedFinalizer) {
		if err := r.Update(ctx, &mc); err != nil {
			return ctrl.Result{}, err
		}
	}

	// 4. CONVERGE: declaratively reconcile child resources (idempotent).
	if err := r.reconcileDeployment(ctx, &mc); err != nil {
		meta.SetStatusCondition(&mc.Status.Conditions, metav1.Condition{
			Type: "Available", Status: metav1.ConditionFalse,
			Reason: "DeploymentFailed", Message: err.Error(),
			ObservedGeneration: mc.Generation,
		})
		_ = r.Status().Update(ctx, &mc)
		return ctrl.Result{}, err
	}

	// 5. REPORT observed state via status conditions + observedGeneration.
	meta.SetStatusCondition(&mc.Status.Conditions, metav1.Condition{
		Type: "Available", Status: metav1.ConditionTrue,
		Reason: "Reconciled", Message: "operand is converged",
		ObservedGeneration: mc.Generation,
	})
	mc.Status.ObservedGeneration = mc.Generation
	if err := r.Status().Update(ctx, &mc); err != nil {
		return ctrl.Result{}, err
	}

	log.Info("reconciled", "name", mc.Name)
	return ctrl.Result{}, nil
}
```

### 3.2 Return / requeue strategy

| Return | Meaning |
|--------|---------|
| `ctrl.Result{}, nil` | Converged. Don't requeue (the watch will re-trigger on the next change). |
| `ctrl.Result{}, err` | Failed. The workqueue **automatically** requeues with exponential backoff. Prefer this over `Requeue: true` for errors. |
| `ctrl.Result{RequeueAfter: d}, nil` | Time-based re-check (poll operand health, cert rotation, "DB not ready yet, look again in 30s"). |

- **Never sleep/poll inside `Reconcile`** waiting for an operand to become ready —
  return and requeue, re-check on the next pass. A blocked reconcile starves the
  whole controller's workqueue.
- Avoid `ctrl.Result{Requeue: true}, nil` hot-loops; if you have nothing new to
  do, return clean and let watches drive you.

### 3.3 Idempotent child resources — `CreateOrUpdate` + owner refs

```go
func (r *MemcachedReconciler) reconcileDeployment(ctx context.Context, mc *cachev1alpha1.Memcached) error {
	dep := &appsv1.Deployment{
		ObjectMeta: metav1.ObjectMeta{Name: mc.Name, Namespace: mc.Namespace},
	}

	// CreateOrUpdate GETs, runs the mutate fn, then CREATEs or UPDATEs as needed —
	// idempotent by construction. Set ONLY the fields you own inside the mutate fn.
	op, err := controllerutil.CreateOrUpdate(ctx, r.Client, dep, func() error {
		dep.Spec.Replicas = &mc.Spec.Size
		dep.Spec.Selector = &metav1.LabelSelector{MatchLabels: labelsFor(mc)}
		dep.Spec.Template.ObjectMeta.Labels = labelsFor(mc)
		dep.Spec.Template.Spec.Containers = []corev1.Container{{
			Name:  "memcached",
			Image: mc.Spec.Image,
			Ports: []corev1.ContainerPort{{ContainerPort: mc.Spec.ContainerPort}},
		}}
		// THE most important line: stamp the owner reference so GC deletes the
		// Deployment when the Memcached CR is deleted, and our Owns() watch fires.
		return controllerutil.SetControllerReference(mc, dep, r.Scheme)
	})
	if err != nil {
		return err
	}
	if op != controllerutil.OperationResultNone {
		r.Recorder.Eventf(mc, corev1.EventTypeNormal, "DeploymentReconciled",
			"Deployment %s/%s %s", dep.Namespace, dep.Name, op)
	}
	return nil
}
```

`controllerutil` signatures you rely on (verbatim):

```go
func CreateOrUpdate(ctx context.Context, c client.Client, obj client.Object, f MutateFn) (OperationResult, error)
func CreateOrPatch(ctx context.Context, c client.Client, obj client.Object, f MutateFn) (OperationResult, error)
func SetControllerReference(owner, controlled metav1.Object, scheme *runtime.Scheme, opts ...OwnerReferenceOption) error
func SetOwnerReference(owner, object metav1.Object, scheme *runtime.Scheme, opts ...OwnerReferenceOption) error
func AddFinalizer(o client.Object, finalizer string) (finalizersUpdated bool)
func RemoveFinalizer(o client.Object, finalizer string) (finalizersUpdated bool)
func ContainsFinalizer(o client.Object, finalizer string) bool
// OperationResult: "unchanged" | "created" | "updated"
```

### 3.4 Child resource naming & deletion

- **Naming must be deterministic** so the next reconcile finds the same child
  (e.g. derive from the CR name; for generated suffixes use `rand.String(5)` and
  **persist the chosen name in status** so it's stable across reconciles).
- **Deletion of in-cluster children is free**: with `SetControllerReference`,
  Kubernetes GC deletes them when the owner is deleted. Don't write delete logic
  for owned children — only for *external* state, via the finalizer (`r.finalize`).

### 3.5 Wiring watches — `SetupWithManager`

```go
func (r *MemcachedReconciler) SetupWithManager(mgr ctrl.Manager) error {
	return ctrl.NewControllerManagedBy(mgr).
		For(&cachev1alpha1.Memcached{}).            // primary resource
		Owns(&appsv1.Deployment{}).                 // owned children: changes requeue the owner
		WithEventFilter(predicate.GenerationChangedPredicate{}). // skip pure status/heartbeat churn
		Named("memcached").
		Complete(r)
}
```

- `For(...)` — the primary type. `Owns(...)` — child types you set an owner ref
  on; an event on a child enqueues its owner (scoped by owner ref, so you don't
  reconcile *every* Deployment in the cluster).
- `Watches(...)` with a custom `handler.EnqueueRequestsFromMapFunc` — for related
  objects you don't own (e.g. a referenced `Secret`) mapped back to affected CRs.
- **Predicates** (`GenerationChangedPredicate`, `LabelChangedPredicate`) are an
  **optimization** to cut needless reconciles — correctness must still hold
  without them (Principle 1).

### 3.6 Errors, conflicts, and the API-errors helpers

```go
import apierrors "k8s.io/apimachinery/pkg/api/errors"

if err := r.Get(ctx, key, obj); err != nil {
	return ctrl.Result{}, client.IgnoreNotFound(err) // nil if NotFound, else the error
}
// On status/spec update races:
if apierrors.IsConflict(err) {
	return ctrl.Result{Requeue: true}, nil // re-fetch and retry on the next pass
}
```

Useful: `IsNotFound`, `IsConflict`, `IsAlreadyExists`, `IsInvalid`,
`IsForbidden` — all wrapped-error aware, all `false` for `nil`. `client.IgnoreNotFound`
is the idiomatic guard at the top of every reconcile.

---

## PHASE 4 — ADMISSION WEBHOOKS

Admission webhooks run **inside the API request path**, after authn/authz:
**mutating** webhooks first (they return a JSONPatch), then built-in schema
validation, then **validating** webhooks (they see the final, post-mutation
object and answer allow/deny). Reach for them only when markers + CEL can't
express the rule.

controller-runtime/kubebuilder give you **typed interfaces** — you don't touch
`AdmissionReview` wire format. Implement them on a separate webhook type:

```go
// +kubebuilder:webhook:path=/mutate-cache-example-com-v1alpha1-memcached,mutating=true,failurePolicy=fail,sideEffects=None,groups=cache.example.com,resources=memcacheds,verbs=create;update,versions=v1alpha1,name=mmemcached.kb.io,admissionReviewVersions=v1
// +kubebuilder:webhook:path=/validate-cache-example-com-v1alpha1-memcached,mutating=false,failurePolicy=fail,sideEffects=None,groups=cache.example.com,resources=memcacheds,verbs=create;update,versions=v1alpha1,name=vmemcached.kb.io,admissionReviewVersions=v1

type MemcachedCustomDefaulter struct{}

func (d *MemcachedCustomDefaulter) Default(ctx context.Context, obj runtime.Object) error {
	mc := obj.(*cachev1alpha1.Memcached)
	if mc.Spec.Size == 0 {
		mc.Spec.Size = 1
	}
	return nil
}

type MemcachedCustomValidator struct{}

func (v *MemcachedCustomValidator) ValidateCreate(ctx context.Context, obj runtime.Object) (admission.Warnings, error) {
	return v.validate(obj)
}
func (v *MemcachedCustomValidator) ValidateUpdate(ctx context.Context, oldObj, newObj runtime.Object) (admission.Warnings, error) {
	return v.validate(newObj)
}
func (v *MemcachedCustomValidator) ValidateDelete(ctx context.Context, obj runtime.Object) (admission.Warnings, error) {
	return nil, nil
}
func (v *MemcachedCustomValidator) validate(obj runtime.Object) (admission.Warnings, error) {
	mc := obj.(*cachev1alpha1.Memcached)
	if mc.Spec.Image == "" {
		return nil, fmt.Errorf("spec.image is required")
	}
	return nil, nil
}
```

Wire-up (in the webhook's `SetupWebhookWithManager`):

```go
func SetupMemcachedWebhookWithManager(mgr ctrl.Manager) error {
	return ctrl.NewWebhookManagedBy(mgr).For(&cachev1alpha1.Memcached{}).
		WithDefaulter(&MemcachedCustomDefaulter{}).
		WithValidator(&MemcachedCustomValidator{}).
		Complete()
}
```

- Returning a non-nil `error` from a `Validate*` → request **denied** with that
  message; returned `admission.Warnings` surface to the user without blocking.
- `failurePolicy=Fail` (safe default) vs `Ignore`; `sideEffects=None` is required
  unless your webhook mutates external state. Set a tight `timeoutSeconds`.
- Webhooks need **TLS serving certs** — wire **cert-manager** via the
  `config/certmanager/` + `config/webhook/` Kustomize overlays the scaffolder
  creates. Never ship a webhook without a cert source.

> **Released-vs-emerging note:** the current released controller-runtime exposes
> `CustomValidator`/`CustomDefaulter` with `runtime.Object` params (shown above)
> and `WithValidator`/`WithDefaulter` — this is what kubebuilder scaffolds. Newer
> tip may introduce generic `Validator[T any]` forms; prefer what your pinned
> `sigs.k8s.io/controller-runtime` version in `go.mod` actually exports.

---

## PHASE 5 — THE MANAGER / ENTRYPOINT (`cmd/main.go`)

The **manager** owns the shared cache, clients, leader election, metrics server,
health probes, and runs all controllers + webhooks.

```go
var (
	scheme   = runtime.NewScheme()
	setupLog = ctrl.Log.WithName("setup")
)

func init() {
	utilruntime.Must(clientgoscheme.AddToScheme(scheme))  // built-in types
	utilruntime.Must(cachev1alpha1.AddToScheme(scheme))   // our CRD types
}

func main() {
	var metricsAddr, probeAddr string
	var enableLeaderElection bool
	flag.StringVar(&metricsAddr, "metrics-bind-address", ":8443", "metrics endpoint")
	flag.StringVar(&probeAddr, "health-probe-bind-address", ":8081", "health probe endpoint")
	flag.BoolVar(&enableLeaderElection, "leader-elect", false, "enable leader election for HA")

	opts := zap.Options{Development: true}
	opts.BindFlags(flag.CommandLine)
	flag.Parse()
	ctrl.SetLogger(zap.New(zap.UseFlagOptions(&opts))) // structured logging via controller-runtime/log/zap

	mgr, err := ctrl.NewManager(ctrl.GetConfigOrDie(), ctrl.Options{
		Scheme:                 scheme,
		Metrics:                metricsserver.Options{BindAddress: metricsAddr}, // go/v4: struct, not MetricsBindAddress
		HealthProbeBindAddress: probeAddr,
		LeaderElection:         enableLeaderElection,
		LeaderElectionID:       "memcached-operator.example.com",
	})
	if err != nil {
		setupLog.Error(err, "unable to start manager")
		os.Exit(1)
	}

	if err = (&controller.MemcachedReconciler{
		Client:   mgr.GetClient(),
		Scheme:   mgr.GetScheme(),
		Recorder: mgr.GetEventRecorderFor("memcached-controller"),
	}).SetupWithManager(mgr); err != nil {
		setupLog.Error(err, "unable to create controller", "controller", "Memcached")
		os.Exit(1)
	}
	// if webhooks: controller.SetupMemcachedWebhookWithManager(mgr)

	_ = mgr.AddHealthzCheck("healthz", healthz.Ping)
	_ = mgr.AddReadyzCheck("readyz", healthz.Ping)

	setupLog.Info("starting manager")
	if err := mgr.Start(ctrl.SetupSignalHandler()); err != nil { // graceful shutdown on SIGTERM
		setupLog.Error(err, "problem running manager")
		os.Exit(1)
	}
}
```

- **Register every API group's `AddToScheme`** in `init()` — both built-in and
  your CRDs — or the cache/clients can't (de)serialize them.
- **Leader election** (`LeaderElectionID` unique per operator) ensures only one
  replica reconciles in an HA Deployment.
- `ctrl.SetupSignalHandler()` gives you graceful shutdown; the manager drains on
  `SIGTERM`.

---

## PHASE 6 — OBSERVABILITY (Capability Level IV)

### 6.1 Prometheus metrics — register into the controller-runtime registry

The manager already serves `/metrics`. Register **custom** metrics into
`sigs.k8s.io/controller-runtime/pkg/metrics`.`Registry` (NOT the global
`prometheus.DefaultRegisterer`, which the manager does not serve):

```go
import (
	"github.com/prometheus/client_golang/prometheus"
	"sigs.k8s.io/controller-runtime/pkg/metrics"
)

var reconcileTotal = prometheus.NewCounterVec(
	prometheus.CounterOpts{
		Name: "memcached_reconcile_total",
		Help: "Total reconciles by result.",
	},
	[]string{"result"},
)

func init() {
	metrics.Registry.MustRegister(reconcileTotal) // wired to the manager's /metrics endpoint
}
// usage: reconcileTotal.WithLabelValues("success").Inc()
```

controller-runtime already exports per-controller reconcile counts, latency
histograms, and workqueue depth for free — your custom metrics should cover
**operand** health (golden signals), not re-implement these.

### 6.2 Events — narrate state transitions

Use the `record.EventRecorder` (from `mgr.GetEventRecorderFor`) for significant,
user-visible transitions (provisioned, upgrade started/finished, backup done,
failures). They show in `kubectl describe` and correlate with external monitoring.

```go
r.Recorder.Eventf(mc, corev1.EventTypeWarning, "ReconcileError", "failed: %v", err)
```

### 6.3 Conditions + structured logging
`status.conditions` are the **primary** user-facing health signal (Phase 2.4).
Logs are for operators of the operator: use `logf.FromContext(ctx)` (structured,
leveled via the zap flags) — log decisions and error context, never secrets.

---

## PHASE 7 — RBAC & SECURITY (Principle 8)

### 7.1 Generate least-privilege RBAC from markers
Put `+kubebuilder:rbac` markers next to the code that actually needs the access
(Phase 3.1); `make manifests` (`controller-gen rbac:roleName=manager-role`)
compiles them into `config/rbac/role.yaml`. **Request only the verbs you use.**

- Status subresource needs its own grant:
  `resources=<plural>/status,verbs=get;update;patch`.
- Finalizer updates need: `resources=<plural>/finalizers,verbs=update`.
- Prefer **namespaced `Role`** over `ClusterRole`. Use `ClusterRole` only for
  genuinely cluster-scoped resources (CRDs, nodes, namespaces).
- Run the operand's pods under a **separate, documented ServiceAccount** from the
  manager — don't reuse the manager's identity for workloads it creates.

### 7.2 Harden the manager pod
```yaml
securityContext:                 # pod
  runAsNonRoot: true
  seccompProfile: { type: RuntimeDefault }
containers:
- name: manager
  securityContext:
    allowPrivilegeEscalation: false
    readOnlyRootFilesystem: true
    capabilities: { drop: ["ALL"] }
```
- Set resource `requests`/`limits` on the manager (and on operand pods you create).
- Protect the metrics endpoint (TLS / auth — kubebuilder go/v4 serves metrics on
  `:8443` with authn/authz by default) and the webhook endpoint (cert-manager TLS).
- **Scope the manager to namespaces** via cache options when the operator is not
  cluster-wide; never hardcode the operator's own namespace into reconcile logic.

---

## PHASE 8 — TESTING (Habit #7)

### 8.1 envtest + Ginkgo/Gomega (controller integration tests)
`make test` runs against **envtest**: a real `kube-apiserver` + `etcd` (no kubelet,
no scheduler) so your CRDs install and your reconciler runs against a true API,
without a full cluster.

```go
var _ = Describe("Memcached controller", func() {
	It("creates a Deployment with the requested size", func() {
		ctx := context.Background()
		mc := &cachev1alpha1.Memcached{
			ObjectMeta: metav1.ObjectMeta{Name: "sample", Namespace: "default"},
			Spec:       cachev1alpha1.MemcachedSpec{Image: "memcached:1.6", Size: 3},
		}
		Expect(k8sClient.Create(ctx, mc)).To(Succeed())

		// Reconcile is async: assert with Eventually, never a bare Get.
		dep := &appsv1.Deployment{}
		Eventually(func() error {
			return k8sClient.Get(ctx, types.NamespacedName{Name: "sample", Namespace: "default"}, dep)
		}, time.Second*10, time.Millisecond*250).Should(Succeed())
		Expect(*dep.Spec.Replicas).To(Equal(int32(3)))
	})
})
```

- Reconciliation is asynchronous — always assert with **`Eventually`/`Consistently`**,
  not a single `Get`. Idempotency tests: reconcile twice, assert no second child
  and identical state.
- Pure functions (`labelsFor`, desired-Deployment builders) get fast **table-driven
  unit tests** — no envtest needed.
- **Chaos mindset:** in e2e, delete the operand Deployment / a pod and assert the
  operator reconverges; delete the CR and assert finalizer cleanup + GC of children.

---

## PHASE 9 — OLM PACKAGING & DISTRIBUTION

OLM (Operator Lifecycle Manager) installs, upgrades, and manages operators
declaratively. **Bundles and catalogs are the same substrate for OLM v0 and v1** —
author them once.

### 9.1 The bundle (one operator version, unpacked)
```text
bundle/
├── manifests/
│   ├── <operator>.clusterserviceversion.yaml   # the CSV
│   └── <group>_<plural>.crd.yaml               # one per owned CRD
├── metadata/
│   └── annotations.yaml
└── bundle.Dockerfile                            # FROM scratch; just carries the files
```
Generate it (Operator SDK), don't hand-write it:
```bash
make bundle IMG=<reg>/memcached-operator:v0.1.0 \
  VERSION=0.1.0 CHANNELS=stable DEFAULT_CHANNEL=stable
# => operator-sdk generate kustomize manifests + generate bundle + bundle validate
make bundle-build bundle-push BUNDLE_IMG=<reg>/memcached-operator-bundle:v0.1.0
```

`metadata/annotations.yaml` (must match the `LABEL`s in `bundle.Dockerfile`):
```yaml
annotations:
  operators.operatorframework.io.bundle.mediatype.v1: registry+v1
  operators.operatorframework.io.bundle.manifests.v1: manifests/
  operators.operatorframework.io.bundle.metadata.v1: metadata/
  operators.operatorframework.io.bundle.package.v1: memcached-operator
  operators.operatorframework.io.bundle.channels.v1: stable
  operators.operatorframework.io.bundle.channel.default.v1: stable
```

### 9.2 The ClusterServiceVersion (CSV)
The CSV is the operator's installable manifest. It carries:
- **Install strategy** — `spec.install.spec.deployments[]` (the manager
  Deployment), `permissions[]` (namespaced RBAC), `clusterPermissions[]`.
- **API ownership** — `spec.customresourcedefinitions.owned[]` (your CRDs) and
  `.required[]` (CRDs from operators you depend on).
- **Install modes** — `spec.installModes[]`: `{type, supported}` for
  `OwnNamespace` / `SingleNamespace` / `MultiNamespace` / `AllNamespaces`.
- **`alm-examples`** annotation — JSON array of sample CRs for the UI.
- **Upgrade graph** — `spec.replaces` / `spec.skips` / skipRange; `minKubeVersion`;
  the `capabilities` annotation (declare your maturity level, Level I–V).

Edit the **source** under `config/manifests/bases/`, then regenerate — never the
bundle output directly.

### 9.3 Catalogs — `opm` + File-Based Catalogs (FBC)
A catalog is an image serving bundle pointers over gRPC, referenced by a
`CatalogSource`. **FBC (plaintext JSON/YAML) is the current default**; the old
**sqlite** index path (`opm index add`) is **deprecated** — do not use it.

```bash
opm init memcached-operator --default-channel=stable \
  --output yaml > catalog/index.yaml          # olm.package blob
# append olm.channel + olm.bundle entries (or `opm render <bundle-image>`):
opm render <reg>/memcached-operator-bundle:v0.1.0 --output yaml >> catalog/index.yaml
opm validate catalog/                          # exit 0 = valid
opm generate dockerfile catalog/               # build the catalog image from this
```
FBC schemas: `olm.package` (one per package: name, defaultChannel), `olm.channel`
(upgrade edges: `entries[]` with `replaces`/`skips`/`skipRange`), `olm.bundle`
(image ref + `properties`: provided/required GVKs + package + deps).

### 9.4 Dependency resolution
Declare deps in the bundle's `metadata/` (`dependencies.yaml` /`properties.yaml`):
- **`olm.gvk`** — depend on whatever operator *provides* a `{group, kind, version}`.
- **`olm.package`** — `{packageName, version}` where version is a **SemVer 2.0
  range** (e.g. `">=1.2.0 <2.0.0"`).
- **`olm.constraint`** — generic constraints over properties.

OLM compiles provided/required properties into a boolean formula solved by a
**SAT solver** to choose the install set; a package's `defaultChannel` is
preferred, other channels evaluated lexicographically, newest-in-graph within a
channel.

### 9.5 Installing — OLM v0 vs OLM v1
**OLM v0** (mature, default on most clusters incl. OpenShift today):
```text
OperatorGroup (scope: which namespaces the operator watches)
  └── Subscription (package + channel + Automatic/Manual approval, from a CatalogSource)
        └── InstallPlan (resolves deps, executes) → ClusterServiceVersion (running version)
```
`OperatorGroup` install modes must be a `supported: true` mode in the CSV
(`AllNamespaces` = empty `targetNamespaces`, cluster-wide).

**OLM v1** (operator-controller + catalogd — emerging, GitOps/least-privilege
first): `ClusterCatalog` (cluster-scoped catalog) + `ClusterExtension`
(declarative install with a per-install `serviceAccount` — no admin escalation).
It currently supports a **subset** of v0 content and has **no automatic v0→v1
migration**. **Recommendation:** author registry+v1 bundles + FBC catalogs (shared
by both); install via **OLM v0** for production today, adopt **OLM v1** where it's
available and GitOps/least-privilege installs matter. Confirm exact
`ClusterExtension` spec fields against the live `olm.operatorframework.io/v1` API
for your target cluster version before codifying.

---

## ANTI-PATTERNS (each one fails review)

| Anti-pattern | Why it breaks | Do instead |
|--------------|---------------|------------|
| Edge-triggered logic ("this is a Create event") | Events drop/dup/reorder; you'll diverge | Level-based: re-derive desired state every loop (Principle 1) |
| Blind `Create` for children | Errors `AlreadyExists` on 2nd reconcile → not idempotent | `CreateOrUpdate`/`CreateOrPatch` keyed on a stable name (3.3) |
| `time.Sleep` / poll loop inside `Reconcile` | Starves the workqueue; one slow CR blocks all | Return + `RequeueAfter`; re-check next pass (3.2) |
| Writing `status` into `spec` / no status subresource | Spec/status update races; clobbers user edits | `+kubebuilder:subresource:status`; `r.Status().Update` (2.2) |
| Free-text status strings | Users/tools can't act on them | `metav1.Condition` (Available/Progressing/Degraded) (2.4) |
| No `observedGeneration` | Users can't tell if status is current | Stamp `mc.Generation` on status + each condition (2.4) |
| Owner ref missing on children | No GC; leaked resources; `Owns()` watch won't fire | `SetControllerReference` in the mutate fn (3.3) |
| Finalizer for purely in-cluster children | Needless; blocks deletion | Owner refs + GC; finalizers only for external state (Principle 7) |
| Remove finalizer before cleanup done | Leaks the external resource | Cleanup first, then `RemoveFinalizer` (3.1) |
| Adding a required `spec` field to a shipped version | Breaks every stored CR | Optional + default, or bump the API version (2.6) |
| Secrets inlined in `spec` | World-readable to `get` on the CR | Reference a `Secret` by name; read in reconciler (2.5) |
| Broad/wildcard RBAC, `cluster-admin`, root | Blast radius; fails security review | `+kubebuilder:rbac` least privilege; non-root pod (Phase 7) |
| Hand-editing `zz_generated.*` / generated CRD/RBAC | Lost on next `make generate` | Edit source markers, regenerate (1.4) |
| One monolith operator/CRD for many apps | Large blast radius, tangled loops | One operator per app; one CRD per controller |
| Operator installs another operator at runtime | Fragile ordering, privilege creep | Declare deps via OLM (9.4) |
| Operator in the data path | Operator downtime = operand downtime | Operator only converges; operand runs independently (Principle 6) |
| Swallowing reconcile errors / log-only failures | User never sees the problem | Surface via conditions + Events, return the error (6.2) |
| Bare `Get` in tests | Reconcile is async → flaky | `Eventually`/`Consistently` (8.1) |
| sqlite catalog index (`opm index add`) | Deprecated | File-Based Catalogs via `opm render`/`init` (9.3) |

---

## PRE-DONE VERIFICATION CHECKLIST

Before declaring an operator task complete, every box must check:

**Generate & build**
- [ ] `make generate` + `make manifests` run; `zz_generated.*`, `config/crd/bases/*`, `config/rbac/role.yaml` are current and committed.
- [ ] `go build ./...` and `make test` (unit + envtest) pass.

**API (CRD)**
- [ ] Status subresource enabled; `spec` has validation (markers / CEL); sensible defaults; no required-field churn on shipped versions.
- [ ] `conditions` is `+listType=map`/`+listMapKey=type`; `observedGeneration` present; printer columns added.
- [ ] No secrets in `spec`.

**Reconciler**
- [ ] Level-based + idempotent (reconcile twice → no duplicate children, identical state).
- [ ] `client.IgnoreNotFound` guard; children via `CreateOrUpdate` with `SetControllerReference`.
- [ ] Finalizer present-before-act and removed only after external cleanup (if external state exists).
- [ ] Conditions + `observedGeneration` set on every exit path; errors returned (not swallowed) and surfaced as Events.
- [ ] Requeue strategy correct (errors auto-backoff; `RequeueAfter` for polling; no sleeps).
- [ ] `SetupWithManager` wires `For`/`Owns`/`Watches`; predicates are optimizations only.

**Security & ops**
- [ ] RBAC is least-privilege from markers (incl. `/status`, `/finalizers`); namespaced where possible; no `cluster-admin`.
- [ ] Manager runs non-root, read-only FS, dropped caps; resource limits set; leader election for HA.
- [ ] Webhooks (if any) have a cert source (cert-manager); `sideEffects`/`failurePolicy` set.

**Packaging (if shipping via OLM)**
- [ ] Bundle generated (`make bundle`); `operator-sdk bundle validate` passes; CSV install modes + owned/required CRDs + capability level correct.
- [ ] Catalog is File-Based (`opm validate` passes); deps declared as `olm.gvk`/`olm.package` SemVer ranges.

---

## REFERENCE

### controller-gen
```bash
controller-gen object:headerFile="hack/boilerplate.go.txt" paths="./..."          # deepcopy (make generate)
controller-gen rbac:roleName=manager-role crd webhook paths="./..." \
  output:crd:artifacts:config=config/crd/bases                                     # manifests (make manifests)
```
Generators: `object` (deepcopy), `crd` (CRD YAML), `rbac:roleName=...` (ClusterRole),
`webhook` (webhook configs). Common opts: `paths=./...`, `output:<gen>:<rule>`.

### apimachinery utilities an operator reaches for
| Package | Use |
|---------|-----|
| `api/meta` | `SetStatusCondition` / `FindStatusCondition` / `IsStatusCondition*` |
| `api/errors` (`apierrors`) | `IsNotFound` / `IsConflict` / `IsAlreadyExists` / `IsInvalid` |
| `util/wait` | `PollUntilContextCancel` / `PollUntilContextTimeout` / `ExponentialBackoffWithContext` (context forms; the bare `Poll*` are deprecated) |
| `util/version` | `ParseSemantic` / `AtLeast` — gate behavior on server version |
| `util/rand` | `String(n)` — random, stable-if-persisted child name suffixes |
| `util/yaml` | `NewYAMLOrJSONDecoder` — read embedded multi-doc manifests |
| `util/json` | unmarshal arbitrary/unstructured JSON (numbers → int64/float64) |
| `component-base/cli` | `cli.Run(cmd)` — standard cobra entrypoint exit-code handling |

### Authoritative sources
kubebuilder book · Operator SDK docs · controller-runtime + controllerutil GoDoc ·
OLM docs (olm.operatorframework.io) + operator-registry · CNCF Operator WhitePaper
(capability levels) · O'Reilly *Kubernetes Operators* (Dobies & Wood) for philosophy.
**Pin every code example to the versions in your project's `go.mod`** — these APIs
move; when in doubt, check the GoDoc for your pinned `sigs.k8s.io/controller-runtime`.

---

## SUBAGENT ORCHESTRATION

When this repo's operator subagents are installed (`.claude/agents/`), delegate
phase work to the specialist and keep this skill as the shared contract. The
subagents are **repo-scoped** — installing only this `SKILL.md` elsewhere will not
bring them along.

| Phase | Subagent | Owns |
|-------|----------|------|
| 1 | `operator-scaffolder` | `kubebuilder`/`operator-sdk` init + create api/webhook, PROJECT, Makefile, project layout |
| 2 | `crd-api-designer` | `*_types.go`, markers, OpenAPI + CEL validation, conditions, versioning + conversion |
| 3 | `reconciler-author` | Reconcile loop, finalizers, `CreateOrUpdate`, owner refs, status, requeue, watches |
| 4–7 | `reconciler-author` | webhooks, manager wiring, metrics/events, RBAC markers (correctness-adjacent) |
| 8 | `operator-tester` | envtest + Ginkgo/Gomega suites, table tests, chaos/e2e |
| 9 | `olm-packager` | bundle, CSV, `annotations.yaml`, `opm` FBC catalogs, dependency resolution, OLM v0/v1 install |

Every subagent enforces the **CORE PRINCIPLES** above. When the work spans phases,
run scaffolder → designer → reconciler → tester → packager in order, regenerating
(`make generate manifests`) at each boundary that touches `*_types.go` or markers.
