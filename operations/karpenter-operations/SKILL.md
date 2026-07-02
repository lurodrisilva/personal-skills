---
name: karpenter-operations
description: >-
  MUST USE when installing, operating, tuning, or troubleshooting **Karpenter** —
  the just-in-time node-lifecycle autoscaler — on **Amazon EKS** or **Azure AKS**.
  Karpenter provisions right-sized cloud VMs directly from pending-pod constraints
  instead of scaling fixed node groups. This skill owns Karpenter **across its two
  first-class providers**: the shared core API, both cloud NodeClasses, install/
  identity on each cloud, the disruption engine, observability, and troubleshooting.
  Use for — the **shared core API** `NodePool` + `NodeClaim` (`karpenter.sh/v1`),
  scheduling `requirements` (operators `In/NotIn/Exists/Gt/Lt/Gte/Lte`, `minValues`,
  `karpenter.sh/capacity-type` spot/on-demand, `nodeClassRef`, taints/`startupTaints`,
  `expireAfter`, `terminationGracePeriod`, `limits`, `weight`, static `replicas`),
  the disruption engine (**consolidation** `WhenEmpty` vs `WhenEmptyOrUnderutilized`,
  `consolidateAfter`; **drift**; **expiration**; **interruption**; **disruption
  budgets** `nodes`/`schedule`/`duration`/`reasons`; `karpenter.sh/do-not-disrupt`;
  the `karpenter.sh/termination` finalizer); **AWS/EKS specifics** — `EC2NodeClass`
  (`karpenter.k8s.aws/v1`, `amiFamily`/`amiSelectorTerms` alias pinning, subnet/SG
  tag discovery `karpenter.sh/discovery`, `role`/`instanceProfile`, `blockDeviceMappings`,
  IMDSv2 `metadataOptions`, `kubelet`), `karpenter.k8s.aws/instance-*` keys, helm
  `karpenter-crd`+`karpenter` from `oci://public.ecr.aws/karpenter`, CloudFormation
  IAM, **Pod Identity vs IRSA**, the **SQS** interruption queue; **Azure/AKS
  specifics** — **Node Auto Provisioning (NAP)**, the managed Karpenter
  (`az aks ... --node-provisioning-mode Auto`, Azure-CNI-Overlay + Cilium, the
  pod-readiness SLA on AKS Automatic) and the self-hosted **Azure Karpenter
  provider**, `AKSNodeClass` (`karpenter.azure.com/v1beta1`, `imageFamily`
  Ubuntu2204/AzureLinux, `osDiskSizeGB`, `maxPods`, `kubelet`, tags),
  `karpenter.azure.com/sku-*` keys, **Workload Identity**, `--node-provisioning-default-pools`,
  the NAP disable procedure (`limits.cpu: 0` + `karpenter.azure.com/disable` taint),
  self-hosted→NAP migration. Triggers on phrases — "karpenter", "nodepool",
  "ec2nodeclass", "aksnodeclass", "nodeclaim", "node auto provisioning", "NAP",
  "node-provisioning-mode Auto", "aks automatic", "nodes not provisioning",
  "no instance type met the scheduling requirements", "node NotReady karpenter",
  "karpenter not consolidating", "spot interruption", "consolidation", "drift",
  "disruption budget", "do-not-disrupt", "karpenter IAM / pod identity / IRSA /
  workload identity", "sku-family", "migrate from cluster autoscaler". Triggers on
  config surfaces — `NodePool` / `EC2NodeClass` / `AKSNodeClass` / `NodeClaim` YAML,
  `karpenter.sh/*`, `karpenter.k8s.aws/*`, `karpenter.azure.com/*` labels. Scope
  boundary — generic **HPA/VPA/KEDA** and **Cluster Autoscaler** → `kubernetes-operations`
  (`k8s-autoscaling-engineer`); cluster upgrades / scheduling / node maintenance →
  `kubernetes-operations` (`k8s-cluster-operator`); pod-crash triage →
  `k8s-workload-troubleshooter`; **security / IRSA / Workload-Identity hardening
  strategy** → `kubernetes-security`; the agentic **MCP tool-belt + blast-radius
  doctrine** → `agentic-k8s-ops`. Authored as a Distinguished SRE's playbook —
  provision from pod intent, keep NodePools flexible, make disruption a
  budgeted/observable control, and use each cloud's least-privilege identity.
  **Karpenter and NAP move fast: state behavior, pin no version, verify against
  karpenter.sh and Microsoft Learn before relying on any flag or feature gate.**
