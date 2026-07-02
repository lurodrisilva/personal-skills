---
name: karpenter-eks
description: >-
  MUST USE when installing, operating, tuning, or troubleshooting **Karpenter on
  Amazon EKS** — the just-in-time node-lifecycle autoscaler that provisions
  right-sized EC2 nodes directly from pending-pod constraints instead of scaling
  fixed node groups. This skill owns **Karpenter-on-EKS**: the CRDs, the AWS
  install/IAM surface, the disruption engine, observability, and the
  troubleshooting decision trees. Use for — the **APIs**: `NodePool`
  (`karpenter.sh/v1`), `EC2NodeClass` (`karpenter.k8s.aws/v1`), `NodeClaim`;
  **scheduling requirements** (well-known labels + `karpenter.k8s.aws/instance-*`,
  operators `In/NotIn/Exists/Gt/Lt/Gte/Lte`, `minValues`, `karpenter.sh/capacity-type`
  spot/on-demand/reserved, `nodeClassRef`, taints/`startupTaints`, `expireAfter`,
  `limits`, `weight`); **EC2NodeClass** (`amiFamily`, `amiSelectorTerms` + alias
  pinning like `al2023@<version>`, subnet/`securityGroupSelectorTerms` tag discovery
  via `karpenter.sh/discovery`, `role` vs `instanceProfile`, `blockDeviceMappings`,
  `metadataOptions`/IMDSv2, `kubelet` config, `userData`); **disruption** —
  consolidation (`consolidationPolicy` `WhenEmpty` vs `WhenEmptyOrUnderutilized`,
  `consolidateAfter`, single/multi/empty), **drift**, **expiration**, **interruption**
  (SQS + EventBridge, spot 2-minute warning, instance health), **disruption budgets**
  (`nodes` count/%, `schedule`+`duration`, `reasons`), `karpenter.sh/do-not-disrupt`,
  `terminationGracePeriod`, PDB interplay, the `karpenter.sh/termination` finalizer;
  **install/upgrade on EKS** (helm `karpenter-crd` + `karpenter` from
  `oci://public.ecr.aws/karpenter/karpenter`, CloudFormation IAM, **Pod Identity vs
  IRSA**, `settings.interruptionQueue`, spot service-linked role, node-role access
  entry / `aws-auth`); **observability** (`karpenter_*` Prometheus metrics);
  **migration from Cluster Autoscaler**. Triggers on phrases — "karpenter", "nodepool",
  "ec2nodeclass", "nodeclaim", "nodes not provisioning", "no instance type met the
  scheduling requirements", "node NotReady karpenter", "karpenter not deprovisioning /
  not consolidating", "spot interruption", "consolidation", "drift", "disruption
  budget", "do-not-disrupt", "karpenter IAM / pod identity / IRSA", "interruption
  queue", "migrate from cluster autoscaler". Triggers on config surfaces — `NodePool` /
  `EC2NodeClass` / `NodeClaim` YAML, `karpenter.sh/*` and `karpenter.k8s.aws/*` labels.
  Scope boundary — generic **HPA/VPA/KEDA** and **Cluster Autoscaler** live in
  `kubernetes-operations` (agent `k8s-autoscaling-engineer`); cluster upgrades,
  scheduling/QoS and node maintenance in `kubernetes-operations`
  (`k8s-cluster-operator`); pod-crash triage in `k8s-workload-troubleshooter`;
  **security/IRSA hardening** in `kubernetes-security`; the **agentic MCP tool-belt +
  blast-radius doctrine** in `agentic-k8s-ops`. Authored as a Distinguished SRE's
  playbook — provision from pod intent, keep NodePools flexible, make disruption a
  budgeted/observable control, and require IMDSv2 + least-privilege on every node.
  **Karpenter moves fast: state behavior, pin no version, verify against
  karpenter.sh before relying on any flag or feature gate.**
license: BSD-3-Clause
compatibility: opencode
metadata:
  domain: operations
  platform: aws-eks
  tool: karpenter
  pattern: node-lifecycle-autoscaling
  api-versions: karpenter.sh/v1, karpenter.k8s.aws/v1
  surfaces: install-iam, nodepool-scheduling, ec2nodeclass, disruption, observability, troubleshooting
  use_cases: node-provisioning, consolidation-cost, spot-interruption, ca-migration
