---
name: kubernetes-operations
description: >-
  MUST USE when **operating / running** Kubernetes clusters and workloads
  (Day-2 / SRE) — triaging and fixing failing Pods, managing rollouts,
  right-sizing resources, scheduling and placement, autoscaling, node
  maintenance and cluster upgrades, RBAC and Pod-security hardening, networking
  and DNS debugging, storage/PVC operations, and observability. This is the
  **operate** skill, not a build skill. Use for — diagnosing
  `CrashLoopBackOff` / `ImagePullBackOff` / `ErrImagePull` /
  `CreateContainerConfigError` / `OOMKilled` (exit 137) / `Evicted` /
  `Pending`/`FailedScheduling`; `kubectl get|describe|logs --previous|events
  --sort-by|top|debug|rollout|drain|cordon|auth can-i`; Deployment rollout /
  rollback / `maxSurge` / `maxUnavailable` / `Recreate`, StatefulSet & DaemonSet
  & Job/CronJob ops; liveness/readiness/startup probe tuning and graceful
  shutdown (`terminationGracePeriodSeconds` / `preStop` / SIGTERM); requests vs
  limits, QoS classes (Guaranteed/Burstable/BestEffort) and eviction order,
  `LimitRange` / `ResourceQuota`; nodeAffinity / pod (anti)affinity / taints &
  tolerations / `topologySpreadConstraints` / `PriorityClass` & preemption;
  node-pressure vs API-initiated eviction; HPA (`autoscaling/v2`) / VPA /
  Cluster Autoscaler / Karpenter / KEDA and `metrics-server`;
  `PodDisruptionBudget`, `kubectl drain` and version-skew-aware cluster
  upgrades (kubeadm), deprecated-API migration (`kubectl convert`); RBAC
  (Role/ClusterRole/bindings, `auth can-i`, aggregated roles), ServiceAccount
  bound/projected tokens (`kubectl create token`), Pod Security Admission
  (privileged/baseline/restricted × enforce/audit/warn), `securityContext`
  hardening; Service types / headless / EndpointSlices / kube-proxy
  (iptables/IPVS/nftables) / CoreDNS `ndots:5` / `NetworkPolicy` default-deny /
  Ingress vs Gateway API; PV/PVC lifecycle, StorageClass, reclaim
  Retain/Delete, access modes RWO/ROX/RWX/RWOP, volume expansion, CSI; backup &
  disaster recovery (etcd snapshot/restore, CSI `VolumeSnapshot`, Velero); and the
  "service not reachable" / "PVC Pending" / "node NotReady" decision trees.
  Triggers on phrases — "kubectl", "pod crashing", "CrashLoopBackOff",
  "OOMKilled", "pod pending", "rollout stuck", "drain node", "node NotReady",
  "hpa not scaling", "pod can't be scheduled", "service not reachable", "PVC
  pending", "RBAC forbidden", "kubectl top", "cordon", "PodDisruptionBudget",
  "cluster upgrade", "version skew", "etcd backup", "volume snapshot", "velero",
  "disaster recovery". Triggers on file patterns — Pod/Deployment/
  StatefulSet/DaemonSet/Job manifests, `NetworkPolicy` / `PodDisruptionBudget` /
  `HorizontalPodAutoscaler` / `ResourceQuota` / `LimitRange` / RBAC YAML,
  kubeconfig files. This skill is for **running** clusters — to BUILD a custom
  controller use `kubernetes-operator-golang`; to build a control plane use
  `crossplane`; to consume platform building blocks use
  `addons-and-building-blocks`; for vendor-specific observability querying see
  `dynatrace` / `kusto-kql-api`. Authored as a Distinguished SRE's Day-2
  playbook — read Events before acting, declarative over imperative, least
  privilege, respect disruption budgets, observe before scaling.
license: BSD-3-Clause
compatibility: opencode
metadata:
  domain: operations
  pattern: day2-operations
  platform: kubernetes
  surfaces: workload-triage, rollouts, resources-qos, scheduling, autoscaling, disruptions-upgrades, rbac-podsecurity, networking, storage, backup-dr, observability
  use_cases: incident-response, capacity-management, cluster-maintenance, security-hardening
---

# Kubernetes Operations (Day-2 / SRE)

You are a Distinguished SRE **operating** Kubernetes — keeping running clusters
and workloads healthy, secure, scalable, and recoverable. This skill is about
**Day-2**: triage, rollouts, capacity, scheduling, scaling, maintenance,
upgrades, security, networking, and storage on clusters that already exist.