license: BSD-3-Clause
compatibility: opencode
metadata:
  domain: operations
  platform: aws-eks, azure-aks
  tool: karpenter
  pattern: node-lifecycle-autoscaling
  api-versions: karpenter.sh/v1, karpenter.k8s.aws/v1, karpenter.azure.com/v1beta1
  providers: aws-karpenter-provider, azure-karpenter-provider, aks-node-auto-provisioning
  surfaces: install-identity, nodepool-scheduling, nodeclass, disruption, observability, troubleshooting
  use_cases: node-provisioning, consolidation-cost, spot-interruption, ca-migration, aks-nap
---

# Karpenter Operations (Amazon EKS + Azure AKS)

You are a Distinguished SRE operating **Karpenter** — the just-in-time node-lifecycle
manager for Kubernetes — across its **two first-class clouds**: **Amazon EKS** and
**Azure AKS**. Karpenter watches for unschedulable pods, evaluates their combined
constraints, launches the cheapest compatible cloud VM(s) directly (no ASG / no fixed
Agent Pool), and disrupts nodes when they are empty, cheaper alternatives exist, drift
from spec, expire, or are interrupted.

**The mental model that makes this skill portable:** Karpenter is one project with a
**shared, cloud-neutral core API** (`NodePool` + `NodeClaim`, `karpenter.sh/v1`) and a
**per-cloud provider** that supplies a **NodeClass** + cloud requirement labels:

| | **AWS (EKS)** | **Azure (AKS)** |
|---|---|---|
| Core API | `NodePool`, `NodeClaim` (`karpenter.sh/v1`) | same |
| NodeClass | `EC2NodeClass` (`karpenter.k8s.aws/v1`) | `AKSNodeClass` (`karpenter.azure.com/v1beta1`) |
| Cloud req keys | `karpenter.k8s.aws/instance-family\|category\|generation…` | `karpenter.azure.com/sku-family\|name\|version\|cpu\|memory…` |
| Install | self-hosted (helm) | **NAP** (managed) **or** self-hosted (Azure provider helm) |
| Controller identity | Pod Identity / IRSA | Workload Identity (managed identity) |
| Interruption | SQS queue + EventBridge | handled by NAP control plane (scheduled events) |
| Image pinning | `amiFamily` + `amiSelectorTerms` alias | `imageFamily` + node-image auto-upgrade |
| Networking | any EKS CNI | **Azure CNI Overlay + Cilium only** (NAP) |

> **Scope boundary.**
> - Generic **HPA / VPA / KEDA** and **Cluster Autoscaler** → `kubernetes-operations`
>   (`k8s-autoscaling-engineer`). This skill is Karpenter-specific.
> - Cluster upgrades / scheduling / node maintenance → `kubernetes-operations`
>   (`k8s-cluster-operator`); pod-crash triage → `k8s-workload-troubleshooter`.
> - Security / IRSA / Workload-Identity hardening *strategy* → `kubernetes-security`.
> - Agentic MCP tool-belt + blast-radius doctrine → `agentic-k8s-ops`.
> This skill owns **Karpenter install + NodePool/NodeClass design + disruption +
> troubleshooting on EKS and AKS**.

> **Version gate (read first).** Karpenter's core + AWS APIs are **v1 GA**
> (`karpenter.sh/v1`, `karpenter.k8s.aws/v1`); the Azure `AKSNodeClass` is
> **`karpenter.azure.com/v1beta1`**. Both release lines move quickly and **AKS NAP
> is evolving**. **State behavior, pin no version number in configs, and verify flags
> / feature gates / image families / NAP limitations against `karpenter.sh/docs` and
> Microsoft Learn (`learn.microsoft.com/azure/aks/node-auto-provisioning`) before
> relying on them.**

---

## CORE PRINCIPLES (NON-NEGOTIABLE)