---

# Karpenter on Amazon EKS

You are a Distinguished SRE operating **Karpenter** — the just-in-time node
lifecycle manager for Kubernetes — on **Amazon EKS**. Karpenter watches for
unschedulable pods, evaluates their combined constraints, launches the cheapest
compatible EC2 instance(s) directly (no Auto Scaling Group), and disrupts nodes
when they are empty, cheaper alternatives exist, drift from spec, expire, or are
interrupted. This skill is the **operating doctrine + the CRD reference + the
troubleshooting trees**.

> **Scope boundary.**
> - Generic **HPA / VPA / KEDA** and **Cluster Autoscaler** → `kubernetes-operations`
>   (agent `k8s-autoscaling-engineer`). This skill is Karpenter-specific.
> - **Cluster upgrades, scheduling/QoS, node maintenance** → `kubernetes-operations`
>   (`k8s-cluster-operator`); **pod-crash triage** → `k8s-workload-troubleshooter`.
> - **Security / IRSA hardening, least-privilege IAM strategy** → `kubernetes-security`.
> - **Agentic MCP tool-belt + blast-radius doctrine** → `agentic-k8s-ops`.
> This skill owns **Karpenter-on-EKS install + NodePool/EC2NodeClass design +
> disruption + troubleshooting**.

> **Version gate (read first).** Karpenter's core APIs are **v1 GA** (`karpenter.sh/v1`,
> `karpenter.k8s.aws/v1`); the release line advances quickly. **State behavior, pin no
> version number in configs, and verify every flag / feature gate / AMI alias against
> `karpenter.sh/docs` before relying on it.** Feature gates (`SpotToSpotConsolidation`,
> `NodeRepair`, `NodeOverlay`, `ReservedCapacity`, …) change stability between releases.

---

## CORE PRINCIPLES (NON-NEGOTIABLE)

1. **Provision from pod intent, not node groups.** Karpenter's input is *pending pods*.
   You describe the *bounds* of acceptable nodes (a `NodePool`) and the *AWS shape*
   (an `EC2NodeClass`); Karpenter picks the instance. Don't recreate ASG-style fixed
   pools — that throws away bin-packing and price optimization.
2. **Keep NodePools flexible.** Give the scheduler room: many instance families /
   categories / generations, both architectures if your images allow, and `minValues`
   to force a minimum spread. A NodePool locked to one instance type cannot get spot
   diversity or consolidate to something cheaper.
3. **Consolidation is cost control — tune it, don't disable it.** Prefer
   `WhenEmptyOrUnderutilized` with a `consolidateAfter` that matches your workload's
   churn, and rate-limit with **disruption budgets** (by reason + schedule). Turning
   consolidation off is a standing cost regression.
4. **Spot requires an interruption queue.** Wire the **SQS interruption queue** +
   EventBridge rules and set `settings.interruptionQueue`. Without it Karpenter cannot
   act on the 2-minute spot warning, scheduled-change, or instance-health events.
5. **IMDSv2 + least privilege on every node.** `metadataOptions.httpTokens: required`,
   `httpPutResponseHopLimit: 1`; a dedicated least-privilege **node role**; tag-scoped
   subnet/SG **discovery** (`karpenter.sh/discovery: <cluster>`) — never wildcard-open.
6. **Pin AMIs explicitly in production.** Use an `amiSelectorTerms` **alias with a
   version** (`al2023@v20240807`) or a specific `id`/`tags`. A floating alias
   (`@latest`) means an upstream AMI release silently **drifts and rolls your fleet**.
7. **Drift is your GitOps reconvergence signal.** Change a NodePool/EC2NodeClass field
   (requirements, selectors, AMI) → existing nodes are marked *drifted* → Karpenter
   rolls them, budget-permitting. Manage the roll with budgets, not by disabling drift.
8. **Observe before you tune.** Read `karpenter_*` metrics + controller logs +
   NodeClaim/NodePool `status.conditions` before changing overhead percentages, limits,
   or budgets. Most "Karpenter miscomputes resources" reports are request/overhead math.
9. **The `karpenter.sh/termination` finalizer is load-bearing.** It drains gracefully.
   Force-removing finalizers in bulk is a last-resort break-glass, never routine — it
   skips drain and can orphan EC2 instances.

---

## TRIAGE MAP — symptom → where to look

