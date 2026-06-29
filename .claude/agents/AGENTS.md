<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-28 | Updated: 2026-06-29 -->

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
  otel-ingest-engineer | cloud-integrator} → monitoring-as-code).
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

### External
- Claude Code subagent runtime (loads `tools` / `model` from frontmatter).

<!-- MANUAL: -->