> **Scope boundary.** This is the *operate* skill.
> - **Build a custom controller / CRD** → `kubernetes-operator-golang`.
> - **Build a control plane (compose cloud infra)** → `crossplane`.
> - **Consume platform building blocks (Helm/ArgoCD addons)** → `addons-and-building-blocks`.
> - **Vendor observability query languages** → `dynatrace` (DQL), `kusto-kql-api` (KQL).
> For exact API field specs, cite **kubespec.dev**; for canonical behavior, **kubernetes.io**.

> **Version note.** Kubernetes moves fast. This skill states *behavior* (which is
> stable) and avoids pinning a single minor version. Where a feature's GA/beta
> status matters, it's flagged — but always confirm exact API versions and field
> availability against **your cluster's** `kubectl explain` / `kubectl
> api-resources` and **kubespec.dev**, not from memory.

---

## CORE PRINCIPLES (NON-NEGOTIABLE)

> Violating any of these is an automatic review failure.

1. **Read Events + `describe` before you act.** `kubectl describe` and `kubectl
   get events --sort-by=.lastTimestamp` reveal ~80% of incidents. Diagnose, then
   change. Never restart/delete/scale blindly.
2. **Declarative over imperative in production.** Desired state lives in
   version-controlled manifests (GitOps), not in `kubectl edit`/`patch` run by
   hand. Imperative commands are for *diagnosis* and *break-glass*, and must be
   reconciled back to Git.
3. **Never `kubectl delete` to "fix" stateful data.** Deleting a StatefulSet Pod,
   PVC, or PV can destroy data irrecoverably. Understand reclaim policy and
   `volumeClaimTemplates` lifecycle first.
4. **Every workload sets resource requests; set limits deliberately.** Requests
   drive scheduling and QoS; missing requests → BestEffort → first evicted.
   Memory limit exceeded → **OOMKilled**; CPU limit → **throttled** (not killed).
5. **Least privilege, always.** RBAC scoped to namespace + verbs actually needed;
   `restricted` Pod Security; drop all capabilities; `runAsNonRoot`. No
   cluster-admin for workloads, no long-lived ServiceAccount token secrets.
6. **Respect voluntary-disruption controls.** Use `PodDisruptionBudget` +
   `kubectl drain` (which honors PDBs) for maintenance. Never hard-delete Pods or
   power off nodes to "speed up" maintenance.
7. **Upgrades follow the version-skew policy and the component order.** apiserver
   first, then controllers/scheduler, then kubelet/kube-proxy. Drain nodes before
   upgrading kubelet. Migrate deprecated APIs *before* the version that removes
   them.
8. **Observe before scaling.** Scale on measured signals (`kubectl top`, HPA
   metrics), not hunches. `metrics-server` is a prerequisite for `kubectl top`
   and resource-based HPA.
9. **Cardinality & blast-radius discipline.** Default-deny NetworkPolicy where it
   matters; namespaces + quotas to bound tenants; PriorityClasses so critical
   workloads survive pressure.

---

## TRIAGE MAP (START HERE ON ANY INCIDENT)

The first commands, and what each tells you:

| Question | Command | Look for |
|---|---|---|
| What's the state? | `kubectl get pod -o wide` | phase, READY x/y, RESTARTS, node, IP |
| Why this state? | `kubectl describe pod <p>` | **Events** (bottom), container `state`/`lastState`, conditions |
| What did it log? | `kubectl logs <p> [-c <c>] --previous` | crash stack/panic; `--previous` = the instance that died |
| Cluster-wide signal? | `kubectl get events --sort-by=.lastTimestamp -A` | FailedScheduling, BackOff, FailedMount, Evicted |
| Resource pressure? | `kubectl top pod/node` | actual CPU/mem vs requests/limits (needs metrics-server) |
| Node healthy? | `kubectl describe node <n>` | conditions (MemoryPressure/DiskPressure), taints, allocatable |
| Can I do X? | `kubectl auth can-i <verb> <res> [--as <user>]` | RBAC permission check |

`-o wide`, `--previous`, and the Events section are the three highest-yield
moves. `kubectl describe` first; logs second.

---

## PHASE A — WORKLOAD TRIAGE (kubectl + Pod failures)

### A.1 kubectl essentials operators actually use

```bash
kubectl get pods -o wide                       # + node, IP
kubectl get pods -o jsonpath='{.items[*].metadata.name}'
kubectl get pods -o custom-columns='NAME:.metadata.name,PHASE:.status.phase,RESTARTS:.status.containerStatuses[0].restartCount'
kubectl get pods --sort-by=.status.containerStatuses[0].restartCount
kubectl logs <pod> -c <ctr> --previous --timestamps   # the crashed instance
kubectl exec -it <pod> -c <ctr> -- sh
kubectl cp <ns>/<pod>:/var/log/app.log ./app.log
kubectl port-forward svc/<svc> 8080:80         # reach a Service with no Ingress
kubectl explain pod.spec.containers.livenessProbe   # field docs, live
kubectl apply -f . --dry-run=server            # full admission, no persist
kubectl diff -f .                              # what apply would change
```

`kubectl debug` for when `exec` won't work (distroless image, crashed container):

```bash
kubectl debug -it <pod> --image=busybox --target=<ctr>   # ephemeral container, shares process ns
kubectl debug node/<node> -it --image=busybox            # debug a node (host mounts at /host)
```

### A.2 Pod phases & container states

- **Phase** (`.status.phase`): `Pending` (not scheduled or images pulling) ·
  `Running` (≥1 container up — **not** the same as Ready) · `Succeeded` ·
  `Failed` · `Unknown` (node unreachable).
- **Ready ≠ Running:** check `.status.conditions[type=Ready].status`. A Running
  Pod failing its readiness probe is pulled from Service endpoints.
- **Container state** (`.status.containerStatuses[].state`): `Waiting` (+ `reason`),
  `Running`, `Terminated` (+ `exitCode`, `reason`). The previous crash is in
  `.lastState.terminated`.
- **Exit codes:** `0` ok · `1–125` app error · **`137` = SIGKILL (OOMKilled / force-kill)** · `143` = SIGTERM (graceful).

### A.3 The Pod-failure decision tree

| Symptom (`reason`) | Most likely cause | Diagnose → fix |
|---|---|---|
| **CrashLoopBackOff** | App exits/panics on startup; bad config; failing liveness probe | `logs --previous` for the stack; `describe` Events; verify env/mounts/probe port. Fix app/config/probe — not the backoff. |
| **ImagePullBackOff / ErrImagePull** | Wrong image/tag; private registry without creds | `describe` Events show the exact pull error; verify tag exists + `imagePullSecrets`. |
| **CreateContainerConfigError** | Missing ConfigMap/Secret; bad volume/securityContext | `describe` names the missing object; `kubectl get secret/configmap`. |
| **OOMKilled (137)** | Memory limit too low or leak | `kubectl top pod` vs `limits.memory`; raise limit or fix leak. CPU is throttled, not OOMKilled. |
| **Evicted** | Node memory/disk pressure | `describe node` shows `MemoryPressure`/`DiskPressure`; right-size requests, add capacity, set PriorityClass. |
| **Pending / FailedScheduling** | No fitting node: insufficient resources, unmet affinity, untolerated taint, unbound PVC | `describe pod` Events give the precise reason → see Phase D / Phase I. |

### A.4 Probes — operational impact

- **liveness** fails → container **restarted**. **readiness** fails → Pod
  **removed from Service endpoints** (no restart). **startup** gates the other two
  for slow starters (avoids liveness killing a booting app).
- Handlers: `httpGet` (200–399 = pass), `tcpSocket`, `exec` (exit 0 = pass),
  `grpc`. Params: `initialDelaySeconds`, `periodSeconds`, `timeoutSeconds`,
  `failureThreshold`, `successThreshold`.
- **Top misconfigs:** `initialDelaySeconds` shorter than real startup → boot loop;
  liveness pointed at the wrong port → endless restarts; `timeoutSeconds: 1` on a
  slow endpoint → false failures; missing readiness probe → 5xx during rollouts.
  Prefer a **startupProbe** over a long `initialDelaySeconds`.

### A.5 Graceful shutdown

Termination order: Pod marked Terminating → removed from EndpointSlices **and**
`preStop` runs / SIGTERM sent → grace period (`terminationGracePeriodSeconds`,
default 30s) → SIGKILL. The app must trap SIGTERM, drain, and exit 0. For
load-balanced services add a short `preStop` sleep so in-flight requests drain
before the socket closes:

```yaml
lifecycle:
  preStop:
    exec: { command: ["/bin/sh", "-c", "sleep 15"] }