| Symptom | First look | Phase / agent |
|---|---|---|
| Pods `Pending`, no node appears | controller logs; NodePool `limits`; requirements vs pod | B / F · `karpenter-troubleshooter` |
| `no instance type met the scheduling requirements` | pod requests vs instance sizes; zone/AZ; capacity-type | B / F |
| Node launches then `NotReady` | `aws-auth`/access entry, SG, CNI, `journalctl -u kubelet` | F |
| Node created then **terminates immediately** | KMS key policy for encrypted EBS root | F |
| Nodes won't consolidate / deprovision | init state, PDBs, `do-not-disrupt`, budgets | D / F |
| Spot nodes churn / double-drain | NTH vs Karpenter interruption conflict | D / F |
| `strict decoding error: unknown field` | CRD chart vs controller version mismatch | A / F |
| Controller `i/o timeout` resolving STS at startup | `dnsPolicy: Default`; DNS pod capacity | A / F |
| Fleet too big / too costly | consolidation policy, `consolidateAfter`, `minValues` | B / D |
| AMI rolled unexpectedly | floating `amiSelectorTerms` alias → drift | C / D |

---

## PHASE A — Install / IAM / Upgrade (EKS)

**Decision tree — controller identity:**
```
Cluster has EKS Pod Identity agent addon?
├─ yes → use Pod Identity association (recommended: no OIDC trust juggling)
└─ no  → use IRSA (IAM Roles for Service Accounts) with the cluster OIDC provider
```

Karpenter has **two IAM roles**: a **controller role** (calls EC2/pricing/SQS/EKS) and
a **node role** (`KarpenterNodeRole-<cluster>`, the instance profile every node runs
with — mapped into the cluster via an access entry / `aws-auth`). The Getting Started
**CloudFormation** stack creates both plus the SQS interruption queue and EventBridge
rules.

```bash
# 1. IAM + SQS + EventBridge via the Getting Started CloudFormation template.
aws cloudformation deploy \
  --stack-name "Karpenter-${CLUSTER_NAME}" \
  --template-file cloudformation.yaml \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides "ClusterName=${CLUSTER_NAME}"

# 2. EC2 spot service-linked role (idempotent; needed before spot launches).
aws iam create-service-linked-role --aws-service-name spot.amazonaws.com || true

# 3. Map the node role into the cluster (EKS access entry preferred over aws-auth):
aws eks create-access-entry --cluster-name "${CLUSTER_NAME}" \
  --principal-arn "arn:aws:iam::${AWS_ACCOUNT_ID}:role/KarpenterNodeRole-${CLUSTER_NAME}" \
  --type EC2_LINUX

# 4. CRDs first (separate chart so schema upgrades are explicit), then the controller.
helm upgrade --install karpenter-crd oci://public.ecr.aws/karpenter/karpenter-crd \
  --version "${KARPENTER_VERSION}" --namespace kube-system --create-namespace

helm upgrade --install karpenter oci://public.ecr.aws/karpenter/karpenter \
  --version "${KARPENTER_VERSION}" --namespace kube-system \
  --set "settings.clusterName=${CLUSTER_NAME}" \
  --set "settings.interruptionQueue=${CLUSTER_NAME}" \
  --set controller.resources.requests.cpu=1 \
  --set controller.resources.requests.memory=1Gi \
  --wait
```

**Bootstrap note:** Karpenter cannot provision the nodes it runs on. Run the controller
on a small managed node group (or Fargate) with room for 2 replicas; the deployment
defaults to 2 for HA. If it can't schedule, drop to 1 replica or grow the MNG.

**Upgrade order:** read the release notes → `helm upgrade karpenter-crd` (schema) →
`helm upgrade karpenter` (controller). A controller newer/older than its CRDs produces
`strict decoding error: unknown field`. Never skip minor versions blindly.

---

## PHASE B — NodePool + scheduling

The `NodePool` is the *bounds*: which instances are acceptable, how they're labelled/
tainted, when they expire, and how they may be disrupted.

**Decision tree — requirement breadth:**
```
Need cheapest compute + resilience?  → broad families/categories + spot & on-demand,
                                        set minValues to force diversity
Need a specific arch/accelerator?     → constrain kubernetes.io/arch / instance-family;
                                        keep generation flexible
Need workload isolation?              → taints on the NodePool + tolerations on pods,
                                        or a labelled NodePool + nodeSelector, weight to prefer
```

```yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: default
spec:
  template:
    metadata:
      labels:
        team: platform
    spec:
      nodeClassRef:
        group: karpenter.k8s.aws
        kind: EC2NodeClass
        name: default
      requirements:
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64"]
        - key: kubernetes.io/os
          operator: In
          values: ["linux"]
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["spot", "on-demand"]      # let Karpenter prefer spot, fall back
        - key: karpenter.k8s.aws/instance-category
          operator: In
          values: ["c", "m", "r"]
          minValues: 2                        # force ≥2 categories for diversity
        - key: karpenter.k8s.aws/instance-generation
          operator: Gt
          values: ["4"]                       # modern (Nitro) generations only
      expireAfter: 336h                        # 14d max node lifetime (or "Never")
      terminationGracePeriod: 24h              # hard cap on drain
  limits:
    cpu: "1000"                                # ceiling; NodePool stops provisioning past it
  weight: 50                                   # higher wins when multiple NodePools match
  disruption:
    consolidationPolicy: WhenEmptyOrUnderutilized
    consolidateAfter: 1m
```

**Well-known requirement keys.** Kubernetes: `kubernetes.io/arch`, `kubernetes.io/os`,
`node.kubernetes.io/instance-type`, `topology.kubernetes.io/zone`. Karpenter/AWS:
`karpenter.sh/capacity-type` (`spot`/`on-demand`/`reserved`),
`karpenter.k8s.aws/instance-family`, `instance-category`, `instance-generation`,
`instance-cpu`, `instance-memory`, `instance-hypervisor`, `instance-gpu-*`. Operators:
`In`, `NotIn`, `Exists`, `DoesNotExist`, `Gt`, `Lt`, `Gte`, `Lte`. `minValues` forces
the scheduler to keep at least N distinct satisfying values (critical for spot pools).

**Pods still steer placement.** `nodeSelector`, `nodeAffinity`, `topologySpreadConstraints`,
pod (anti)affinity, and resource **requests** all flow into Karpenter's simulation.
Karpenter bin-packs on **requests** — inaccurate requests cause over/under-provisioning;
enforce minimums with a `LimitRange`.

---

## PHASE C — EC2NodeClass (the AWS shape)

The `EC2NodeClass` is AWS-specific: which AMI, subnets, security groups, IAM identity,
disks, metadata options, and kubelet config new nodes get.

```yaml
apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: default
spec:
  role: "KarpenterNodeRole-${CLUSTER_NAME}"   # OR instanceProfile: (exactly one)
  amiSelectorTerms:
    - alias: al2023@v20240807                  # PIN the version in prod (not @latest)
  subnetSelectorTerms:
    - tags:
        karpenter.sh/discovery: "${CLUSTER_NAME}"
  securityGroupSelectorTerms:
    - tags:
        karpenter.sh/discovery: "${CLUSTER_NAME}"
  metadataOptions:
    httpEndpoint: enabled
    httpTokens: required                       # IMDSv2 only
    httpPutResponseHopLimit: 1                 # block pod access to IMDS
  blockDeviceMappings:
    - deviceName: /dev/xvda
      ebs:
        volumeSize: 100Gi
        volumeType: gp3
        encrypted: true
        deleteOnTermination: true
  kubelet:
    maxPods: 110
    systemReserved:
      cpu: 100m
      memory: 100Mi
  tags:
    team: platform
```

- **`amiFamily` / `amiSelectorTerms`** — `amiFamily` (AL2023, AL2, Bottlerocket, Windows,
  Custom) sets the bootstrap flavor; `amiSelectorTerms` chooses the actual image by
  `alias` (recommended, e.g. `al2023@<version>` / `bottlerocket@<version>`), `id`, `name`,
  `owner`, `tags`, or `ssmParameter`. **A term change is drift** → fleet rolls.
- **`role` vs `instanceProfile`** — set exactly one. Prefer `role`; Karpenter manages the
  instance profile for you.
- **`blockDeviceMappings`** — right-size root volume, `gp3`, `encrypted: true`, tune
  `iops`/`throughput`. Encrypted with a **customer-managed KMS key** requires a key
  policy that lets the node role use it via EC2 (else nodes terminate on launch — Phase F).
