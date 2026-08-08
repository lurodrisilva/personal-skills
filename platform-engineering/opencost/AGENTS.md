<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-08-08 | Updated: 2026-08-08 -->

# opencost

## Purpose
The `opencost` skill — the **measurement plane** for Kubernetes cost. It covers
**OpenCost the tool**: deploying it (Helm / manifest / Docker / exporter-only), wiring
it to Prometheus, giving it real prices (cloud billing integration or a custom pricing
sheet), querying it (`/allocation`, `/assets`, `/cloudCost`, `/customCost/*`), getting
data out (CSV, Parquet, `kubectl cost`, MCP), extending it (plugins, carbon
estimates), and fixing it when the numbers are empty, negative, or zero.

It is deliberately **not** a FinOps-practice skill. What to *do* about a cost number —
right-size requests, kill idle, set quotas, bill teams back — belongs to
`../../operations/kubernetes-finops/`. This skill produces the number that skill acts
on, and insists the number be qualified.

## Key Files
| File | Description |
|------|-------------|
| `SKILL.md` | The skill contract: core principles, capability map, Phases A–E (deploy → price → query → integrate → troubleshoot), anti-patterns, verification checklist, reference (cost model, ports, metric names), MCP surface, subagent orchestration |
| `tools/` | Three read-only triage scripts — health, pricing verification, allocation summary (see `tools/AGENTS.md`) |

## Subdirectories
| Directory | Purpose |
|-----------|---------|
| `tools/` | Read-only `kubectl` + `curl` triage scripts shipped with the skill |

## For AI Agents

### Working In This Directory
- **Read `SKILL.md` first and obey its CORE PRINCIPLES.** The five that constrain
  almost every edit: a cost number without a stated **pricing source** is a guess;
  allocation is **`max(request, usage)`**; **idle belongs to the cluster**, not a
  tenant; **no Prometheus scrape target → no data** (and negative idle); and **every
  OpenCost interaction is read-only** while every install/config change is gated.
- **Pin no versions in prose.** OpenCost ships fast — Helm values keys, env vars, and
  API parameters move between releases. Describe behavior, and tell the reader to
  verify against `opencost.io/docs`, the `opencost/opencost` +
  `opencost/opencost-helm-chart` repos, and `helm show values`. The skill's version
  gate says this explicitly; keep it.
- **Facts here were extracted verbatim from opencost.io.** Endpoint paths, query
  parameter names and defaults, metric names, `cloud-integration.json` key paths,
  `authorizerType` values, env var names, and port numbers are character-exact on
  purpose. **Do not "tidy" them from memory** — re-fetch the doc page and quote it.
  A plausible-but-wrong `?aggregate=…` example is the main way this skill can fail.
- **Ports are load-bearing and easy to get backwards:** `9003` = API **and**
  `/metrics`, `9090` = UI, `8081` = MCP.
- **Never put a credential in an example that looks copy-pasteable into Git.** Cloud
  integration examples use placeholders and route through the `cloud-costs` secret;
  prefer IRSA / `GCPWorkloadIdentity` over static keys everywhere.
- Keep the **scope boundary** section accurate. If you add content that is really
  about right-sizing, autoscaling, node lifecycle, or the cloud invoice, it belongs in
  a sibling skill — add a handoff line instead of duplicating.
- The five companion subagents live in **`../../.claude/agents/`** (repo-scoped), not
  in this directory: `opencost-installer`, `opencost-cloud-integrator`,
  `opencost-api-analyst`, `opencost-export-integrator`, `opencost-troubleshooter`.
  Adding or renaming one means updating both `SKILL.md`'s orchestration table and
  `../../.claude/agents/AGENTS.md`.

### Testing Requirements
- Run `./scripts/validate-skills.sh` from the repo root before every push.
  `platform-engineering/` is in the validator's `DOMAIN_DIRS`, so this SKILL.md is
  CI-checked on every push and PR.
- The check that actually bites a long skill is **balanced code fences** — an odd
  number of ``` markers fails CI. Count them before running the validator.
- Frontmatter must keep `name`, `description`, `license: BSD-3-Clause`,
  `compatibility: opencode`, and a non-empty `metadata` map.
- `bash -n` every script under `tools/`; keep them executable.

### Common Patterns
- `description:` opens with `MUST USE when …` and exhaustively lists OpenCost-specific
  triggers. This is what discriminates against `kubernetes-finops`, whose description
  also matches "opencost" — keep the tool-level triggers (config file names, endpoint
  paths, metric names, port numbers, `ghcr.io/opencost/*`) specific.
- Body order: scope boundary + version gate → CORE PRINCIPLES → capability map →
  phases with verbatim commands/YAML/JSON → anti-patterns table → pre-done checklist →
  REFERENCE → MCP SURFACE → SUBAGENT ORCHESTRATION.
- Every phase ends by handing the *decision* outward and keeping the *measurement*
  here.

## Dependencies

### Internal
- `../../operations/kubernetes-finops/SKILL.md` — the FinOps practice that consumes
  these numbers (right-sizing, waste, quotas, chargeback). The boundary is documented
  in both files; keep them in sync.
- `../../operations/karpenter-operations/` — node lifecycle.
- `../aws-finops/` / `../azure-finops/` — the cloud invoice, reservations, savings plans.
- `../../operations/observability-stack/` — Prometheus / Thanos operation itself.
- `../../operations/kubernetes-operations/` — generic cluster triage.
- `../../operations/agentic-k8s-ops/` — the read-mostly / gated-write blast-radius doctrine.
- `../../.claude/agents/` — the five companion subagents.

### External
- OpenCost (CNCF) — `opencost.io/docs`, `opencost/opencost`, `opencost/opencost-helm-chart`.
- Prometheus (+ optional Thanos / Cortex / Mimir for multi-cluster).
- `kubectl`, `helm`, `curl`, optional `jq` and the `kubectl cost` krew plugin.

<!-- MANUAL: -->
