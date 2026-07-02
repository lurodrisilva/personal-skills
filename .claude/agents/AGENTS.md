<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-28 | Updated: 2026-07-02 -->

# agents

## Purpose
Committed **Claude Code subagent definitions** — focused agents that skills in
this repo delegate phase work to. Each file is a Markdown document with YAML
frontmatter (`name`, `description`, `tools`, `model`) followed by the agent's
system prompt. Agents are grouped into **per-skill teams**, each driven by that
skill's "Subagent Orchestration" table:
- **operator-development team** → `platform-engineering/kubernetes-operator-golang/SKILL.md`
- **Crossplane team** → `platform-engineering/crossplane/SKILL.md`
- **Dynatrace team** → `platform-engineering/dynatrace/SKILL.md`
- **Kubernetes-operations team** → `operations/kubernetes-operations/SKILL.md`
- **Kubernetes-security team** → `security/kubernetes-security/SKILL.md`
- **Kubernetes-networking team** → `networking/kubernetes-networking/SKILL.md`
- **Azure-SRE-Agent team** → `operations/azure-sre-agent/SKILL.md`
- **Karpenter-EKS team** → `operations/karpenter-eks/SKILL.md`

## Key Files
| File | Team | Description |
|------|------|-------------|
| `operator-scaffolder.md` | operator | `kubebuilder`/`operator-sdk` `init`/`create api`/`create webhook`, PROJECT, Makefile, go/v4 layout |
| `crd-api-designer.md` | operator | `*_types.go`, kubebuilder markers, OpenAPI + CEL, `status.conditions`, versioning (model=opus for complex schemas) |
| `reconciler-author.md` | operator | Reconcile loop, finalizers, `CreateOrUpdate`, owner refs, status, requeue, watches, webhooks, manager, RBAC (model=opus for non-trivial loops) |
| `olm-packager.md` | operator | OLM bundle, `ClusterServiceVersion`, `opm` File-Based Catalogs, dependency resolution, OLM v0/v1 |
| `operator-tester.md` | operator | envtest + Ginkgo/Gomega, table-driven unit tests, idempotency + chaos/e2e |
| `crossplane-composition-author.md` | crossplane | XRDs, Compositions (Pipeline), function pipelines, EnvironmentConfigs (model=opus for complex APIs) |
| `crossplane-managed-resource-author.md` | crossplane | Managed Resources, `managementPolicies`/`deletionPolicy`, ProviderConfig refs, importing existing resources |
| `crossplane-package-publisher.md` | crossplane | Provider/Configuration/Function packages, `crossplane.yaml`, `xpkg build/push`, ImageConfig signing |
| `crossplane-control-plane-operator.md` | crossplane | install, Providers, credentials/workload identity, GitOps (ArgoCD/Flux) delivery, troubleshooting |
| `crossplane-tester.md` | crossplane | `crossplane render`/`validate`/`beta trace`, CI gate |
| `dynatrace-api-client.md` | dynatrace | plane/credential selection, tokens, Environment API v2, Settings 2.0, `nextPageKey` pagination, rate limits |
| `dynatrace-dql-author.md` | dynatrace | DQL/Grail pipelines, `timeseries`, the `query:execute`/`poll` API, `storage:*` scopes (model=opus for complex queries) |
| `dynatrace-otel-ingest-engineer.md` | dynatrace | OTLP ingest, the Dynatrace Collector distro, delta temporality, enrichment |
| `dynatrace-cloud-integrator.md` | dynatrace | `da-aws` connector, role + ExternalId, CloudFormation, monitoring-config API, legacy migration |
| `dynatrace-monitoring-as-code.md` | dynatrace | Terraform provider + Monaco, Settings-2.0/dashboards/SLOs/alerting as code, GitOps |
| `k8s-workload-troubleshooter.md` | k8s-ops | Pod-failure decision trees (CrashLoopBackOff/OOMKilled/Pending), rollouts, probes, graceful shutdown, `kubectl debug`, log/event triage |
| `k8s-cluster-operator.md` | k8s-ops | resources/QoS, scheduling/placement, eviction, PDB/drain/cordon, version-skew upgrades, node maintenance |
| `k8s-autoscaling-engineer.md` | k8s-ops | HPA (`autoscaling/v2`)/VPA/Cluster-Autoscaler/Karpenter/KEDA, metrics-server, capacity & cost |
| `k8s-security-rbac.md` | k8s-ops | RBAC least-privilege, `auth can-i`, SA bound tokens, Pod Security Admission, `securityContext` hardening |
| `k8s-network-storage.md` | k8s-ops | Services/EndpointSlices/DNS/NetworkPolicy/Ingress-Gateway + PV/PVC/StorageClass/CSI; reachability & PVC-pending trees |
| `k8s-cluster-hardener.md` | k8s-security | control plane / kubelet / node hardening, etcd encryption, secrets stores, CIS / kube-bench, audit logging |
| `k8s-rbac-iam-auditor.md` | k8s-security | least-privilege RBAC, dangerous verbs (escalate/bind/impersonate), SA tokens, OIDC/Entra, multi-tenancy |
| `k8s-supplychain-admission.md` | k8s-security | scan/sign/SLSA, PSA + securityContext, ValidatingAdmissionPolicy / Gatekeeper / Kyverno, CI policy-as-code |
| `k8s-network-zerotrust.md` | k8s-security | default-deny NetworkPolicy, Calico/Cilium microsegmentation, mTLS/mesh, egress control |
| `k8s-runtime-threat.md` | k8s-security | Falco/Tetragon (eBPF) detection+enforcement, drift prevention, CNAPP, incident response |
| `k8s-network-fundamentals.md` | k8s-networking | the K8s network model, CNI mechanics, Services/kube-proxy/EndpointSlices, CoreDNS, dual-stack |
| `calico-architect.md` | k8s-networking | Calico components (Felix/BIRD/confd/Typha), dataplanes (eBPF/iptables/nftables/VPP), Tigera operator install, datastore |
| `calico-ipam-bgp.md` | k8s-networking | IP pools/IPAM/borrowing, BGP peering/RR/service-IP advertisement, overlay-vs-native encapsulation (model=opus for complex BGP) |
| `calico-policy-author.md` | k8s-networking | `NetworkPolicy`/`GlobalNetworkPolicy` (`projectcalico.org/v3`) mechanics, `action`/`order`/tiers, host endpoints, network sets |
| `calico-troubleshooter.md` | k8s-networking | `calicoctl` node/BGP/IPAM status, route/MTU/connectivity, eBPF enablement, Typha scale |
| `azure-sre-rca.md` | azure-sre-agent | incident root-cause hypothesis + **proposed** gated mitigation (never auto-applies); `opus` |
| `azure-sre-observability.md` | azure-sre-agent | App Insights / Log Analytics (KQL) / Grafana / Dynatrace-DQL signal gathering + correlation (read-only) |
| `azure-sre-sourcecode.md` | azure-sre-agent | deploy/release/config-change correlation across GitHub / Azure DevOps (read-only) |
| `azure-sre-architecture.md` | azure-sre-agent | resource topology + dependency + blast-radius mapping (read-only) |
| `azure-sre-scanning.md` | azure-sre-agent | scheduled security / compliance / drift sweeps (read-only) |
| `karpenter-nodepool-designer.md` | karpenter | NodePool + scheduling requirements, capacity types, `minValues`, weight/limits, consolidation-policy choice |
| `karpenter-nodeclass-author.md` | karpenter | EC2NodeClass — AMI alias pinning, subnet/SG tag discovery, `role`/`instanceProfile`, `blockDeviceMappings`, IMDSv2, kubelet, userData |
| `karpenter-disruption-operator.md` | karpenter | consolidation/drift/expiration/interruption, disruption budgets, `do-not-disrupt`, `terminationGracePeriod`, PDB interplay, NTH conflict |
| `karpenter-installer.md` | karpenter | helm install/upgrade, CloudFormation IAM, Pod Identity vs IRSA, SQS interruption queue, node-role access entry, CA migration |
| `karpenter-troubleshooter.md` | karpenter | Phase-F trees (not provisioning / NotReady / won't-deprovision / CNI IP / finalizer); owns the read-only `tools/` scripts |

## Subdirectories
None.

## For AI Agents

### Working In This Directory
- One subagent per file; the frontmatter `name` MUST match the filename stem
  (e.g. `reconciler-author.md` → `name: reconciler-author`).
- Required frontmatter: `name`, `description` (when to invoke + hand-off
  boundaries), `tools` (comma-separated allow-list), `model` (`sonnet` default;
  `crd-api-designer` and `reconciler-author` note `opus` for complex work).
- Every subagent's prompt **anchors to its team's skill** and enforces that
  skill's CORE PRINCIPLES (and, for Crossplane, the VERSION MAP) — it does not
  restate the whole skill. Keep each agent's scope to its phase(s) and its explicit
  "what you do NOT do" hand-offs so each team stays composable (operator:
  scaffolder → designer → reconciler → tester → packager; crossplane:
  control-plane-operator → managed-resource-author → composition-author →
  package-publisher → tester; dynatrace: api-client → {dql-author |
  otel-ingest-engineer | cloud-integrator} → monitoring-as-code; k8s-ops:
  workload-troubleshooter → {cluster-operator | autoscaling-engineer |
  security-rbac | network-storage}; k8s-security: threat-model → {cluster-hardener
  | rbac-iam-auditor | supplychain-admission | network-zerotrust |
  runtime-threat}, layered for defense in depth; k8s-networking:
  network-fundamentals → calico-architect → {calico-ipam-bgp |
  calico-policy-author} → calico-troubleshooter; azure-sre-agent:
  {observability | architecture} → sourcecode → rca (proposes, gated) ; scanning
  on a schedule; karpenter: installer → {nodepool-designer | nodeclass-author} →
  disruption-operator → troubleshooter).
- These agents are **repo-scoped** (see `../AGENTS.md`). If you add an agent, also
  add it to the owning skill's Subagent Orchestration table and that skill dir's
  `AGENTS.md` "Companion Subagents" section; if you rename one, update both sides.

### Testing Requirements
- Not covered by `scripts/validate-skills.sh`. After editing, manually verify:
  1. YAML frontmatter parses (`yq`) and carries `name`, `description`, `tools`, `model`.
  2. `name` equals the filename stem.
  3. `model` is a valid tier and `tools` are real tool names.

### Common Patterns
- Body shape: a one-line role statement that points at the skill, a "What you do"
  list, a "What you do NOT do" hand-off list, and a "Done when" acceptance line.

## Dependencies

### Internal
- `../../platform-engineering/kubernetes-operator-golang/SKILL.md` — the contract
  the operator team reads first and enforces.
- `../../platform-engineering/crossplane/SKILL.md` — the contract the Crossplane
  team reads first and enforces.
- `../../platform-engineering/dynatrace/SKILL.md` — the contract the Dynatrace
  team reads first and enforces.
- `../../operations/kubernetes-operations/SKILL.md` — the contract the
  Kubernetes-operations team reads first and enforces.
- `../../security/kubernetes-security/SKILL.md` — the contract the
  Kubernetes-security team reads first and enforces.
- `../../networking/kubernetes-networking/SKILL.md` — the contract the
  Kubernetes-networking team reads first and enforces.
- `../../operations/azure-sre-agent/SKILL.md` — the contract the Azure-SRE-Agent
  team reads first and enforces (CORE PRINCIPLES + the propose-then-approve doctrine).
- `../../operations/karpenter-eks/SKILL.md` — the contract the Karpenter-EKS team
  reads first and enforces (CORE PRINCIPLES + the version/verify-upstream gate).

### External
- Claude Code subagent runtime (loads `tools` / `model` from frontmatter).

<!-- MANUAL: -->