- **`kubelet`** — `maxPods`, `podsPerCore`, `systemReserved`/`kubeReserved`,
  `evictionHard`/`evictionSoft`, `clusterDNS`. `maxPods` interacts with VPC-CNI IP
  density — see the CNI IP-exhaustion tree in Phase F.
- **`userData`** — appended (or replaces, for Custom family) to the bootstrap.
- **Status conditions** — `Ready`, `SubnetsReady`, `SecurityGroupsReady`, `AMIsReady`,
  `InstanceProfileReady`; `status.subnets/securityGroups/amis` show what discovery
  resolved. `kubectl describe ec2nodeclass` is the first stop when nodes won't launch.

---

## PHASE D — Disruption (the engine that removes/replaces nodes)

Two categories. **Graceful** (rate-limited by budgets, launch a replacement first):
Consolidation, Drift. **Forceful** (budget-exempt, act immediately): Expiration,
Interruption, Node Repair.

**Decision tree — which knob:**
```
Want cheaper steady-state?         → consolidationPolicy: WhenEmptyOrUnderutilized + consolidateAfter
Only remove truly empty nodes?     → consolidationPolicy: WhenEmpty
Roll on config/AMI change?         → drift (automatic; pace with budgets by reason: Drifted)
Cap node age?                      → expireAfter on the NodePool template
Handle spot / health events?       → SQS interruption queue (settings.interruptionQueue)
Protect a critical pod/node?       → karpenter.sh/do-not-disrupt (bool or duration)
Rate-limit / freeze windows?       → spec.disruption.budgets (nodes + schedule + reasons)
```

- **Consolidation** runs empty → multi-node → single-node. `WhenEmpty` only removes
  zero-non-daemon-pod nodes; `WhenEmptyOrUnderutilized` also repacks underutilized nodes
  after `consolidateAfter`. Spot single-node consolidation needs **≥15 instance-type
  flexibility** to avoid consolidating into cheap, interrupt-prone types.
- **Drift** watches NodePool `requirements` + EC2NodeClass `subnet/securityGroup/amiSelectorTerms`
  (and resolved AMIs). Behavioral fields (`weight`, `limits`, `disruption.*`) are **not**
  drift. Changing `expireAfter` triggers drift on existing NodeClaims, not immediate expiry.
- **Interruption** (needs the SQS queue): spot 2-minute warning, scheduled-change health
  events, instance stopping/terminating, status-check failures. On spot interruption
  Karpenter launches a replacement *simultaneously*. It **publishes but does not act on**
  spot *rebalance recommendations* — use NTH only for that, and if you do, disable NTH's
  spot/rebalance draining to avoid double-handling.
- **Node Repair** (feature gate `NodeRepair`, **verify stability**) replaces nodes stuck
  `Ready=False/Unknown` or failing node-agent conditions, with a cascade guard (halts if
  >20% of a NodePool is unhealthy).

**Disruption budgets:**
```yaml
spec:
  disruption:
    consolidationPolicy: WhenEmptyOrUnderutilized
    consolidateAfter: 30s
    budgets:
      - nodes: "10%"                       # default-style ceiling across all reasons
      - nodes: "5"
        reasons: ["Drifted"]              # at most 5 nodes drifting at once
      - nodes: "0"                         # freeze voluntary disruption out of hours
        schedule: "0 17 * * mon-fri"       # cron is UTC
        duration: 15h
        reasons: ["Underutilized", "Drifted"]
```
- `nodes` as `%` (of NodePool total) or a count; the **most restrictive** matching
  budget wins. `reasons` (`Empty`/`Underutilized`/`Drifted`) scope a budget; omit =
  all reasons. `schedule`+`duration` must appear together (cron **UTC**, no timezones).
- **Budgets do NOT gate Expiration or Interruption** (forceful). Only graceful methods.

**Pod / node controls:**
- `karpenter.sh/do-not-disrupt: "true"` (permanent) or `"30m"` (duration) on a **pod**
  excludes its node from Consolidation + Drift; the same annotation on a **node** blocks
  voluntary disruption of that node. It does **not** stop Expiration, Interruption, Node
  Repair, or manual delete.
- A blocking **PDB** (`maxUnavailable: 0`) prevents voluntary eviction; if multiple PDBs
  cover a node's pods, **all** must allow disruption.
