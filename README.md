# personal-skills

[![Validate Skills](https://github.com/lurodrisilva/personal-skills/actions/workflows/validate-skills.yml/badge.svg)](https://github.com/lurodrisilva/personal-skills/actions/workflows/validate-skills.yml)
[![Skills](https://img.shields.io/badge/skills-25-blue)](#available-skills)

A collection of **Claude Code skills** -- comprehensive reference guides that Claude Code loads when working on projects matching specific technology patterns. Each skill encodes architectural rules, coding conventions, and framework-specific guidance for a technology stack.

## Available Skills

### AI

| Skill | Tool | Focus | Key Technologies |
|-------|------|-------|------------------|
| [graphify](ai/graphify/SKILL.md) | Graphify (`graphifyy` package → `graphify` command) | Codebase knowledge graph for AI coding assistants — build, query, serve, and maintain a queryable graph of code + docs + media | tree-sitter local AST (33+ languages, no API cost), SQL deterministic table/view/FK/JOIN extraction, faster-whisper transcription, Claude/LLM semantic extraction via parallel subagents, Leiden community detection, NetworkX node-link `graph.json` with `EXTRACTED`/`INFERRED`/`AMBIGUOUS` confidence, `/graphify` slash command + flags, `graphify-out/` artifacts (HTML viz, report, Obsidian, SVG), `.graphifyignore`, SHA256 incremental cache, headless `graphify extract --backend claude\|gemini\|ollama`, PR-impact (`graphify prs --triage`, AST-only git hooks + merge driver), MCP stdio server (`python -m graphify.serve`: `query_graph`/`get_node`/`get_neighbors`/`shortest_path`/`list_prs`/`get_pr_impact`/`triage_prs`), companion Docker MCP SQLite server (`mcp/sqlite`) |

### Coding

| Skill | Language / Framework | Architecture | Key Technologies |
|-------|---------------------|--------------|------------------|
| [golang-hex-clean](coding/golang-hex-clean/SKILL.md) | Go | Hexagonal / Clean | GoFiber, go-redis, OpenTelemetry, DDD, CQRS |
| [dotnet-hex-clean](coding/dotnet-hex-clean/SKILL.md) | .NET | Clean Architecture (Ardalis) | FastEndpoints, EF Core, Vogen, Mediator, DDD, CQRS |
| [create-makefiles](coding/create-makefiles/SKILL.md) | Language-agnostic | Unified task-runner | GNU Make best practices, per-language templates (Go, Node, Python, .NET, C/C++) |
| [dockerfile-instructions](coding/dockerfile-instructions/SKILL.md) | Language-agnostic | Container builds | BuildKit, multi-stage builds, size + build-time optimization, multi-arch (buildx, QEMU, TARGETPLATFORM), distroless, non-root |

### Platform Engineering

| Skill | Platform | Focus | Key Technologies |
|-------|----------|-------|------------------|
| [github-actions](platform-engineering/github-actions/SKILL.md) | GitHub Actions | CI/CD governance, supply-chain security | Workflow syntax, OIDC federation, SHA-pinning, script-injection prevention, dependency caching, artifact attestations (SLSA Build L3), Sigstore policy-controller |
| [addons-and-building-blocks](platform-engineering/addons-and-building-blocks/SKILL.md) | Kubernetes / AKS | Layered platform blueprints — baseline addons + reusable building blocks | Helm library charts (`myorg.*` / `plat-net.*`), OCI chart distribution (GHCR), ArgoCD App-of-Apps with sync waves, CloudNativePG, Crossplane managed resources, wrapper-chart helm-unittest, kubeconform, Terraform + Terratest AKS foundation |
| [wiremock-api-mocks](platform-engineering/wiremock-api-mocks/SKILL.md) | Kubernetes (`testing-system` namespace) | Shared, cluster-wide HTTP API mock server — one WireMock instance, many tenants, stubs declared in consumer Helm values | WireMock (Java) Helm addon, `myorg.wiremock.syncJob` library helper, `metadata.owner=<release>` atomic replace via Admin API, URL-prefix isolation `/__mocks__/<release>/`, NetworkPolicy + consumer-namespace label gating, `WireMock.Net` for in-process .NET unit tests |
| [kafka-strimzi-operator](platform-engineering/kafka-strimzi-operator/SKILL.md) | Kubernetes (any distro) | Apache Kafka on Kubernetes via Strimzi — KRaft-only, role-split node pools, capacity contracts that match what Cruise Control sees, perf-test playbook against the four limiting resources (CPU / network-in / network-out / log disk) | Strimzi Cluster + Topic + User Operators, `Kafka` / `KafkaNodePool` / `KafkaTopic` / `KafkaUser` / `KafkaRebalance` CRs, KRaft controller quorum, JBOD storage, `cruiseControl.brokerCapacity` mirrored 1:1 with `resources.limits`, JMX-exporter Prometheus metrics, Cruise Control optimisation goals, `Hex.Scaffold` consumer/producer integration |
| [kubernetes-operator-golang](platform-engineering/kubernetes-operator-golang/SKILL.md) | Kubernetes (any distro) | **Building** Kubernetes Operators in Go — scaffolding, CRD/API design, the level-based idempotent Reconcile loop, finalizers + owner refs + status conditions, admission webhooks, least-privilege RBAC, envtest, and OLM packaging. Orchestrated by 5 companion subagents in `.claude/agents/`. Encodes CNCF capability levels + the Seven Habits of Highly Successful Operators | kubebuilder (go/v4), Operator SDK, controller-runtime, `controllerutil` (`CreateOrUpdate` / `SetControllerReference` / finalizers), `controller-gen` markers, OpenAPI + CEL validation, `metav1.Condition` status, `CustomValidator` / `CustomDefaulter` webhooks, leader election, Prometheus `metrics.Registry`, Ginkgo/Gomega + envtest, OLM bundle / `ClusterServiceVersion` / `opm` File-Based Catalogs / OLM v0 + v1 |
| [crossplane](platform-engineering/crossplane/SKILL.md) | Kubernetes (any distro) | **Building** a Crossplane control plane — Managed Resources + lifecycle, XRDs as versioned platform APIs, function-pipeline Compositions, packages, GitOps delivery, and testing. **Crossplane v2-first** (namespaced XRs, Claims removed, functions-only composition) with v1 flagged. Orchestrated by 5 companion subagents in `.claude/agents/`. Complements `addons-and-building-blocks` (which *consumes* managed resources) | Crossplane v2, `apiextensions.crossplane.io` (XRD `/v2`, Composition `/v1`), Composition Functions (`function-patch-and-transform` / `-auto-ready` / `-environment-configs`), `pkg.crossplane.io` packages (Provider / Configuration / Function), `crossplane xpkg build/push`, ImageConfig + Cosign, `managementPolicies`, ProviderConfig + workload identity, `crossplane render`/`validate`, ArgoCD delivery |
| [dynatrace](platform-engineering/dynatrace/SKILL.md) | Dynatrace | Working with **Dynatrace** programmatically — the two-plane API + auth model, DQL on Grail, OpenTelemetry ingest, the AWS connector, and monitoring-as-code. Spine is **right-plane-right-credential**: Classic `.live`/`Api-Token` vs Platform-Grail `.apps`/`Bearer`; you ingest OTel on one plane and query it on the other. Orchestrated by 5 companion subagents in `.claude/agents/`. Sibling to `kusto-kql-api` (different vendor; DQL ≠ KQL) | Dynatrace API (Environment v2, Settings 2.0, `nextPageKey`), API tokens (`dt0c01`) / platform tokens (`dt0s16`) / OAuth clients (`dt0s02`), DQL/Grail (`fetch`/`timeseries`/`makeTimeseries`/`parse`, `query:execute`/`poll`, `storage:*:read`), OTLP ingest (HTTP/protobuf, delta temporality) + the Dynatrace OpenTelemetry Collector, the role-based `da-aws` connector (ExternalId + CloudFormation), Terraform provider + Monaco |
| [kafka-load-test](platform-engineering/kafka-load-test/SKILL.md) | Kubernetes (`testing-system` namespace) | Load testing Kafka and Kafka-driven services — paired-tool methodology (`kafka-producer/consumer-perf-test.sh` for broker baselines + `k6 + xk6-kafka` for application-pipeline headlines), four-quadrant watch list, first-breach stop conditions, name-the-limiting-resource discipline | k6 + xk6-kafka v2 (`Producer` / `Consumer` / `AdminClient` / `SchemaRegistry`), CGO + librdkafka build (`grafana/xk6` builder or `mostafamoradian/xk6-kafka` image), `ramping-arrival-rate` scenarios, `kafka_writer_*` / `kafka_reader_*` thresholds, in-cluster `Job` execution, `setup()`-based race-free topic creation, post-run cleanup (topic delete, offset reset, synthetic-row drop) |
| [aws-cli](platform-engineering/aws-cli/SKILL.md) | AWS (CLI v2) | AWS CLI usage for ad-hoc ops, Makefile glue, CI pipelines, EKS bootstraps — command-structure discipline, two-file config model, credential resolution order, JMESPath `--query`, `file://` vs `fileb://`, pagination, waiters, identity-first auth | AWS CLI v2, IAM Identity Center / SSO (`sso_session`), IRSA / EKS Pod Identity (`web_identity_token_file`), OIDC + `aws-actions/configure-aws-credentials@v4`, `credential_process`, JMESPath, `aws s3` vs `s3api`, `aws … wait` pollers, `--cli-input-json` + `--generate-cli-skeleton`, retry modes (`standard` / `adaptive`), endpoint overrides (`AWS_ENDPOINT_URL_<SERVICE>`), aliases, autoprompt |
| [helm-chart-packages](platform-engineering/helm-chart-packages/SKILL.md) | Kubernetes (Helm) | Authoring Helm charts and their supply chain — the `Chart.yaml` v2 contract, SemVer discipline, standard labels, CRDs in `crds/`, signed packages, and OCI digest pinning | Helm v3, `Chart.yaml` apiVersion `v2`, `values.schema.json`, `templates/` + `_helpers.tpl`, `crds/`, helm-unittest + kubeconform, `helm package` / `helm push` to OCI, provenance `.prov` + Cosign, `@sha256:` digest pinning |
| [auth0-kong-authZ-authN](platform-engineering/auth0-kong-authZ-authN/SKILL.md) | Kubernetes (Kong + Auth0) | Edge authN/authZ at a Kong API Gateway fronted by Auth0 as the OIDC IdP — credential search modes, JWKS-not-introspection validation, `audience`-pinned tokens, and both the KIC + Ingress and KGO + Gateway API delivery paths | Kong Gateway Enterprise `openid-connect` plugin, Auth0 OIDC, JWKS verification, `audience` / `scope` claim checks, session vs bearer vs introspection modes, Kong Ingress Controller + `Ingress`, Kong Gateway Operator + Gateway API |
| [azure-pg-flex](platform-engineering/azure-pg-flex/SKILL.md) | Azure (PostgreSQL Flexible Server) | Observability playbook for Azure Database for PostgreSQL — Flexible Server — the two-layer metrics model, the headroom-vs-raw diagnostic doctrine, the Azure Monitor REST surface, and the two log surfaces | `Microsoft.DBforPostgreSQL/flexibleServers`, Azure Monitor metrics + REST API, platform vs PostgreSQL-native metrics, Diagnostic Settings categories (`PostgreSQLLogs` / `Sessions` / QueryStore), Server Logs, Log Analytics / KQL |
| [azure-retail-prices](platform-engineering/azure-retail-prices/SKILL.md) | Azure (Retail Prices REST API) | Programmatic reads of the public Azure Retail Prices REST API — the anonymous (no-auth) endpoint contract, the two API versions, `NextPageLink` pagination, case-sensitive `$filter`, and USD-only billing reconciliation | `prices.azure.com/api/retail/prices`, anonymous endpoint, `api-version` (stable vs `2023-01-01-preview`), OData `$filter` (case-sensitive), `NextPageLink` pagination to `null`, `meterId` / `armRegionName` / `unitPrice`, savings-plan + reservation prices |
| [kusto-kql-api](platform-engineering/kusto-kql-api/SKILL.md) | Azure (Kusto / ADX / Fabric / Log Analytics) | Talking to a Kusto engine over its REST API or via KQL — five REST endpoints, four service-specific base URLs, v1-vs-v2 response frames, the "200 OK with errors in body" trap, the `innerunique` join trap, and a CI-gate KQL parser. Sibling to `dynatrace` (DQL ≠ KQL) | Azure Data Explorer / Fabric Eventhouse / Log Analytics / App Insights / Sentinel, `/v1/rest/query` + `/v2/rest/query`, KQL, v1/v2 response frames, client request properties, `innerunique` default join, `Microsoft.Azure.Kusto.Language` parser for CI |
| [create-harness](platform-engineering/create-harness/SKILL.md) | Claude Code (agent harness) | Scaffolds a Claude Code "agent harness" monorepo — interview-first topology, `bin/harness sync` projection into `.claude/`, MCP + plugins wiring, and graphify knowledge graphs across product repos | `bin/harness sync`, monorepo of skills / MCP servers / sub-agents / knowledge vault, `.claude/` projection, MCP server + plugins wiring, graphify knowledge graphs, workspace of product repos |

### Operations

| Skill | Platform | Focus | Key Technologies |
|-------|----------|-------|------------------|
| [kubernetes-operations](operations/kubernetes-operations/SKILL.md) | Kubernetes (any distro) | **Operating / running** clusters and workloads (Day-2 / SRE) — incident triage, rollouts, capacity, scheduling, scaling, node maintenance & upgrades, security, networking, storage, observability. The **operate** counterpart to the build-focused `kubernetes-operator-golang` / `crossplane`. Leads with triage decision-trees; declarative-over-imperative, least-privilege, observe-before-scale. Orchestrated by 5 companion subagents in `.claude/agents/` | `kubectl` (describe/logs --previous/events/top/debug/rollout/drain/auth can-i), Pod-failure trees (CrashLoopBackOff / OOMKilled / Pending), requests/limits + QoS, `LimitRange` / `ResourceQuota`, affinity / taints / `topologySpreadConstraints` / `PriorityClass`, HPA (`autoscaling/v2`) / VPA / Cluster Autoscaler / Karpenter / KEDA + `metrics-server`, `PodDisruptionBudget` / drain / version-skew upgrades, RBAC + Pod Security Admission + `securityContext`, Services / EndpointSlices / CoreDNS / `NetworkPolicy` / Gateway API, PV/PVC / StorageClass / CSI |
| [azure-sre-agent](operations/azure-sre-agent/SKILL.md) | Azure (AKS / App Service / Container Apps / Functions) | **AI-assisted incident ops** with Microsoft's **Azure SRE Agent** (Preview) — its extension model and **propose-then-approve** doctrine. Owns the agent platform: the 6 primitives, the MCP-connector model, and the Permission gate that keeps an autonomous agent from mutating prod unsafely. Pairs with `agentic-k8s-ops` (the cross-tool pattern) and the `dynatrace` MCP surface. Ships 5 companion subagents in `.claude/agents/` | 6 extension primitives (Skills/runbooks, Subagents, Python tools, **MCP servers**, hooks, **Permission gate**), MCP connectors (Streamable-HTTP vs stdio; Bearer / custom-headers / managed-identity; namespaced tools; **80-tool budget**; 60s heartbeat), propose-then-approve / human-in-the-loop, auto-provisioned Log Analytics + App Insights + Managed Identity, Azure Monitor / PagerDuty / ServiceNow triggers, RBAC blast-radius scoping |
| [agentic-k8s-ops](operations/agentic-k8s-ops/SKILL.md) | Kubernetes on Azure | **Umbrella playbook** for AI-assisted (agentic) SRE — the cross-tool **Detect → Decide → Act** pattern, the credible **MCP tool-belt**, and the **blast-radius doctrine**. Ties together `azure-sre-agent`, the `dynatrace` MCP surface, `kubernetes-operations`, and `create-harness` without duplicating them; read-mostly by default, every write a gated reversible PR | Detect→Decide→Act, Davis AI (causal RCA) / HolmesGPT archetype, MCP tool-belt — kubernetes-mcp-server (`--read-only`), mcp-for-argocd (`MCP_READ_ONLY`), github-mcp-server (`--toolsets`), azure-mcp (RBAC), k8sgpt `serve --mcp`, trivy-mcp — read-only-by-default, least-privilege tokens, tool-count budget, GitOps-PR remediation, maturity labeling (Preview / community / marketing) |
| [karpenter-eks](operations/karpenter-eks/SKILL.md) | AWS EKS | **Operating Karpenter** — just-in-time node-lifecycle autoscaling on EKS: the CRDs, the AWS install/IAM surface, the disruption engine, observability, and troubleshooting decision-trees. Provisions right-sized EC2 nodes from pending-pod constraints instead of scaling fixed node groups. Owns Karpenter-on-EKS; hands generic HPA/VPA/KEDA + Cluster Autoscaler to `kubernetes-operations`. Ships 3 read-only triage scripts under `tools/` and 5 companion subagents in `.claude/agents/` | `NodePool` (`karpenter.sh/v1`) / `EC2NodeClass` (`karpenter.k8s.aws/v1`) / `NodeClaim`, scheduling requirements (`minValues`, `karpenter.sh/capacity-type` spot/on-demand/reserved, `karpenter.k8s.aws/instance-*`), `amiSelectorTerms` alias pinning + tag discovery (`karpenter.sh/discovery`), IMDSv2 `metadataOptions` / `blockDeviceMappings` / `kubelet`, disruption (consolidation `WhenEmptyOrUnderutilized` / drift / expiration / interruption via SQS), disruption budgets + `do-not-disrupt` + `terminationGracePeriod` + `karpenter.sh/termination` finalizer, helm `karpenter-crd` + `karpenter` (`oci://public.ecr.aws/karpenter`), Pod Identity vs IRSA, `karpenter_*` metrics, Cluster-Autoscaler migration |

### Security

| Skill | Platform | Focus | Key Technologies |
|-------|----------|-------|------------------|
| [kubernetes-security](security/kubernetes-security/SKILL.md) | Kubernetes (any distro) | **Securing / hardening** Kubernetes (the security discipline) — threat model & the 4Cs, cluster/kubelet/etcd hardening, secrets, least-privilege RBAC & identity, workload hardening, supply-chain & admission policy, zero-trust microsegmentation, runtime threat detection. Owns *why controls exist / how they fail*; complements `kubernetes-operations` (operate) and `github-actions` (CI supply chain). Ships read-only audit scripts under `tools/` and 5 companion subagents in `.claude/agents/` | 4Cs threat model, etcd `EncryptionConfiguration` + KMS, kube-bench / CIS Benchmark, `securityContext` + Pod Security Admission, RBAC (`escalate`/`bind`/`impersonate`), Trivy / SBOM, Sigstore Cosign + SLSA, ValidatingAdmissionPolicy / OPA Gatekeeper / Kyverno, default-deny `NetworkPolicy` + Calico / Cilium + mTLS, Falco / Tetragon (eBPF), External Secrets Operator / Vault, CNAPP |

### Networking

| Skill | Platform | Focus | Key Technologies |
|-------|----------|-------|------------------|
| [kubernetes-networking](networking/kubernetes-networking/SKILL.md) | Kubernetes (any distro) | The **networking plane** — the pod network model, the CNI, Services/kube-proxy/DNS, and **Calico** as the CNI in depth (architecture, dataplanes, IPAM, BGP, encapsulation, policy mechanics). Owns *how the network works / how Calico implements it*; complements `kubernetes-operations` (debug) and `kubernetes-security` (policy strategy). 5 companion subagents in `.claude/agents/` | IP-per-pod model, CNI spec (`ADD`/`DEL`, conflist), Services + `kube-proxy` (iptables/IPVS/nftables) + EndpointSlices, CoreDNS `ndots`, Calico architecture (Felix/BIRD/confd/Typha), dataplanes (eBPF/iptables/nftables/VPP), Tigera operator `Installation`, `IPPool` + IPAM + borrowing, BGP (`BGPConfiguration`/`BGPPeer`, route reflectors, service-IP advertising), VXLAN/IPIP/no-encap, `GlobalNetworkPolicy` (`projectcalico.org/v3`, `order`/`Pass`/tiers), `HostEndpoint`, `calicoctl` |

## How It Works

Skills are SKILL.md files that Claude Code can load into its context to provide domain-specific guidance. When Claude Code detects that a project matches a skill's description, it applies the encoded rules and patterns automatically.

Each skill provides:

- **Architecture rules** -- strict layering and dependency direction enforcement (where applicable)
- **Layer-by-layer implementation patterns** -- with concrete code examples
- **Naming and style conventions** -- idiomatic patterns for the target language or platform
- **Testing strategies** -- unit, integration, and architecture tests (where applicable)
- **Anti-patterns and verification checklists** -- pre-done gates the skill checks before declaring a task complete

## Repository Structure

```
coding/
  <skill-name>/
    SKILL.md          # Skill definition (YAML frontmatter + markdown content)
platform-engineering/
  <skill-name>/
    SKILL.md          # Skill definition (YAML frontmatter + markdown content)
operations/
  <skill-name>/
    SKILL.md          # Skill definition (YAML frontmatter + markdown content)
scripts/
  validate-skills.sh  # CI validation script
.claude/
  agents/             # repo-scoped Claude Code subagents that companion skills can orchestrate
.github/
  workflows/
    validate-skills.yml  # GitHub Actions workflow
```

Some skills ship companion **subagents** under `.claude/agents/` — focused Claude Code agents the skill delegates phase work to (e.g. `kubernetes-operator-golang` is orchestrated by `operator-scaffolder`, `crd-api-designer`, `reconciler-author`, `olm-packager`, and `operator-tester`). Subagents are repo-scoped: installing a `SKILL.md` elsewhere does not carry them along.

Skills are organized by domain:

- `coding/` -- application-development skills (language, framework, or build-tooling guidance)
- `platform-engineering/` -- infrastructure / DevOps / CI-CD / supply-chain skills
- `operations/` -- Day-2 / SRE skills for **running** systems (e.g. `kubernetes-operations`)
- `security/` -- security / hardening / threat-model skills (e.g. `kubernetes-security`; may ship read-only audit scripts under `tools/`)
- `networking/` -- networking-plane / CNI / dataplane / network-policy-mechanics skills (e.g. `kubernetes-networking`)

## SKILL.md Format

Each skill file uses YAML frontmatter followed by markdown content:

```yaml
---
name: skill-name
description: When and why to load this skill
license: BSD-3-Clause
compatibility: opencode
metadata:
  language: golang
  pattern: hexagonal-clean-architecture
---

# Skill Title

Markdown content with architecture rules, patterns, and code examples.
```

### Required Frontmatter Fields

| Field | Purpose |
|-------|---------|
| `name` | Skill identifier |
| `description` | Describes when to activate the skill (used for auto-detection) |
| `license` | Distribution license |
| `compatibility` | Target platform (e.g., `opencode`) |
| `metadata` | Non-empty map of language/framework/pattern tags |

## Adding a New Skill

1. Pick the right domain directory:
   - `coding/` for application-development skills (language, framework, build tooling)
   - `platform-engineering/` for infrastructure, DevOps, CI/CD, or supply-chain skills
   - `operations/` for Day-2 / SRE skills that **operate** running systems
   - `security/` for security / hardening / threat-model skills
   - `networking/` for networking-plane / CNI / dataplane skills
2. Create a subdirectory following the relevant naming convention:
   - `<language>-hex-clean` for hexagonal/clean architecture skills (e.g., `golang-hex-clean`)
   - `<domain>-<purpose>` for platform-engineering skills (e.g., `github-actions`)
   - A descriptive kebab-case name for cross-cutting build tooling (e.g., `create-makefiles`, `dockerfile-instructions`)
3. Add a `SKILL.md` file with valid YAML frontmatter and all required fields
4. Write the markdown body: non-negotiable rules first, then layer-by-layer patterns with code examples, closing with an anti-patterns table and a pre-done verification checklist
5. Run the validation script locally before pushing:

```bash
./scripts/validate-skills.sh
```

### Validation Checks

The CI pipeline runs on every push to `master` and every pull request, validating every `SKILL.md` under `coding/`, `platform-engineering/`, `operations/`, `security/`, and `networking/`:

- Every directory under each domain must contain a `SKILL.md` (or, as a learner-friendly exception, one or more `*-expertise.md` / `*-workflow.md` notes)
- Frontmatter must be valid YAML with all required fields (`name`, `description`, `license`, `compatibility`, `metadata`)
- `metadata` must be a non-empty map
- Markdown body after frontmatter must be non-empty
- Fenced code blocks must be balanced (even number of ` ``` ` markers)

To extend coverage to a new top-level domain, add the directory name to the `DOMAIN_DIRS` array at the top of `scripts/validate-skills.sh`.

## License

BSD-3-Clause — see [LICENSE](LICENSE).