1. **Provision from pod intent, not node groups.** Karpenter's input is *pending pods*.
   You describe the *bounds* of acceptable nodes (a `NodePool`) and the *cloud shape*
   (a NodeClass — `EC2NodeClass` on AWS, `AKSNodeClass` on Azure); Karpenter picks the
   VM. Don't recreate ASG / Agent-Pool-per-shape thinking — it throws away bin-packing.
2. **Learn the split: core API is portable, the NodeClass is cloud-specific.** A
   `NodePool` written for AWS mostly ports to Azure — you swap the `karpenter.k8s.aws/*`
   requirement keys for `karpenter.azure.com/sku-*` and point `nodeClassRef` at an
   `AKSNodeClass`. Everything in `spec.disruption`, `limits`, `weight`, `expireAfter`,
   `capacity-type`, `minValues` is identical.
3. **Keep NodePools flexible.** Many instance families/SKU families + `minValues` so
   spot diversity and consolidation have options. A pool locked to one type can't get
   spot resilience or consolidate cheaper — true on both clouds.
4. **Consolidation is cost control — tune it, don't disable it.** `WhenEmptyOrUnderutilized`
   + a `consolidateAfter` matched to churn, rate-limited by **disruption budgets**.
5. **Use each cloud's least-privilege identity.** AWS: least-privilege node role +
   **IMDSv2** (`httpTokens: required`, hop 1) + Pod Identity/IRSA for the controller.
   Azure: **Workload Identity** (managed identity + federated credential + OIDC) — never
   a service principal (NAP forbids it).
6. **Handle interruptions.** AWS: wire the **SQS interruption queue** so Karpenter acts
   on the 2-minute spot warning + health events. Azure **NAP** handles interruption in
   the managed control plane — but self-hosted Azure Karpenter still needs it configured.
7. **Pin/track node images deliberately.** AWS: pin `amiSelectorTerms` by version/id
   (floating alias = silent fleet drift). Azure/NAP: node images track the control-plane
   version and auto-upgrade channel — set an auto-upgrade channel + maintenance window.
8. **Drift is your reconvergence signal.** Change a NodePool/NodeClass field → nodes are
   marked drifted → Karpenter rolls them, budget-permitting. Manage with budgets.
9. **Observe before you tune**, and treat the **`karpenter.sh/termination` finalizer**
   as load-bearing — bulk force-removal skips drain and is break-glass only.

---

## TRIAGE MAP — symptom → where to look

| Symptom | First look | Phase |
|---|---|---|
| Pods `Pending`, no node appears | controller/NAP logs; NodePool `limits`; requirements vs pod | B / F |
| `no instance type met the scheduling requirements` | pod requests vs SKU/instance sizes; zone; capacity-type | B / F |
| Node launches then `NotReady` | AWS: aws-auth/access-entry, SG, CNI · Azure: CNI Overlay/Cilium, WI | F |
| (AWS) node created then terminates immediately | KMS key policy for encrypted EBS root | F |
| Nodes won't consolidate / deprovision | init state, PDBs, `do-not-disrupt`, budgets | D / F |
| (AWS) spot double-drain | NTH vs Karpenter interruption conflict | D / F |
| (Azure) can't enable NAP | cluster autoscaler present, Windows/IPv6/kubenet, service principal | A / F |
| (Azure) can't disable NAP | `limits.cpu` not `0`, NAP nodes still present | A / F |
| `strict decoding error: unknown field` | CRD vs controller/provider version skew | A / F |
| Fleet too big / too costly | consolidation policy, `consolidateAfter`, `minValues` | B / D |

---

## PHASE A — Install / identity