```

---

## PHASE B — WORKLOADS & ROLLOUTS

```bash
kubectl rollout status deployment/<d>          # blocks until done / fails
kubectl rollout history deployment/<d>         # revisions; --revision=N for detail
kubectl rollout undo deployment/<d> [--to-revision=N]
kubectl rollout restart deployment/<d>         # re-pull images / cycle pods
kubectl set image deployment/<d> <ctr>=<img>:<tag>
```

- **Only Pod-template changes trigger a rollout** — `kubectl scale` does not.
- **RollingUpdate** (default): `maxSurge` (extra Pods above desired) +
  `maxUnavailable` (Pods allowed down). `maxUnavailable: 0` + `maxSurge: 1` =
  zero-downtime, slower. **Recreate** = all old killed before new (downtime, but
  no two-version overlap — use for incompatible schema changes).
- `progressDeadlineSeconds` (default 600) → stuck rollout reports
  `ProgressDeadlineExceeded`. `minReadySeconds` keeps a Pod out of rotation until
  stably Ready. `revisionHistoryLimit` (default 10) bounds rollback history.
- **StatefulSet** ops differ: stable identity `<name>-<ordinal>`, needs a headless
  Service, ordered create/reverse-ordered delete (`podManagementPolicy:
  OrderedReady`), per-Pod PVCs from `volumeClaimTemplates` that are **not**
  auto-deleted. `updateStrategy.rollingUpdate.partition=N` enables canary.
- **DaemonSet**: one Pod per matching node (no replica count); `OnDelete` vs
  `RollingUpdate`. **Job/CronJob**: `backoffLimit`, `activeDeadlineSeconds`,
  `ttlSecondsAfterFinished`; only `restartPolicy: Never|OnFailure`.

---

## PHASE C — RESOURCES & QoS

- **requests** = scheduling + QoS basis (cgroup `cpu.shares`); **limits** = hard
  cap. **Memory over limit → OOMKilled (137).** **CPU over limit → throttled**
  (CFS quota), never killed — watch `container_cpu_cfs_throttled_periods_total`.
- **QoS classes** (drive eviction order):
  - **Guaranteed** — every container has `requests == limits` for CPU **and**
    memory. Evicted last.
  - **Burstable** — at least one request set, not all equal to limits. Middle.
  - **BestEffort** — nothing set. **Evicted first**; can't be admitted under a
    namespace `ResourceQuota` on cpu/memory.
- **`LimitRange`** (namespace): inject `default`/`defaultRequest`, enforce
  `min`/`max`, cap `maxLimitRequestRatio`. **`ResourceQuota`** (namespace): hard
  caps on `requests.cpu`, `limits.memory`, `pods`, `persistentvolumeclaims`,
  per-StorageClass storage, object counts — a 403 at admission when exceeded.
- **allocatable < capacity:** kubelet `--system-reserved` / `--kube-reserved`
  carve out node resources before scheduling.

---

## PHASE D — SCHEDULING & PLACEMENT

Evaluation order (high level): `nodeName` (bypass) → `nodeSelector` →
`nodeAffinity` → pod (anti)affinity → `topologySpreadConstraints` →
`priority`/preemption; `schedulingGates` block entry to the queue until removed.

- **nodeSelector** — simple `key=value` (ANDed). **nodeAffinity** —
  `requiredDuringSchedulingIgnoredDuringExecution` (hard; `nodeSelectorTerms`
  ORed, `matchExpressions` ANDed) vs `preferred…` (soft, `weight` 1–100).
  Operators `In/NotIn/Exists/DoesNotExist/Gt/Lt`.
- **pod (anti)affinity** — co-locate / spread relative to other Pods over a
  `topologyKey` (`kubernetes.io/hostname`, `topology.kubernetes.io/zone`). Required
  anti-affinity is a common scheduling-failure cause at scale.
- **Taints & tolerations** — taint `key=value:effect`, effects `NoSchedule` /
  `PreferNoSchedule` / `NoExecute` (evicts; `tolerationSeconds` delays). A Pod
  must tolerate **every** remaining taint to land/stay.
- **topologySpreadConstraints** — `maxSkew`, `topologyKey`, `whenUnsatisfiable:
  DoNotSchedule|ScheduleAnyway`, `labelSelector`. Spread replicas across zones/nodes.
- **PriorityClass** (`scheduling.k8s.io/v1`, integer `value`, one `globalDefault`)
  → preemption evicts lower-priority victims to fit a pending higher-priority Pod
  (`preemptionPolicy: Never` queues ahead without evicting).

**Eviction — two distinct mechanisms (don't conflate):**
- **Node-pressure (kubelet):** signals `memory.available`, `nodefs.available`,
  `imagefs.available`, `pid.available` vs `--eviction-hard`/`--eviction-soft`
  thresholds. Order: BestEffort → Burstable (by excess over request) → Guaranteed.
  **Ignores PDBs** (emergency). DaemonSet/static Pods need
  `system-node-critical` + tolerations to survive.
- **API-initiated (`/eviction` subresource, `policy/v1`):** what `kubectl drain`
  uses. **Honors PDBs** → returns **429** when a PDB would be violated.

---

## PHASE E — AUTOSCALING

> **Prerequisite:** `metrics-server` serves the resource Metrics API
> (`metrics.k8s.io`, **v1beta1**) consumed by `kubectl top` and resource-based
> HPA. No metrics-server → no `kubectl top`, no CPU/memory HPA.

- **HPA** — **`autoscaling/v2`** (v1 is legacy). `spec.metrics[]` types:
  `Resource` (cpu/mem `Utilization`|`AverageValue`), `Pods`, `Object`, `External`
  (queue depth etc.). Algorithm:
  `desired = ceil(current × currentValue / targetValue)`, within a ~10% tolerance.
  `behavior.scaleUp/scaleDown` with `stabilizationWindowSeconds` + `policies`
  (`Percent`/`Pods`, `selectPolicy`) damps flapping (default scale-down window
  300s).

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
spec:
  scaleTargetRef: { apiVersion: apps/v1, kind: Deployment, name: web }
  minReplicas: 2
  maxReplicas: 20
  metrics:
    - type: Resource
      resource: { name: cpu, target: { type: Utilization, averageUtilization: 70 } }
  behavior:
    scaleDown: { stabilizationWindowSeconds: 300 }
```