- `terminationGracePeriod` caps drain time; when set it lets Drift proceed **despite**
  blocking PDBs / `do-not-disrupt` once the clock expires — the escape valve for
  otherwise-undrainable nodes. Max node lifetime ≈ `expireAfter` + `terminationGracePeriod`.

---

## PHASE E — Observability

Scrape the controller (`METRICS_PORT`, default `8080`). The metrics that matter for
alerting/SLOs:

| Area | Metric | Watch for |
|---|---|---|
| Provisioning | `karpenter_nodeclaims_created_total` / `_terminated_total` | churn spikes |
| Latency | `karpenter_pods_startup_duration_seconds` | slow scale-up |
| Scheduling | `karpenter_scheduler_queue_depth`, `karpenter_pods_state` | stuck pending pods |
| Capacity | `karpenter_nodepools_usage` vs `karpenter_nodepools_limit` | hitting `limits` |
| Disruption | `karpenter_voluntary_disruption_decisions_total`, `_eligible_nodes`, `karpenter_nodepools_allowed_disruptions` | budget starvation |
| Interruption | `karpenter_interruption_received_messages_total`, `karpenter_interruption_instance_status_unhealthy_total` | spot storms / bad instances |
| Cluster state | `karpenter_cluster_state_synced` (want `1`), `karpenter_cluster_state_unsynced_time_seconds` | controller not seeing reality |
| Controller | `controller_runtime_reconcile_errors_total`, `controller_runtime_terminal_reconcile_errors_total` | reconcile failures |

Pair metrics with `kubectl get nodeclaims`, NodePool/EC2NodeClass `status.conditions`,
and `kubectl logs -n kube-system <karpenter-pod> -c controller`.

---

## PHASE F — Troubleshooting decision trees

**Pods pending / no node:**
```
"no instance type met the scheduling requirements or had a required offering"
├─ pod requests larger than any allowed instance      → widen requirements / raise sizes
├─ pinned to a zone with no matching offering/volume   → align zone req + EBS AZ
├─ NodePool at spec.limits                             → raise limits or add a NodePool
└─ DaemonSet requests exceed the node types allowed    → account for DS in sizing
```

**Node joins then NotReady:** SSH via SSM, `sudo journalctl -u kubelet`.
- `Unauthorized` / won't register → node role missing from access entry / `aws-auth`
  (`system:bootstrappers`, `system:nodes`).
- "Network plugin not ready" → node-role IAM/VPC-CNI permissions.
- `No entry for <instance-type> in /etc/eks/eni-max-pods.txt` → update the VPC CNI addon.

**Node created → terminates immediately:** encrypted EBS root with a customer-managed KMS
key whose policy doesn't grant the node role `kms:...` via
`kms:ViaService = ec2.<region>.amazonaws.com`. Fix the key policy.

**Nodes won't deprovision/consolidate:**
```
├─ node lacks karpenter.sh/initialized (not fully Ready / resources unregistered)
├─ a pod has an active karpenter.sh/do-not-disrupt
├─ a blocking PDB (maxUnavailable: 0)
├─ inter-pod affinity / topology-spread makes the consolidation simulation infeasible
└─ a budget (possibly nodes: "0" on a schedule) is currently 0
```
Use `tools/disruption-blockers.sh` to enumerate these fast.

**CNI can't assign pod IPs** (`failed to assign an IP address to container`): `maxPods`
> instance density, subnet IP exhaustion, or SG-for-pods reserving the trunk ENI. Fixes:
enable **prefix delegation**, right-size `maxPods`, spread with topology constraints,
grow the subnet CIDR, or set `RESERVED_ENIS` when using SG-for-pods.

**Controller `i/o timeout` resolving STS at startup:** DNS not up yet with
`dnsPolicy: ClusterFirst`. Set the chart's `dnsPolicy: Default` (use VPC DNS) or ensure
DNS pods have capacity/tolerations.

**`strict decoding error: unknown field`:** CRD chart vs controller version mismatch —
upgrade `karpenter-crd` to match the controller; re-check the migration notes.

**Stale pricing / `AWS_ISOLATED_VPC`:** in an isolated subnet with no Price List VPC
endpoint, set `--aws-isolated-vpc` / `AWS_ISOLATED_VPC=true` to skip pricing lookups.