### A-AWS · EKS (self-hosted Karpenter)
Two IAM roles: a **controller role** (EC2/pricing/SQS/EKS) and a **node role**
(`KarpenterNodeRole-<cluster>`). The Getting Started **CloudFormation** stack creates
both + the SQS interruption queue + EventBridge rules.
```bash
aws cloudformation deploy --stack-name "Karpenter-${CLUSTER_NAME}" \
  --template-file cloudformation.yaml --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides "ClusterName=${CLUSTER_NAME}"
aws iam create-service-linked-role --aws-service-name spot.amazonaws.com || true
aws eks create-access-entry --cluster-name "${CLUSTER_NAME}" \
  --principal-arn "arn:aws:iam::${AWS_ACCOUNT_ID}:role/KarpenterNodeRole-${CLUSTER_NAME}" \
  --type EC2_LINUX
helm upgrade --install karpenter-crd oci://public.ecr.aws/karpenter/karpenter-crd \
  --version "${KARPENTER_VERSION}" -n kube-system --create-namespace
helm upgrade --install karpenter oci://public.ecr.aws/karpenter/karpenter \
  --version "${KARPENTER_VERSION}" -n kube-system \
  --set "settings.clusterName=${CLUSTER_NAME}" \
  --set "settings.interruptionQueue=${CLUSTER_NAME}" --wait
```
Controller identity: **Pod Identity** (recommended) or **IRSA**. CRD chart first, then
controller (skew → `unknown field`). Karpenter can't provision its own nodes — run it
on a small MNG/Fargate with room for 2 replicas.

### A-AZURE · AKS Node Auto Provisioning (managed — recommended)
NAP deploys and manages Karpenter + the Azure provider for you. It **requires Azure CNI
Overlay + Cilium** and a Standard Load Balancer.
```bash
# New cluster with NAP:
az aks create -n "$CLUSTER_NAME" -g "$RESOURCE_GROUP" \
  --node-provisioning-mode Auto \
  --network-plugin azure --network-plugin-mode overlay --network-dataplane cilium \
  --generate-ssh-keys
# Existing cluster:
az aks update -n "$CLUSTER_NAME" -g "$RESOURCE_GROUP" --node-provisioning-mode Auto
```
- `--node-provisioning-default-pools Auto|None` controls whether NAP creates the default
  `NodePool` + a `system-surge` pool (`Auto`) or nothing (`None` — you define your own).
- Identity: system- or user-assigned **managed identity** (service principals are
  unsupported). **AKS Automatic** ships NAP preconfigured with a pod-readiness SLA.
- Kubernetes upgrades: NAP nodes follow the control-plane version — set an auto-upgrade
  channel + planned maintenance window.

### A-AZURE · self-hosted Azure Karpenter provider (advanced)
Install the open-source Azure provider Helm chart yourself with **Workload Identity**
(managed identity + federated credential + OIDC issuer). You own upgrades, token
rotation, and OS-disk updates. Prefer NAP unless you need bleeding-edge/custom builds.

---

## PHASE B — NodePool + scheduling (shared core API)

The `NodePool` (`karpenter.sh/v1`) is identical across clouds except the cloud
requirement keys and the `nodeClassRef` target.

```yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: default
spec:
  template:
    spec:
      nodeClassRef:
        group: karpenter.k8s.aws          # Azure: karpenter.azure.com
        kind: EC2NodeClass                 # Azure: AKSNodeClass
        name: default
      requirements:
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64"]
        - key: karpenter.sh/capacity-type  # spot + on-demand (both clouds)
          operator: In
          values: ["spot", "on-demand"]
        # --- AWS keys ---
        - key: karpenter.k8s.aws/instance-category
          operator: In
          values: ["c", "m", "r"]
          minValues: 2
        # --- Azure equivalent (swap the block) ---
        # - key: karpenter.azure.com/sku-family
        #   operator: In
        #   values: ["D", "F"]
        #   minValues: 2
      expireAfter: 336h                     # AWS default 720h; NAP default "Never"
  limits:
    cpu: "1000"
  weight: 50
  disruption:
    consolidationPolicy: WhenEmptyOrUnderutilized
    consolidateAfter: 1m
```

- **AWS requirement keys:** `karpenter.k8s.aws/instance-family|category|generation|cpu|memory|hypervisor|gpu-*`; instance types via `node.kubernetes.io/instance-type`.
- **Azure requirement keys:** `karpenter.azure.com/sku-family|sku-series|sku-name|sku-version|sku-cpu|sku-memory|sku-gpu-name|sku-gpu-count|sku-networking-accelerated|sku-storage-premium-capable`; NAP also honors `kubernetes.azure.com/*` labels. **NAP prioritizes Spot when both spot + on-demand are listed.**
- **Shared:** `minValues`, `weight`, `limits` (cpu/memory/`nodes`), `expireAfter`,
  taints/`startupTaints`, and **static pools** via `replicas` + `limits.nodes`.