- **HPA not scaling?** Check `kubectl describe hpa` (`ScalingActive` /
  `<unknown>` metric), metrics-server health, and that **requests are set**
  (Utilization is a % of request).
- **VPA** (separate add-on, `autoscaling.k8s.io/v1`): modes `Off` (recommend
  only) / `Initial` / `Auto`|`Recreate` (evicts to resize; in-place resize is
  newer). **Don't run VPA and HPA on the same metric** — they fight.
- **Node autoscaling:** **Cluster Autoscaler** (pre-defined node groups, scales on
  *pending* Pods + consolidation) vs **Karpenter** (CNCF project; provisions
  right-sized nodes directly from Pod constraints, no node groups). **KEDA**
  (CNCF) drives HPA from event sources (queue length, cron). All scale on
  **requests**, not live usage — right-size requests or nodes churn.

---

## PHASE F — DISRUPTIONS, DRAIN & UPGRADES

- **PodDisruptionBudget** (`policy/v1`): `minAvailable` **or** `maxUnavailable`
  (count or %), `selector`, `unhealthyPodEvictionPolicy`. Protects against
  **voluntary** disruptions (drain, scale-down) — **not** involuntary (node
  crash). A too-strict PDB (`minAvailable: 100%`) **blocks drain forever**.

```bash
kubectl cordon <node>                           # stop new scheduling
kubectl drain <node> --ignore-daemonsets --delete-emptydir-data   # evict (honors PDBs)
# ... maintenance / kubelet upgrade ...
kubectl uncordon <node>                          # back into rotation
```