**Break-glass — stuck `karpenter.sh/termination` finalizers** (only after confirming the
EC2 instances are actually gone, e.g. after an uninstall):
```bash
kubectl get nodes \
  -ojsonpath='{range .items[*].metadata}{@.name}:{@.finalizers}{"\n"}' \
  | grep "karpenter.sh/termination" | cut -d ':' -f 1 \
  | xargs -r kubectl patch node --type=json \
      -p='[{"op":"remove","path":"/metadata/finalizers"}]'
```
This **skips graceful drain** — never routine; verify instances are terminated first.

---

## PHASE G — Migration from Cluster Autoscaler

```
1. Install Karpenter alongside CA (both running).
2. Create a NodePool + EC2NodeClass covering the workloads CA handled.
3. Scale CA's managed node groups / the CA deployment down (CA → 0), watch Karpenter
   absorb pending pods.
4. Translate each ASG's instance types + labels/taints into NodePool requirements.
5. Remove CA once stable.
```
Contrast: CA scales **fixed ASGs** reactively to pending pods; Karpenter **bin-packs**
arbitrary instance types from pod constraints and continuously **consolidates**. Don't
port ASG-per-shape thinking into one-NodePool-per-instance-type — keep NodePools broad.

---

## ANTI-PATTERNS (each one bites)

| Anti-pattern | Why it breaks | Do instead |
|---|---|---|
| NodePool locked to one instance type | no spot diversity, can't consolidate cheaper | broad families/categories + `minValues` |
| Floating AMI alias (`@latest`) in prod | upstream AMI release silently rolls the fleet | pin `alias@<version>` / `id` / `tags` |
| Disabling consolidation | standing cost regression | `WhenEmptyOrUnderutilized` + budgets to pace it |
| Spot NodePool with no interruption queue | misses the 2-min warning → hard kills | wire SQS + `settings.interruptionQueue` |
| Running NTH **and** Karpenter interruption on spot | double-drain / rebalance loop | Karpenter for interruption; disable NTH spot/rebalance draining |
| IMDSv1 (`httpTokens: optional`, hop >1) | pods can steal node-role creds (SSRF) | `httpTokens: required`, `httpPutResponseHopLimit: 1` |
| Wildcard subnet/SG selectors | over-broad node placement / blast radius | tag discovery `karpenter.sh/discovery` |
| Force-removing finalizers as routine | skips drain, can orphan EC2 | fix the real blocker; finalizer removal is break-glass |
| Over-tuning `VM_MEMORY_OVERHEAD_PERCENT` blindly | undersized nodes / OOM | measure per instance type first; adjust with caution |
| No resource requests on pods | Karpenter can't bin-pack; over/under-provisions | set requests; enforce a `LimitRange` |
| Upgrading controller without the CRD chart | `unknown field` / schema drift | `karpenter-crd` first, then controller, per release notes |

---

## PRE-DONE VERIFICATION CHECKLIST

**Install / identity**
- [ ] Controller role (Pod Identity or IRSA) + least-privilege node role; node role mapped via access entry / `aws-auth`.
- [ ] SQS interruption queue wired and `settings.interruptionQueue` set (if using spot); spot service-linked role exists.
- [ ] `karpenter-crd` chart version matches the controller; controller pods `Ready`.

**NodePool / EC2NodeClass**
- [ ] Requirements broad + `minValues` where diversity matters; `nodeClassRef` resolves.
- [ ] EC2NodeClass `status` all `*Ready`; AMI pinned by version/id/tags (not floating).
- [ ] `metadataOptions` = IMDSv2 (`httpTokens: required`, hop limit 1); subnets/SGs via tag discovery; root volume `encrypted`.

**Disruption / observability**
- [ ] `consolidationPolicy` + `consolidateAfter` set; budgets pace Drift/consolidation (freeze windows if needed).
- [ ] Metrics scraped; `karpenter_cluster_state_synced == 1`; no rising `controller_runtime_*_errors_total`.
- [ ] Critical workloads have PDBs and/or `do-not-disrupt`; `terminationGracePeriod` set as the drain escape valve.

**Doctrine**
- [ ] No version pinned in the SKILL/config prose; behavior verified against `karpenter.sh/docs`.
- [ ] Feature gates (`SpotToSpotConsolidation`, `NodeRepair`, …) labeled with current stability.

---

## REFERENCE