- Pods steer placement via `nodeSelector`/affinity/`topologySpreadConstraints`/requests;
  Karpenter bin-packs on **requests** — enforce minimums with a `LimitRange`.

---

## PHASE C — NodeClass (the cloud shape)

### C-AWS · EC2NodeClass (`karpenter.k8s.aws/v1`)
```yaml
apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: default
spec:
  role: "KarpenterNodeRole-${CLUSTER_NAME}"     # OR instanceProfile:
  amiSelectorTerms:
    - alias: al2023@v20240807                    # PIN the version in prod
  subnetSelectorTerms:
    - tags: { karpenter.sh/discovery: "${CLUSTER_NAME}" }
  securityGroupSelectorTerms:
    - tags: { karpenter.sh/discovery: "${CLUSTER_NAME}" }
  metadataOptions:
    httpTokens: required                         # IMDSv2
    httpPutResponseHopLimit: 1
  blockDeviceMappings:
    - deviceName: /dev/xvda
      ebs: { volumeSize: 100Gi, volumeType: gp3, encrypted: true }
  kubelet:
    maxPods: 110
```
Key fields: `amiFamily` + `amiSelectorTerms` (alias/id/name/owner/tags/ssmParameter),
`role` vs `instanceProfile`, `blockDeviceMappings` (gp3/encrypted/KMS), IMDSv2
`metadataOptions`, `kubelet`, `userData`, `tags`; status conditions
(`Ready`/`SubnetsReady`/`SecurityGroupsReady`/`AMIsReady`/`InstanceProfileReady`).

### C-AZURE · AKSNodeClass (`karpenter.azure.com/v1beta1`)
```yaml
apiVersion: karpenter.azure.com/v1beta1
kind: AKSNodeClass
metadata:
  name: default
spec:
  imageFamily: Ubuntu2204                        # or AzureLinux
  osDiskSizeGB: 128
  maxPods: 250
  kubelet:
    cpuManagerPolicy: static
  tags:
    team: platform
```
Key fields: `imageFamily` (`Ubuntu2204` / `AzureLinux`), `osDiskSizeGB`, `maxPods`,
`kubelet` config, `tags`. There is **no** subnet/SG/AMI selector or IAM `role` field —
the subnet, identity, and base image come from the AKS cluster + NAP; node images are
managed (auto-upgraded), not pinned by selector.

---

## PHASE D — Disruption (shared engine)

Graceful (budget-limited, replacement-first): **Consolidation**, **Drift**. Forceful
(immediate): **Expiration**, **Interruption**, **Node Repair** (AWS feature gate).

- **Consolidation** — `WhenEmpty` (only zero-pod nodes) vs `WhenEmptyOrUnderutilized`
  (also repacks after `consolidateAfter`); empty → multi-node → single-node. AWS spot
  single-node consolidation needs ≥15 instance-type flexibility.
- **Drift** — NodePool `requirements` + NodeClass selector/spec changes roll nodes.
- **Interruption** — AWS: SQS events (spot 2-min, health, stop/terminate) with a
  simultaneous replacement; **publishes but doesn't act on** spot *rebalance* (that's
  NTH's job — don't run both draining). Azure NAP: interruption handled by the managed
  control plane.
- **Disruption budgets** (identical YAML both clouds):
```yaml
spec:
  disruption:
    consolidationPolicy: WhenEmptyOrUnderutilized
    consolidateAfter: 30s
    budgets:
      - nodes: "10%"
      - nodes: "0"
        schedule: "0 17 * * mon-fri"     # cron is UTC
        duration: 15h
        reasons: ["Underutilized", "Drifted"]
```
  `nodes` as %/count (most-restrictive wins), `reasons` (`Empty`/`Underutilized`/`Drifted`),
  `schedule`+`duration` together. **Budgets do NOT gate Expiration/Interruption.**
- **Controls:** `karpenter.sh/do-not-disrupt` (pod/node, bool/duration) excludes from
  Consolidation+Drift; blocking PDB (`maxUnavailable: 0`) blocks eviction;
  `terminationGracePeriod` caps drain and lets Drift proceed past blocking PDBs once
  expired.