- **Version-skew policy** (support window is the apiserver and the N−2 minors):
  `kubelet`/`kube-proxy` may be **up to 3 minors older** than the apiserver, never
  newer; controller-manager/scheduler ≤ apiserver; `kubectl` within ±1 minor.
  **Upgrade one minor at a time.**
- **Order:** apiserver → controller-manager/scheduler/cloud-controller → kubelet →
  kube-proxy. **Drain before upgrading a node's kubelet.** With kubeadm:
  `kubeadm upgrade plan` → `kubeadm upgrade apply vX.Y.Z` on the first control
  plane, `kubeadm upgrade node` on the rest, then drain → upgrade kubelet/kubectl
  → `systemctl restart kubelet` → uncordon per node.
- **Deprecated APIs:** migrate manifests *before* the removing release —
  `kubectl convert -f m.yaml --output-version <group>/<v>`; check the cluster's
  API-deprecation warnings. Use `pkgs.k8s.io` (the legacy `apt/yum.kubernetes.io`
  repos are retired).

---

## PHASE G — SECURITY OPS (RBAC + Pod Security)

### G.1 RBAC

- **Role**/**RoleBinding** (namespaced) vs **ClusterRole**/**ClusterRoleBinding**
  (cluster-wide). Rules = `apiGroups` (`""` = core) × `resources` (+ subresources
  like `pods/log`, `pods/exec`) × `verbs` (`get,list,watch,create,update,patch,
  delete`, plus `escalate`/`bind`). `roleRef` is **immutable** — delete & recreate
  to change.