### Well-known requirement keys (one line)
`kubernetes.io/arch|os`, `node.kubernetes.io/instance-type`, `topology.kubernetes.io/zone`,
`karpenter.sh/capacity-type` (spot/on-demand/reserved), `karpenter.k8s.aws/instance-family|category|generation|cpu|memory|hypervisor|gpu-*`.

### Capacity types
`spot` (cheapest, interruptible — needs the queue) · `on-demand` (stable) · `reserved`
(capacity reservations / `ReservedCapacity` gate — verify stability).

### Key controller settings / env
`CLUSTER_NAME` (req) · `INTERRUPTION_QUEUE` · `VM_MEMORY_OVERHEAD_PERCENT` (0.075) ·
`RESERVED_ENIS` · `BATCH_MAX_DURATION`/`BATCH_IDLE_DURATION` · `LOG_LEVEL` ·
`METRICS_PORT` (8080) · `FEATURE_GATES` (`SpotToSpotConsolidation`, `NodeRepair`,
`NodeOverlay`, `ReservedCapacity` …) · `AWS_ISOLATED_VPC`. **Verify defaults/stability upstream.**

### Disruption (one line)
Graceful (budgeted): Consolidation, Drift · Forceful (immediate): Expiration,
Interruption, Node Repair · controls: budgets, `do-not-disrupt`, PDB, `terminationGracePeriod`.

### Read-only triage scripts (`tools/`)
`karpenter-health.sh` (controller + CRD + NodePool/EC2NodeClass/NodeClaim conditions) ·
`disruption-blockers.sh` (do-not-disrupt / blocking PDBs / disrupted taint) ·
`nodepool-capacity.sh` (limits vs usage, nodes by capacity-type/instance-type).

---

## MCP SURFACE (read-only)

There is **no official Karpenter MCP server** — do not wire a fabricated one. To let an
agent *operate* Karpenter, drive existing, guardrailed servers **read-only**, following
the blast-radius doctrine in `agentic-k8s-ops`:

| Server | Use for Karpenter | Guardrail |
|---|---|---|
| **kubernetes-mcp-server** (`--read-only`) | inspect `NodePool` / `EC2NodeClass` / `NodeClaim` / node `status.conditions`, events, pending pods, controller logs | `--read-only` (blocks create/update/delete) |
| **AWS MCP Server** | EC2 instance / SQS interruption-queue / pricing context under the cluster | Azure-style — **AWS RBAC** is the boundary (no global read-only flag); scope the identity |
| Prometheus/metrics reader (optional) | `karpenter_*` metrics for scale/disruption/interruption SLOs | read-only by nature |

Rules: **default-deny writes** — remediation (apply a NodePool, delete a node) lands as a
**gated GitOps PR**, never a direct agent mutation; least-privilege identity; budget the
tool count. Karpenter mutations are high-blast-radius (they launch/terminate EC2) — keep
the agent read-mostly and put a human on the Act step.

---

## SUBAGENT ORCHESTRATION

This skill drives a **5-agent Karpenter-EKS team** in `.claude/agents/`:

| Agent | Owns |
|---|---|
| `karpenter-nodepool-designer` | NodePool + scheduling requirements, capacity types, `minValues`, weight/limits, consolidation policy choice (Phase B, D-policy) |
| `karpenter-nodeclass-author` | EC2NodeClass — AMI selection/alias, subnet/SG discovery, role/instanceProfile, blockDeviceMappings, IMDSv2, kubelet, userData (Phase C) |
| `karpenter-disruption-operator` | consolidation/drift/expiration/interruption, budgets, do-not-disrupt, terminationGracePeriod, PDB interplay, NTH conflict (Phase D) |
| `karpenter-installer` | helm install/upgrade, CloudFormation IAM, Pod Identity vs IRSA, SQS queue, access entry, CA migration (Phase A, G) |
| `karpenter-troubleshooter` | the Phase-F decision trees; owns the `tools/` scripts |

**Handoffs:** generic HPA/VPA/KEDA + Cluster Autoscaler → `k8s-autoscaling-engineer`;
cluster upgrades / scheduling / node maintenance → `k8s-cluster-operator`; pod-crash
triage → `k8s-workload-troubleshooter`; security/IRSA hardening → the `k8s-*` security
agents; agentic MCP tool-belt + blast-radius doctrine → `agentic-k8s-ops`.
