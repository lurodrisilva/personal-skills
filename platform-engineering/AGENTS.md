<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-04-25 | Updated: 2026-08-08 | DEEPINIT: 2026-08-08 -->

# platform-engineering

## Purpose
Infrastructure / DevOps / CI-CD / supply-chain / observability skills — Claude Code / opencode auto-loads them when a project matches their description. Each subdirectory contains a `SKILL.md` (some also ship a companion expertise note alongside, or a companion subagent team under `../.claude/agents/`). **This directory IS CI-validated:** `scripts/validate-skills.sh` walks every domain in its `DOMAIN_DIRS` array — currently `coding/`, `platform-engineering/`, `operations/`, `security/`, and `networking/` — on every push and PR.

## Key Files
None at this level — all content lives in subdirectories.

## Subdirectories
| Directory | Purpose |
|-----------|---------|
| `addons-and-building-blocks/` | Helm library charts + ArgoCD App-of-Apps + Crossplane / CNPG building blocks on AKS (see `addons-and-building-blocks/AGENTS.md`) |
| `auth0-kong-authZ-authN/` | Kong API Gateway + Auth0 OIDC edge authN/authZ — `openid-connect` plugin, JWKS-not-introspection, `audience`-pinned tokens, KIC + Ingress and KGO + Gateway API paths (see `auth0-kong-authZ-authN/AGENTS.md`) |
| `aws-cli/` | AWS CLI v2 — command structure, two-file config model, credential resolution, JMESPath `--query`, `file://` vs `fileb://`, pagination + waiters, SSO / IRSA / OIDC over long-lived keys (see `aws-cli/AGENTS.md`) |
| `aws-finops/` | **FinOps on AWS** — the FinOps Framework (Inform→Optimize→Operate; four domains), the AWS Well-Architected Cost Optimization pillar + FOCUS billing schema; allocation, usage/rate optimization, budgeting/forecasting, governance, EKS + AI cost. Sibling of `azure-finops`; delegates CLI mechanics to `aws-cli`. Ships 3 read-only `aws` cost scripts under `tools/` + a 5-agent FinOps team in `../.claude/agents/` (see `aws-finops/AGENTS.md`) |
| `azure-cli/` | Azure CLI (`az`) — command-group grammar, identity-first auth (managed identity / OIDC over long-lived secrets), client-side JMESPath `--query` + output formats, `az config` + `AZURE_*` env surface, extensions, waiters/`--ids`, sovereign clouds, the `az rest` escape hatch, and the Azure MCP Server (referenced). Sibling of `aws-cli`; `azure-finops` uses its `az` mechanics. Ships 3 read-only `az` triage scripts under `tools/` + a 5-agent Azure-CLI team in `../.claude/agents/` (see `azure-cli/AGENTS.md`) |
| `azure-cosmosdb-mongo-vcore/` | Cosmos DB for MongoDB vCore expertise notes — `dns-zone-group show` exit-0-on-missing CLI bug, SRV-not-A `mongocluster.cosmos.azure.com` TCP-probe trap, M30+ HA tier minimum (see `azure-cosmosdb-mongo-vcore/AGENTS.md`) |
| `azure-finops/` | **FinOps on Azure** — the FinOps Framework (Inform→Optimize→Operate; four domains), the WAF Cost Optimization pillar (CO:01–CO:14) + FOCUS billing schema; allocation, usage/rate optimization, budgeting/forecasting, governance, AKS + AI cost. Ships 3 read-only `az` cost scripts under `tools/` + a 5-agent FinOps team in `../.claude/agents/` (see `azure-finops/AGENTS.md`) |
| `azure-pg-flex/` | Azure Postgres Flexible Server observability playbook — metrics two-layer model, headroom-vs-raw diagnostic doctrine, REST API surface, two log surfaces (Server Logs + Diagnostic Settings categories) (see `azure-pg-flex/AGENTS.md`) |
| `azure-retail-prices/` | Azure Retail Prices REST API — anonymous commercial-cloud-only endpoint, paginate to `NextPageLink === null`, USD-only billing reconciliation, case-sensitive `$filter` on `2023-01-01-preview` (see `azure-retail-prices/AGENTS.md`) |
| `create-harness/` | Scaffolds a Claude Code "agent harness" monorepo — interview-first topology, `bin/harness sync` projection into `.claude/`, MCP + plugins wiring, graphify knowledge graphs across repos (see `create-harness/AGENTS.md`) |
| `crossplane/` | **Building** a Crossplane control plane (v2-first) — Managed Resources, XRDs, function-pipeline Compositions, packages, safe-start MRD/MRAP, provider development (Upjet vs native), GitOps delivery; ships 4 read-only `tools/` scripts + a read-only MCP surface + a 6-agent Crossplane team in `../.claude/agents/` (see `crossplane/AGENTS.md`) |
| `dynatrace/` | **Dynatrace** programmatic surface — the two-plane API + auth (Classic `Api-Token` vs Platform/Grail `Bearer`), DQL on Grail, OpenTelemetry (OTLP) ingest + the Dynatrace Collector, the role-based `da-aws` connector, and monitoring-as-code (Terraform/Monaco); ships a 5-agent Dynatrace team in `../.claude/agents/` (see `dynatrace/AGENTS.md`) |
| `github-actions/` | CI/CD governance — workflow syntax, OIDC federation, SHA-pinning, attestations / SLSA Build L3 (see `github-actions/AGENTS.md`) |
| `github-cli/` | GitHub CLI (`gh`) — command-group grammar, token-precedence auth (`GH_TOKEN`>`GITHUB_TOKEN`>keyring; GHES enterprise token), repo-context resolution (`-R`/`GH_REPO`/`set-default`), the `--json`/`--jq`/`--template` output trio, the `gh api` REST+GraphQL escape hatch (`-f` string vs `-F` typed), config + `GH_*` env, aliases + extensions (supply-chain), the dev-workflow porcelain, the Actions surface + gh-in-Actions `GH_TOKEN`+`permissions:`, and the GitHub MCP Server (referenced). Siblings `aws-cli`/`azure-cli`; boundary partner `github-actions`. Ships 3 read-only `gh` triage scripts under `tools/` + a 6-agent GitHub-CLI team in `../.claude/agents/` (see `github-cli/AGENTS.md`) |
| `helm-chart-packages/` | Helm chart authoring + supply chain — Chart.yaml v2 contract, SemVer, standard labels, CRDs in `crds/`, signed packages + OCI `@sha256:` digest pinning (see `helm-chart-packages/AGENTS.md`) |
| `kafka-load-test/` | Load testing Kafka + Kafka-driven services — paired-tool methodology (`perf-test.sh` broker baseline + `k6 + xk6-kafka` headline), four-quadrant watch list, first-breach stop conditions (see `kafka-load-test/AGENTS.md`) |
| `kafka-strimzi-operator/` | Apache Kafka on Kubernetes via the Strimzi operator — KRaft-only role-split `KafkaNodePool`s, the verbatim `BrokerCapacity` API contract, Cruise Control rebalance modes, perf-test playbook against the four limiting resources (CPU / network-in / network-out / log disk), `Hex.Scaffold` consumer/producer integration notes (see `kafka-strimzi-operator/AGENTS.md`) |
| `kubernetes-operator-golang/` | **Building** Kubernetes Operators in Go (kubebuilder go/v4 + controller-runtime) — CRD/API design, the level-based idempotent Reconcile loop, webhooks, RBAC, envtest, OLM packaging; ships a 5-agent operator team in `../.claude/agents/` (see `kubernetes-operator-golang/AGENTS.md`) |
| `kusto-kql-api/` | Kusto / KQL telemetry-query API playbook — five REST endpoints, four service-specific base URLs, v1-vs-v2 response frames, the "200 OK with errors in body" trap, `innerunique` join trap, standalone `Microsoft.Azure.Kusto.Language` parser for CI gates (see `kusto-kql-api/AGENTS.md`) |
| `opencost/` | **OpenCost** (CNCF) — the *measurement plane* for Kubernetes cost and the reference implementation of the OpenCost Specification: deployment (Helm / manifest / Docker / exporter-only / guided / Tilt dev), the `job_name: opencost` Prometheus wiring, ports 9003 (API + `/metrics`) / 9090 (UI) / 8081 (MCP), multi-cluster single-source-of-data, cloud pricing (`cloud-integration.json` for AWS/Azure/GCP/OCI + custom on-prem pricing), the Allocation / Assets / CloudCost / CustomCost API, CSV + Parquet export, carbon estimates, the plugin framework, and the read-only MCP surface. **Boundary partner of `../operations/kubernetes-finops/`**: this skill produces the cost number, that one decides what to do about it. Ships 3 read-only triage scripts under `tools/` + a 5-agent OpenCost team in `../.claude/agents/` (see `opencost/AGENTS.md`) |
| `platform-architect/` | **Distinguished platform-engineering architecture** — the capstone that decides *what* the platform offers and delegates the *how* to the sibling skills: platform-as-a-product strategy, the five-plane IDP reference architecture, golden paths, Team Topologies + cognitive load, DORA/SPACE + adoption metrics, ADR/RFC governance, and the CNCF Platform Engineering Maturity Model. Ships 3 read-only assessment scripts under `tools/` + a 6-agent team in `../.claude/agents/` (see `platform-architect/AGENTS.md`) |
| `terraform-iac/` | **Infrastructure as Code with Terraform / OpenTofu** — the `plan → review → gated apply` lifecycle: HCL2 module authoring, remote state + locking (S3+DynamoDB / azurerm / gcs / TFC-HCP), providers + short-lived OIDC/assume-role/workload-identity auth, plan review + policy-as-code (OPA/Conftest/Sentinel), testing (`terraform test`/terratest/tflint/tfsec/checkov), and drift; ships 3 read-only `terraform` scripts under `tools/` + a 5-agent IaC team in `../.claude/agents/` (see `terraform-iac/AGENTS.md`) |
| `wiremock-api-mocks/` | Shared cluster-wide WireMock mock server in `testing-system` namespace — stubs declared in consumer Helm values, registered via Admin API at install/upgrade (see `wiremock-api-mocks/AGENTS.md`) |