- **Verify, don't guess:** `kubectl auth can-i <verb> <resource>
  [--as=<user>] [-n <ns>]`. Privilege-escalation guard: you can't grant verbs you
  lack without `escalate`.
- **Aggregated ClusterRoles** (`aggregationRule` + label selectors) compose
  permissions modularly — label a small ClusterRole and it folds into the
  aggregate.
- **ServiceAccount tokens:** prefer **bound, projected, time-limited** tokens
  (`kubectl create token <sa> --duration=1h`, TokenRequest API). Long-lived
  auto-mounted Secret tokens are opt-in legacy — avoid; set
  `automountServiceAccountToken: false` where not needed.

```bash
kubectl auth can-i list secrets -n payments --as system:serviceaccount:payments:api
kubectl create token build-bot --duration=30m
```

### G.2 Pod Security Admission (PSP is removed)

PodSecurityPolicy was **removed** — use **Pod Security Admission**. Per-namespace
labels select a **level** (`privileged` / `baseline` / `restricted`) in a **mode**
(`enforce` / `audit` / `warn`), independently:

```yaml
metadata:
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/warn: restricted
    pod-security.kubernetes.io/audit: restricted
```

> `enforce` rejects only **Pods**; `audit`/`warn` also evaluate workload
> controllers — so a Deployment can be admitted while its Pods are blocked. Roll
> out with `warn`/`audit` first, then `enforce`.

**`securityContext` an SRE checks for `restricted`:** `runAsNonRoot: true`,
`allowPrivilegeEscalation: false`, `readOnlyRootFilesystem: true`,
`capabilities.drop: ["ALL"]`, `seccompProfile.type: RuntimeDefault`,
`privileged: false`.

---

## PHASE H — NETWORKING OPS

- **Service types:** `ClusterIP` (internal VIP) · `NodePort` (node port, default
  **30000–32767**) · `LoadBalancer` (cloud LB) · `ExternalName` (CNAME). **Headless**
  (`clusterIP: None`) returns Pod IPs directly — StatefulSet DNS.
- **EndpointSlices** (`discovery.k8s.io/v1`) are the scalable backing for Services
  (the old `Endpoints` API is deprecated). A Service with no ready endpoints =
  selector mismatch or unready Pods.
- **kube-proxy** modes: `iptables` (common default), `IPVS` (better at large
  Service counts), `nftables` (newer; **not the default everywhere yet** — verify
  per cluster).
- **DNS / CoreDNS:** Service FQDN `<svc>.<ns>.svc.cluster.local`. The **`ndots:5`**
  default makes short names try every search domain first → latency; use a
  trailing-dot FQDN for hot external lookups.
- **NetworkPolicy** (`networking.k8s.io/v1`): Pods are unisolated until selected
  by a policy. Rules are **additive** and **default-allow-until-default-denied** —
  apply a default-deny, then open required flows:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: { name: default-deny-ingress, namespace: app }
spec:
  podSelector: {}            # all Pods in ns
  policyTypes: [Ingress]     # nothing ingress-allowed until another policy permits
```

- **Ingress** (`networking.k8s.io/v1`) is **GA but feature-frozen**; **Gateway
  API** (`gateway.networking.k8s.io`) is the actively-developed successor (GA core
  kinds: GatewayClass/Gateway/HTTPRoute) — prefer it for new L7 routing.

### "Service not reachable" decision tree
1. `kubectl get endpointslices -l kubernetes.io/service-name=<svc>` — **any ready
   endpoints?** None → selector/label mismatch or Pods not Ready.
2. `kubectl get pods -l <selector>` — do Pods match and pass readiness?
3. DNS: `kubectl exec <pod> -- nslookup <svc>.<ns>.svc.cluster.local`.
4. Policy: `kubectl get networkpolicy -n <ns>` — is a default-deny blocking it?
5. Proxy: kube-proxy logs / mode; cross-node? check CNI.

---

## PHASE I — STORAGE OPS

- **Lifecycle:** PVC (request) binds a PV (supply); dynamic provisioning mints the
  PV from a **StorageClass**. `volumeBindingMode: WaitForFirstConsumer` delays
  binding until a Pod schedules (topology-aware — use it for zonal disks).
- **Reclaim policy:** **`Retain`** (PV kept after PVC deletion — safe for prod data,
  manual cleanup) vs **`Delete`** (storage deleted — data-loss risk).
- **Access modes:** `RWO` (one node) · `ROX` (many ro) · `RWX` (many rw — needs a
  capable backend, e.g. NFS/CephFS) · **`RWOP`** (one Pod). Most block storage is
  RWO only — a common "why won't my second replica mount it" surprise.
- **Volume expansion:** StorageClass `allowVolumeExpansion: true`, then raise
  `spec.resources.requests.storage`. **CSI** is the driver model; in-tree cloud
  volume plugins have migrated to CSI.

### "PVC Pending / won't mount" decision tree
1. `kubectl describe pvc <pvc>` — Events: no StorageClass? no matching PV?
   `WaitForFirstConsumer` (Pending until a Pod schedules — normal)?
