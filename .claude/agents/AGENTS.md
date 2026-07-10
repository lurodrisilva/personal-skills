<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-28 | Updated: 2026-07-07 -->

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
- **Karpenter team** → `operations/karpenter-operations/SKILL.md`
- **Azure-CLI team** → `platform-engineering/azure-cli/SKILL.md`
- **GitHub-CLI team** → `platform-engineering/github-cli/SKILL.md`
- **Azure-FinOps team** → `platform-engineering/azure-finops/SKILL.md`
- **AWS-FinOps team** → `platform-engineering/aws-finops/SKILL.md`
- **Kubernetes-FinOps team** → `operations/kubernetes-finops/SKILL.md`
- **Terraform-IaC team** → `platform-engineering/terraform-iac/SKILL.md`
- **GitOps-ArgoCD team** → `operations/gitops-argocd/SKILL.md`
- **Observability-Stack team** → `operations/observability-stack/SKILL.md`
- **Platform-Architect team** → `platform-engineering/platform-architect/SKILL.md`

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
| `azure-cli-auth-identity.md` | azure-cli | `az login` methods (interactive/SP/MI/OIDC), `create-for-rbac` least-privilege scoping, accounts/subscriptions/tenants, sovereign clouds; owns `az-identity-check.sh` |
| `azure-cli-query-output.md` | azure-cli | client-side JMESPath `--query` (multiselect list/hash, filter, functions, quoting traps) + the seven `-o` formats (tsv/table gotchas); owns `az-resource-inventory.sh` |
| `azure-cli-config-extensions.md` | azure-cli | `az config` + `AZURE_{SECTION}_{NAME}` env surface + precedence, extensions + dynamic install, install/upgrade, proxy (`REQUESTS_CA_BUNDLE`) / telemetry; owns `az-config-audit.sh` |
| `azure-cli-ci-automation.md` | azure-cli | `azure/login@v2` OIDC + CI hardening (`--only-show-errors`, telemetry off, pinned image), `--no-wait` + `az … wait` + `--ids @-`, exit codes |
| `azure-cli-mcp-and-discovery.md` | azure-cli | Azure MCP Server (`microsoft/mcp`, reuses `az login`, namespace/readOnly) + MCP-vs-`az` decision, `az find`/`interactive`/`next` discovery, `az rest` escape hatch |
| `github-cli-auth-identity.md` | github-cli | `gh auth` login methods (web/device/`--with-token`/`--hostname` GHES), token precedence (`GH_TOKEN`>`GITHUB_TOKEN`>keyring; `GH_ENTERPRISE_TOKEN`), PAT-vs-`GITHUB_TOKEN` / fine-grained-vs-classic, `setup-git`, multi-account `switch`; owns `gh-auth-check.sh` |
| `github-cli-api-scripting.md` | github-cli | `gh api` REST/GraphQL escape hatch (`-f` string vs `-F` typed, GET→POST, `--paginate`/`--slurp`), `--json`/`--jq`/`--template` output shaping, `gh search`, repo-context resolution; owns `gh-api-inventory.sh` |
| `github-cli-config-extensions.md` | github-cli | `gh config` + `GH_*` env surface + precedence, aliases (`$1`/`--shell`), extensions (install/`--pin`/supply-chain), completion, install/upgrade, exit codes (0/1/2/4), proxy; owns `gh-config-audit.sh` |
| `github-cli-dev-workflow.md` | github-cli | `repo`/`pr`/`issue`/`release`/`label`/`ruleset`/`gist` porcelain automation — PR create/`--fill`/merge `--squash --auto`, release `--generate-notes --verify-tag` + asset globs, `--json` scripting, `-R`/`GH_REPO` determinism |
| `github-cli-actions-ci.md` | github-cli | `workflow`/`run` (`watch --exit-status`/`rerun --failed`/`download`)/`secret` (libsodium, stdin, repo/env/org/`--app`)/`variable`/`cache`/`attestation` (SLSA/Sigstore) + gh-in-Actions `GH_TOKEN` + least-privilege `permissions:` |
| `github-cli-mcp-discovery.md` | github-cli | GitHub MCP Server (`github/github-mcp-server`, remote + local, toolsets, `--read-only`; already wired as the `github` plugin) + MCP-vs-`gh` decision, `gh <cmd> --help`/`gh reference` discovery |
| `karpenter-nodepool-designer.md` | karpenter | NodePool + scheduling requirements (AWS `instance-*` / Azure `sku-*`), capacity types, `minValues`, weight/limits, static pools, consolidation-policy choice (EKS+AKS) |
| `karpenter-nodeclass-author.md` | karpenter | `EC2NodeClass` (AMI alias pinning, subnet/SG discovery, role, IMDSv2) **and** `AKSNodeClass` (imageFamily, osDiskSizeGB, maxPods, kubelet) |
| `karpenter-disruption-operator.md` | karpenter | consolidation/drift/expiration/interruption, budgets, `do-not-disrupt`, `terminationGracePeriod`, PDB interplay, NTH conflict (AWS), NAP disable (Azure) |
| `karpenter-installer.md` | karpenter | EKS (helm/CloudFormation/Pod-Identity/IRSA/SQS) + AKS (NAP `az` enable/disable, self-hosted + Workload Identity), CA & self-hosted→NAP migration |
| `karpenter-troubleshooter.md` | karpenter | Phase-F trees for EKS + AKS/NAP (not provisioning / NotReady / won't-deprovision / CNI IP / NAP enable-disable / finalizer); owns the read-only `tools/` scripts |
| `finops-cost-allocator.md` | azure-finops | Inform — FOCUS exports/ingestion, cost tags + MG/subscription hierarchy, showback split, reporting; owns the allocatable-spend KPI |
| `finops-budget-forecaster.md` | azure-finops | Quantify — budgets + action groups, forecasting (±15%), planning/estimating, unit economics (incl. AI cost/token), anomaly management |
| `finops-usage-optimizer.md` | azure-finops | Optimize/usage — rightsizing, Advisor, ARG waste cleanup, autoscale/scheduling, storage tiering, AKS cost split; owns `azure-waste-finder.sh` |
| `finops-rate-optimizer.md` | azure-finops | Optimize/rate — Reservations vs Savings Plans vs Spot, Azure Hybrid Benefit, coverage 60–85% / utilization >90%; owns `azure-commitment-coverage.sh` |
| `finops-governance-lead.md` | azure-finops | Operate — Azure Policy guardrails (require-tag/deny-SKU/budgets), chargeback, practice cadence, maturity assessment |
| `aws-finops-cost-allocator.md` | aws-finops | Inform — Data Exports/FOCUS + CUR into S3/Athena/QuickSight, cost allocation tags + Cost Categories + Organizations, CID dashboards; owns the allocatable-spend KPI |
| `aws-finops-budget-forecaster.md` | aws-finops | Quantify — AWS Budgets + budget actions, forecasting (±15%), planning/estimating, unit economics (incl. Bedrock cost/token), Cost Anomaly Detection |
| `aws-finops-usage-optimizer.md` | aws-finops | Optimize/usage — Compute Optimizer + Cost Optimization Hub rightsizing, Trusted Advisor, waste cleanup, EKS SCAD split; owns `aws-waste-finder.sh` |
| `aws-finops-rate-optimizer.md` | aws-finops | Optimize/rate — Savings Plans vs RIs vs Spot, Graviton, coverage 60–85% / utilization >90%; owns `aws-commitment-coverage.sh` |
| `aws-finops-governance-lead.md` | aws-finops | Operate — SCPs / tag policies / budget-action guardrails, Billing Conductor chargeback, practice cadence, maturity assessment |
| `k8s-cost-allocator.md` | k8s-finops | Allocate — OpenCost/Kubecost, labels + namespaces, the allocated/idle/shared split, showback→chargeback; owns `k8s-cost-allocation.sh` |
| `k8s-rightsizer.md` | k8s-finops | Right-size — requests vs limits vs usage, QoS classes, p95/p99, VPA/Goldilocks/KRR; owns `k8s-rightsizing-scan.sh` |
| `k8s-cost-autoscaler.md` | k8s-finops | Scale & pack — HPA/VPA/KEDA scale-to-zero, bin-packing/descheduler, Spot/Arm64/SKU, node-capacity decision |
| `k8s-waste-hunter.md` | k8s-finops | Eliminate — idle nodes, unused PVCs/PVs, zombie Deployments/Services, completed Jobs; owns `k8s-idle-waste.sh` |
| `k8s-cost-governor.md` | k8s-finops | Govern — ResourceQuota/LimitRange, require-requests/labels admission policy, budgets/anomaly, chargeback, maturity |
| `terraform-module-author.md` | terraform-iac | Phase A — reusable modules (typed vars + `validation`, outputs, `for_each`/`dynamic`, `moved`), composition, module registry + version constraints |
| `terraform-state-operator.md` | terraform-iac | Phase B/F — remote backends + locking (S3+DynamoDB/azurerm/gcs/TFC), workspaces, `import`, `state mv`/`rm` safety, `plan -refresh-only` drift; owns `tf-state-inventory.sh` + `tf-drift-check.sh` |
| `terraform-provider-config.md` | terraform-iac | Phase C — `required_providers` + `.terraform.lock.hcl`, OIDC/assume-role/workload-identity auth (no static keys), provider `alias`, OIDC-in-CI |
| `terraform-plan-reviewer.md` | terraform-iac | Phase D — reading `plan` (adds/changes/**destroys**), `-detailed-exitcode`, OPA/Conftest/Sentinel policy-as-code, `prevent_destroy`/`-target` guard, gated apply; owns `tf-plan-summary.sh` |
| `terraform-iac-tester.md` | terraform-iac | Phase E — `validate`/`fmt -check`, tflint, tfsec/checkov/trivy, native `terraform test` (`.tftest.hcl`), terratest, CI gate |
| `argocd-application-author.md` | gitops-argocd | Phase A — `Application`/multi-source, `AppProject` tenancy, Helm/Kustomize/directory, app-of-apps; + Argo Rollouts / Image Updater promotion manifests |
| `argocd-sync-operator.md` | gitops-argocd | Phase B — sync policy (`prune`/`selfHeal`), sync waves, PreSync/Sync/PostSync/SyncFail hooks, sync options, gated prod sync; owns `argocd-sync-status.sh` |
| `argocd-drift-health.md` | gitops-argocd | Phase C — custom-Lua health, diff, `ignoreDifferences`, OutOfSync/Degraded/Missing triage, self-heal reconcile; owns `argocd-drift-check.sh` |
| `argocd-multicluster.md` | gitops-argocd | Phase D — `ApplicationSet` generators, cluster registration, RBAC + SSO tenancy, fan-out at scale; owns `argocd-app-health.sh` |
| `flux-gitops-operator.md` | gitops-argocd | Phase F — the Flux sibling (`GitRepository`/`Kustomization`/`HelmRelease`, controllers, Flagger), Argo-vs-Flux selection + migration |
| `prometheus-rules-author.md` | observability-stack | Phase A — PromQL, recording/alerting rules, `ServiceMonitor`/`PodMonitor`/`PrometheusRule`, relabeling, cardinality, Thanos/Mimir; owns `promtool-check.sh` |
| `otel-collector-engineer.md` | observability-stack | Phase B — Collector pipelines, OTLP, tail-sampling, `k8sattributes`, semantic conventions, instrumentation; owns `otel-config-validate.sh` |
| `loki-tempo-correlation.md` | observability-stack | Phase C — Loki/LogQL + Tempo/TraceQL, exemplars, trace↔log correlation, structured logging |
| `grafana-dashboard-author.md` | observability-stack | Phase D — dashboards-as-code (JSON/provisioning/grafana-operator/Terraform), RED/USE, variables, unified alerting |
| `slo-alerting-engineer.md` | observability-stack | Phase D/E — SLI/SLO/error-budget, Sloth/OpenSLO, multi-window burn-rate, Alertmanager routing; owns `alert-routing-check.sh` |
| `platform-strategy-advisor.md` | platform-architect | Phase A — platform-as-a-product, build-vs-buy, Wardley mapping, technology radar, capability roadmap, investment thesis (model=opus) |
| `platform-reference-architect.md` | platform-architect | Phase B — the five IDP planes, capability map, golden-path/paved-road design, plane→implementer delegation (model=opus) |
| `team-topologies-designer.md` | platform-architect | Phase C — team types, the three interaction modes (X-as-a-Service default), cognitive-load reduction, RACI, Conway's-law alignment |
| `developer-experience-lead.md` | platform-architect | Phase D — DORA four keys + SPACE + adoption/NPS scorecard, feedback loops; reads `dora-metrics-report.sh` |
| `governance-standards-author.md` | platform-architect | Phase E — ADR (MADR)/RFC, guardrails-not-gates, technology-radar governance, off-road exceptions; owns `adr-lint.sh` |
| `platform-maturity-assessor.md` | platform-architect | Phase F — CNCF maturity assessment (5 aspects × 4 levels), gap analysis, roadmap sequencing; owns `platform-maturity-scan.sh` (model=opus) |

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
  disruption-operator → troubleshooter; azure-finops: cost-allocator →
  budget-forecaster → {usage-optimizer | rate-optimizer, usage before rate} →
  governance-lead; aws-finops: cost-allocator → budget-forecaster →
  {usage-optimizer | rate-optimizer, usage before rate} → governance-lead;
  kubernetes-finops: cost-allocator → rightsizer →
  {cost-autoscaler | waste-hunter} → cost-governor; terraform-iac:
  provider-config → module-author → plan-reviewer → iac-tester → state-operator;
  gitops-argocd: application-author → sync-operator → drift-health → multicluster
  (flux-gitops-operator = the Flux sibling); observability-stack:
  otel-collector-engineer → prometheus-rules-author → loki-tempo-correlation →
  grafana-dashboard-author → slo-alerting-engineer).
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
- `../../operations/karpenter-operations/SKILL.md` — the contract the Karpenter team
  reads first and enforces (CORE PRINCIPLES + the EKS/AKS provider split + the
  version/verify-upstream gate).
- `../../platform-engineering/azure-finops/SKILL.md` — the contract the Azure-FinOps
  team reads first and enforces (CORE PRINCIPLES + allocate-before-optimize +
  usage-before-rate + the read-only-analysis / gated-action doctrine).
- `../../platform-engineering/aws-finops/SKILL.md` — the contract the AWS-FinOps
  team reads first and enforces (CORE PRINCIPLES + allocate-before-optimize +
  usage-before-rate + the read-only-analysis / gated-action doctrine).
- `../../operations/kubernetes-finops/SKILL.md` — the contract the Kubernetes-FinOps
  team reads first and enforces (CORE PRINCIPLES + allocate-before-optimize +
  requests-are-the-currency + the container allocated/idle/shared cost split).
- `../../platform-engineering/terraform-iac/SKILL.md` — the contract the Terraform-IaC
  team reads first and enforces (CORE PRINCIPLES + plan-before-apply +
  remote-state-with-locking + short-lived-least-privilege-auth + the
  read-only-analysis / gated-apply doctrine).
- `../../operations/gitops-argocd/SKILL.md` — the contract the GitOps-ArgoCD team reads
  first and enforces (CORE PRINCIPLES + Git-is-the-single-source-of-truth +
  gated-prod-sync + AppProject blast-radius).
- `../../operations/observability-stack/SKILL.md` — the contract the Observability-Stack
  team reads first and enforces (CORE PRINCIPLES + three-signals-one-context +
  alert-on-SLO-burn + everything-as-code + the read-only-to-observe doctrine).

### External
- Claude Code subagent runtime (loads `tools` / `model` from frontmatter).

<!-- MANUAL: -->