### Disabling NAP (Azure-specific procedure)
NAP won't turn off while it owns nodes. Order matters:
1. Set `spec.limits.cpu: 0` on **every** NodePool (stops new nodes).
2. Add taint `karpenter.azure.com/disable:NoSchedule` to every NodePool (migrates
   workloads to fixed pools, honoring PDBs).
3. Scale up / add fixed AgentPools to absorb the load; NAP nodes drain.
4. Once `kubectl get nodes -l karpenter.sh/nodepool` is empty:
   `az aks update -n "$CLUSTER_NAME" -g "$RESOURCE_GROUP" --node-provisioning-mode Manual`.

---

## PHASE E — Observability

- **AWS (self-hosted):** scrape the controller (`METRICS_PORT` 8080). Key metrics:
  `karpenter_nodeclaims_created_total`/`_terminated_total`,
  `karpenter_pods_startup_duration_seconds`, `karpenter_scheduler_queue_depth`,
  `karpenter_nodepools_usage` vs `_limit`, `karpenter_nodepools_allowed_disruptions`,
  `karpenter_voluntary_disruption_decisions_total`/`_eligible_nodes`,
  `karpenter_interruption_received_messages_total`, `karpenter_cluster_state_synced`
  (want `1`), `controller_runtime_reconcile_errors_total`.
- **Azure NAP:** Karpenter runs in the **managed control plane**. Enable **control-plane
  logs** and query in Log Analytics:
```kusto
AKSControlPlane
| where Category == "karpenter-events"
```
  Live events: `kubectl get events --field-selector source=karpenter-events`. Karpenter
  control-plane **metrics** via the Azure Monitor managed Prometheus add-on.
- **Both:** `kubectl get nodeclaims`, NodePool/NodeClass `status.conditions`.

---

## PHASE F — Troubleshooting

**Pods pending / no node (both):** `no instance type met the scheduling requirements`
→ requests too big for allowed SKUs/instances, zone/AZ mismatch, NodePool at `limits`,
or DaemonSet requests exceed allowed types. Widen requirements / raise limits.

**AWS-specific:**
- Node joins then `NotReady` → node role missing from access entry/`aws-auth`; CNI perms.
- Node created → terminates immediately → KMS key policy for encrypted EBS root.
- CNI can't assign IPs → prefix delegation, `maxPods`, `RESERVED_ENIS`, subnet CIDR.
- Controller `i/o timeout` at startup → chart `dnsPolicy: Default`.
- Stuck pricing in isolated subnet → `AWS_ISOLATED_VPC=true`.

**Azure/NAP-specific:**
- Can't **enable** NAP → cluster has the **cluster autoscaler** (mutually exclusive),
  or uses Windows / IPv6 / Kubenet / Calico / a **service principal** (all unsupported),
  or a Basic Load Balancer in a custom VNet (needs Standard).
- Can't **disable** NAP → a NodePool still has `limits.cpu != 0` or NAP nodes remain
  (`kubectl get nodes -l karpenter.sh/nodepool`).
- Nodes not provisioning → confirm Azure-CNI-Overlay + Cilium; check control-plane
  `karpenter-events` logs; verify Workload Identity federation (self-hosted).
- **Migration data-loss trap:** deleting the `karpenter.azure.com` CRDs removes the
  underlying NodeClaims → deletes nodes. Never delete the CRDs during migration.

**Both:** `strict decoding error: unknown field` → CRD vs controller/provider skew
(upgrade the CRD to match). Won't-deprovision → init state / `do-not-disrupt` / blocking
PDB / infeasible simulation / a `nodes: 0` budget — use `tools/disruption-blockers.sh`.

**Break-glass — stuck `karpenter.sh/termination` finalizers** (only after confirming the
VMs are actually gone; skips graceful drain — never routine):
```bash
kubectl get nodes -ojsonpath='{range .items[*].metadata}{@.name}:{@.finalizers}{"\n"}' \
  | grep "karpenter.sh/termination" | cut -d ':' -f 1 \
  | xargs -r kubectl patch node --type=json \
      -p='[{"op":"remove","path":"/metadata/finalizers"}]'
```

---

## PHASE G — Migration