2. `kubectl get storageclass` — does the named class exist / is it default?
3. **Multi-Attach error** → an RWO volume is still attached to another node;
   ensure the old Pod is gone (`kubectl get volumeattachments`).
4. Mount failures → CSI controller/node Pod logs in `kube-system`; fsGroup/SELinux
   permission mismatches.

---

## PHASE J — OBSERVABILITY OPS

- **`kubectl top node` / `top pod`** (needs metrics-server) for live CPU/mem.
- **Events** are first-class but **throttled and short-lived** (~1h retention) —
  capture them during an incident; don't rely on them historically.
- **Logs:** `kubectl logs --previous` for crashed containers; node/control-plane
  components via `journalctl -u kubelet|kube-apiserver|kube-scheduler|
  kube-controller-manager` or `/var/log/...`. `kubectl cluster-info dump` for a
  full snapshot.
- **Node NotReady** triage: `describe node` → conditions (kubelet posting status?),
  `journalctl -u kubelet` on the node, CNI/health, disk/PID pressure.
- **Standard stack:** Prometheus (metrics) + Loki/ELK (logs) + OpenTelemetry
  (traces) is the portable baseline; metrics-server is **only** for `kubectl top`
  and HPA, not a monitoring system. For a vendor query layer see `dynatrace` /
  `kusto-kql-api`.

---

## PHASE K — BACKUP & DISASTER RECOVERY

A backup you have never restored is a hope, not a backup. Two layers:

- **Cluster state — etcd.** etcd holds all API objects; losing it loses the
  cluster. Snapshot regularly and **off-cluster**, and rehearse restore:

```bash
ETCDCTL_API=3 etcdctl snapshot save snap.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
etcdctl snapshot status snap.db -w table        # verify before trusting it
# restore: etcdctl snapshot restore snap.db --data-dir /var/lib/etcd-restore
# then point the etcd static Pod at the new data dir and restart the control plane
```

> Managed control planes (EKS/GKE/AKS) own etcd — you can't `etcdctl` it; rely on
> the provider's control-plane backup + object-level backup below.