## For AI Agents

### Working In This Directory
- Skills here follow the `<domain>-<purpose>` naming convention (e.g. `github-actions`, `addons-and-building-blocks`).
- The SKILL.md `description:` should be deliberately exhaustive — these skills are platform-wide and need to fire on many file patterns, tool names, and PR triggers. The existing skills' descriptions are good reference points (a `>-` block scalar is the safe form when the description is colon-dense — see `crossplane`).
- Tone convention: every skill in this directory is framed as **"Distinguished Platform Engineer's Playbook"** — fleet-scale governance, blast-radius control, supply-chain integrity over one-off convenience.

### Testing Requirements
- **`scripts/validate-skills.sh` validates this directory** (its `DOMAIN_DIRS` array includes `platform-engineering/`); CI runs it on every push and PR. Run it locally before pushing; it checks per `SKILL.md`:
  1. Frontmatter parses as YAML and contains `name`, `description`, `license`, `compatibility`, non-empty `metadata` map.
  2. Markdown body after the closing `---` is non-empty.
  3. Fenced code-block markers are even in count (no unclosed ` ``` `).
- An expertise-only subdirectory (no `SKILL.md`, just `*-expertise.md` / `*-workflow.md`) is accepted via the validator's orphan-directory exception and is not SKILL.md-validated.

### Common Patterns
- `metadata:` includes `domain: platform-engineering` plus `platform:` and `pattern:` tags that downstream skill registries can filter on.
- Body opens with a numbered "Non-negotiables" list — the rules to flag in a PR review *before anything else*.
- Each skill includes a "WHEN TO USE THIS SKILL" matrix that distinguishes triggers from look-alike but out-of-scope scenarios (e.g. "`.gitlab-ci.yml` → No, wrong platform").

## Dependencies

### Internal
- `../README.md` — references each skill in the "Platform Engineering" table; rename → README update required.
- `../scripts/validate-skills.sh` — validates this tree (its `DOMAIN_DIRS` includes `platform-engineering/`); CI runs it on every push and PR.
- `../.claude/agents/` — companion subagent teams that some skills here orchestrate (`crossplane`, `kubernetes-operator-golang`, `dynatrace`, `azure-finops`, `aws-finops`, `terraform-iac`, `azure-cli`, `github-cli`, `opencost`, `platform-architect`).
- `../operations/kubernetes-finops/` — boundary partner of `opencost/`. The two skills
  deliberately split tool-vs-practice and cross-reference each other; changing one
  side's scope means updating the other.

<!-- MANUAL: -->