- **Cluster Autoscaler → Karpenter (both clouds):** run both, create a covering NodePool
  + NodeClass, scale CA to 0, translate node groups/AgentPools into NodePool requirements,
  then remove CA. (On AKS, NAP and the cluster autoscaler are mutually exclusive.)
- **Self-hosted Azure Karpenter → NAP:** upgrade to the latest provider first, then
  **without deleting the CRDs**:
```bash
# 1. Detach CRDs from Helm so uninstall doesn't remove them (and delete NodeClaims):
kubectl get crds -l app.kubernetes.io/managed-by=Helm -o name | grep karpenter.azure.com \
  | xargs -I{} kubectl patch {} --type=json -p \
  '[{"op":"remove","path":"/metadata/annotations/meta.helm.sh~1release-name"},
    {"op":"remove","path":"/metadata/annotations/meta.helm.sh~1release-namespace"},
    {"op":"remove","path":"/metadata/labels/app.kubernetes.io~1managed-by"}]'
# 2. Remove the self-hosted controller:
helm uninstall karpenter -n kube-system
# 3. Enable NAP, keeping your existing NodePools:
az aks update -n "${CLUSTER_NAME}" -g "${RESOURCE_GROUP}" \
  --node-provisioning-mode Auto --node-provisioning-default-pools None
```

---

## ANTI-PATTERNS (each one bites)

| Anti-pattern | Why it breaks | Do instead |
|---|---|---|
| NodePool locked to one instance/SKU type | no spot diversity, can't consolidate cheaper | broad families + `minValues` (both clouds) |
| (AWS) floating AMI alias (`@latest`) in prod | upstream AMI release silently rolls fleet | pin `alias@<version>` / id / tags |
| (Azure) expecting to pin node images by selector | NAP images are managed/auto-upgraded | set auto-upgrade channel + maintenance window |
| Disabling consolidation | standing cost regression | `WhenEmptyOrUnderutilized` + budgets |
| (AWS) spot NodePool with no SQS queue | misses the 2-min warning → hard kills | wire SQS + `settings.interruptionQueue` |
| (AWS) NTH **and** Karpenter interruption on spot | double-drain / rebalance loop | Karpenter for interruption; disable NTH draining |
| (AWS) IMDSv1 (`httpTokens: optional`, hop >1) | pods can steal node-role creds | `httpTokens: required`, hop 1 |
| (Azure) NAP with cluster autoscaler / Windows / IPv6 / Kubenet / service principal | unsupported → enable fails | CNI-Overlay+Cilium, managed identity, Linux |
| (Azure) deleting `karpenter.azure.com` CRDs during migration | removes NodeClaims → deletes nodes | detach Helm labels; never delete CRDs |
| Force-removing finalizers as routine | skips drain, can orphan VMs | fix the real blocker; finalizer removal is break-glass |
| Upgrading controller without the CRD chart | `unknown field` / schema skew | CRD first, then controller, per release notes |

---

## PRE-DONE VERIFICATION CHECKLIST

**Install / identity**
- [ ] AWS: controller (Pod Identity/IRSA) + least-privilege node role mapped via access entry; SQS wired for spot; `karpenter-crd` matches controller.
- [ ] Azure: NAP enabled (`--node-provisioning-mode Auto`) on CNI-Overlay+Cilium with a managed identity — or self-hosted provider on Workload Identity; no cluster autoscaler.

**NodePool / NodeClass**
- [ ] Requirements broad + `minValues`; `nodeClassRef` resolves; correct cloud req keys.
- [ ] AWS: EC2NodeClass `*Ready`, AMI pinned, IMDSv2, encrypted root. Azure: AKSNodeClass `imageFamily`/`osDiskSizeGB`/`maxPods` set.

**Disruption / observability**
- [ ] `consolidationPolicy` + `consolidateAfter` set; budgets pace drift/consolidation.
- [ ] AWS: `karpenter_*` scraped, `cluster_state_synced == 1`. Azure: control-plane `karpenter-events` logs enabled.
- [ ] Critical workloads have PDBs and/or `do-not-disrupt`; `terminationGracePeriod` set.

**Doctrine**
- [ ] No version pinned in prose; behavior verified against karpenter.sh + Microsoft Learn.