- **Workloads & data — objects + volumes.** Back up namespaced objects and PV
  data with **Velero** (`velero backup create`, schedules, restore), which can
  trigger **CSI `VolumeSnapshot`** via a `VolumeSnapshotClass` for crash-consistent
  volume copies. For databases, prefer app-aware backups (the DB's own dump/PITR)
  over raw volume snapshots.
- **DR drills:** periodically restore into a scratch namespace/cluster and verify
  the app comes up — an untested restore is the most common DR failure. Keep
  manifests in Git (declarative recovery), but Git does **not** back up PV **data**
  or etcd — those need the steps above.
- **Ownership:** etcd/control-plane DR → `k8s-cluster-operator`; volume snapshots /
  Velero → `k8s-network-storage`.

---

## ANTI-PATTERNS (each one fails review)

| Anti-pattern | Why it breaks | Do instead |
|---|---|---|
| Restart/delete/scale before reading Events | Treats symptom; recurs | `describe` + `logs --previous` + events first |
| `kubectl edit`/`patch` to fix prod | Drifts from Git; lost on reconcile | Change the manifest; GitOps reconciles |
| `kubectl delete` StatefulSet Pod/PVC to "reset" | Destroys data | Understand reclaim policy + volumeClaimTemplates first |
| No resource requests | BestEffort → first evicted; HPA Utilization meaningless | Always set requests; limits deliberately |
| `initialDelaySeconds` instead of a startupProbe | Boot loops on slow start | Use `startupProbe` to gate liveness |
| Memory limit == request "to be safe" without headroom | OOMKills under burst | Size from observed `kubectl top`; CPU throttles, mem kills |
| `minAvailable: 100%` PDB | Drain blocks forever | Budget that permits one disruption (e.g. `maxUnavailable: 1`) |
| Hard-deleting Pods / powering off nodes for maintenance | Skips PDB + graceful term | `cordon` → `drain` → maintain → `uncordon` |
| Skipping minors / wrong upgrade order / kubelet newer than apiserver | Skew breakage | One minor at a time, apiserver-first, drain before kubelet |
| Referencing PodSecurityPolicy | Removed | Pod Security Admission (labels) + securityContext |
| `cluster-admin` / long-lived SA token for a workload | Excess blast radius | Scoped RBAC + bound projected tokens |
| No NetworkPolicy (flat network) | Lateral movement | Default-deny + explicit allows |
| `reclaimPolicy: Delete` on stateful data | PVC delete wipes storage | `Retain` for data you can't lose |
| "Backups" that are never test-restored (or Git as the only "backup") | Restore fails when you need it; Git holds manifests, not etcd/PV data | Snapshot etcd + volumes off-cluster; rehearse restore in a scratch namespace |
| Pinning a Kubernetes minor version in docs/manifests as "current" | Rots fast | State behavior; verify against the live cluster + kubespec.dev |

---

## PRE-DONE VERIFICATION CHECKLIST

**Triage**
- [ ] Diagnosed from `describe` + Events + `logs --previous` before changing anything; root cause named, not just the `reason` string.

**Workloads**
- [ ] Rollout strategy fits (zero-downtime vs Recreate); readiness probe present; `preStop`/grace period set for graceful drain.

**Resources**
- [ ] Requests set on every container; QoS intended; namespace `LimitRange`/`ResourceQuota` where multi-tenant.

**Scheduling/scaling**
- [ ] Placement constraints justified (not over-constrained); HPA on `autoscaling/v2` with requests set + metrics-server healthy; VPA/HPA not on the same metric.

**Maintenance**
- [ ] PDB allows progress; `cordon`→`drain`→`uncordon` for nodes; upgrades one minor at a time, correct order, deprecated APIs migrated.

**Security**
- [ ] RBAC least-privilege (verified with `auth can-i`); PSA `restricted` where feasible; `securityContext` hardened; bound tokens, not long-lived secrets.

**Networking/storage**
- [ ] Endpoints/selectors verified for reachability; default-deny NetworkPolicy where required; reclaim policy correct; access mode matches replica topology.

**Backup/DR**
- [ ] etcd snapshotted off-cluster (or provider-managed); PV data + objects backed up (Velero / CSI `VolumeSnapshot`); a restore has actually been rehearsed.

---

## REFERENCE

### Highest-yield commands
`kubectl describe` · `kubectl get events --sort-by=.lastTimestamp -A` ·
`kubectl logs --previous` · `kubectl top pod/node` · `kubectl auth can-i` ·
`kubectl rollout status/undo` · `kubectl drain/cordon/uncordon` ·
`kubectl debug` · `kubectl explain` · `kubectl get … -o jsonpath`.

### Version-sensitive facts (verify against your cluster)
- **PodSecurityPolicy removed** → Pod Security Admission is the mechanism.
- **HPA = `autoscaling/v2`**; Metrics API = `metrics.k8s.io/v1beta1`.
- **Ingress GA but frozen**; **Gateway API** is the successor (core kinds GA).
- **EndpointSlices** (`discovery.k8s.io/v1`) replace the deprecated Endpoints API.
- **nftables** kube-proxy mode exists but isn't the universal default — check.
- **`RWOP`** access mode and bound/projected SA tokens are the modern defaults.
- In-tree cloud volume plugins have migrated to **CSI**.
- Don't hardcode a single "current" minor — cite **kubespec.dev** for exact field
  specs and confirm with `kubectl explain` / `api-resources`.

### Sources
kubernetes.io (canonical docs/behavior) · kubespec.dev (exact resource/field
specs across versions) · Civo Academy & community learning paths (operational
curriculum framing).

---

## SUBAGENT ORCHESTRATION

When this repo's operations subagents are installed (`.claude/agents/`), delegate
to the specialist; this skill is the shared contract (CORE PRINCIPLES + TRIAGE
MAP). The subagents are **repo-scoped** — installing only this `SKILL.md`
elsewhere will not carry them.

| Surface | Subagent | Owns |
|---|---|---|
| Triage & workloads | `k8s-workload-troubleshooter` | Pod-failure decision trees, rollouts, probes, graceful shutdown, `kubectl debug`, log/event triage |
| Cluster & maintenance | `k8s-cluster-operator` | resources/QoS, scheduling/placement, eviction, PDB/drain/cordon, version-skew upgrades, node maintenance |
| Scaling | `k8s-autoscaling-engineer` | HPA/VPA/Cluster-Autoscaler/Karpenter/KEDA, metrics-server, capacity & cost |
| Security | `k8s-security-rbac` | RBAC least-privilege, `auth can-i`, SA bound tokens, Pod Security Admission, `securityContext` hardening |
| Networking & storage | `k8s-network-storage` | Services/EndpointSlices/DNS/NetworkPolicy/Ingress-Gateway and PV/PVC/StorageClass/CSI, the reachability & PVC-pending trees |

Every subagent enforces the **CORE PRINCIPLES** and starts from the **TRIAGE
MAP**. For an incident: `k8s-workload-troubleshooter` triages, then hands to the
owning specialist (`k8s-cluster-operator` | `k8s-autoscaling-engineer` |
`k8s-security-rbac` | `k8s-network-storage`).