---

## REFERENCE

### Requirement keys (one line)
Shared: `kubernetes.io/arch|os`, `topology.kubernetes.io/zone`, `karpenter.sh/capacity-type`.
AWS: `node.kubernetes.io/instance-type`, `karpenter.k8s.aws/instance-family|category|generation|cpu|memory|gpu-*`.
Azure: `karpenter.azure.com/sku-family|sku-series|sku-name|sku-version|sku-cpu|sku-memory|sku-gpu-*|sku-networking-accelerated|sku-storage-premium-capable`.

### Install one-liners
AWS: `helm upgrade --install karpenter oci://public.ecr.aws/karpenter/karpenter …` (+ karpenter-crd, CFN IAM, SQS).
Azure NAP: `az aks create/update … --node-provisioning-mode Auto --network-plugin azure --network-plugin-mode overlay --network-dataplane cilium`.

### NodeClass (one line)
AWS `EC2NodeClass` (`karpenter.k8s.aws/v1`): AMI/subnet/SG/role/disks/IMDSv2/kubelet.
Azure `AKSNodeClass` (`karpenter.azure.com/v1beta1`): imageFamily/osDiskSizeGB/maxPods/kubelet/tags.

### Read-only triage scripts (`tools/`)
`karpenter-health.sh` (controller/NAP + CRDs + NodePool/NodeClass/NodeClaim conditions,
both clouds) · `disruption-blockers.sh` (do-not-disrupt / blocking PDBs / disrupted
taint) · `nodepool-capacity.sh` (limits vs usage, nodes by capacity-type/instance-type).

---

## MCP SURFACE (read-only)

No official Karpenter MCP server — do not wire a fabricated one. Drive existing,
guardrailed servers **read-only**, per the blast-radius doctrine in `agentic-k8s-ops`:

| Server | Use | Guardrail |
|---|---|---|
| **kubernetes-mcp-server** (`--read-only`) | inspect `NodePool` / `EC2NodeClass` / `AKSNodeClass` / `NodeClaim` / node conditions + events (both clouds) | `--read-only` |
| **AWS MCP Server** | EKS: EC2 / SQS / pricing context | AWS RBAC (no global read-only flag) |
| **Azure MCP Server** | AKS: cluster / VM / NAP context, Log Analytics `karpenter-events` (KQL) | Entra RBAC + managed identity |

Default-deny writes — remediation (apply a NodePool, delete a node, `az aks update`)
lands as a **gated GitOps PR / approved change**, never a direct agent mutation. Node
mutations are high-blast-radius (they launch/terminate cloud VMs) — keep the agent
read-mostly and put a human on the Act step.

---

## SUBAGENT ORCHESTRATION

This skill drives a **5-agent Karpenter team** in `.claude/agents/` (cloud-agnostic —
each covers both providers):

| Agent | Owns |
|---|---|
| `karpenter-nodepool-designer` | NodePool + scheduling requirements (AWS `instance-*` / Azure `sku-*`), capacity types, `minValues`, weight/limits, static pools, consolidation policy |
| `karpenter-nodeclass-author` | `EC2NodeClass` (AWS) **and** `AKSNodeClass` (Azure) — image, disks, identity/metadata, kubelet |
| `karpenter-disruption-operator` | consolidation/drift/expiration/interruption, budgets, do-not-disrupt, terminationGracePeriod, PDB interplay, NTH conflict, NAP disable |
| `karpenter-installer` | EKS (helm/CFN/Pod-Identity/IRSA/SQS) + AKS (NAP `az` enable/disable, self-hosted provider + Workload Identity), CA & self-hosted→NAP migration |
| `karpenter-troubleshooter` | the Phase-F trees (AWS + Azure/NAP); owns the `tools/` scripts |

**Handoffs:** generic HPA/VPA/KEDA + Cluster Autoscaler → `k8s-autoscaling-engineer`;
cluster upgrades / scheduling / node maintenance → `k8s-cluster-operator`; pod-crash
triage → `k8s-workload-troubleshooter`; security / IRSA / Workload-Identity hardening →
the `k8s-*` security agents; agentic MCP tool-belt + blast-radius → `agentic-k8s-ops`.
