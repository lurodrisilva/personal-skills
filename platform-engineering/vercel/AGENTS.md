<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-08-28 | Updated: 2026-08-28 -->

# vercel

## Purpose
The `vercel` skill — an operator's playbook for **Vercel the platform** (the
frontend cloud): shipping through preview→promotion, configuring `vercel.json`,
functions on Fluid compute, routing middleware, caching/ISR, crons, storage
(Blob / Global Config / Marketplace), domains + DNS, the CLI and the canonical
CI sequence, the REST API + `@vercel/sdk`, OIDC federation, observability
(logs / drains / OTel), security (Deployment Protection / WAF / RBAC), the
official **Vercel MCP server** (`mcp.vercel.com`), and the **AI Gateway**
(`ai-gateway.vercel.sh`).

It deliberately does **not** own framework application code (Next.js et al.),
GitHub Actions workflow YAML beyond the Vercel steps, or cloud IAM beyond the
Vercel OIDC trust policy — those hand off to sibling skills.

## Key Files
| File | Description |
|------|-------------|
| `SKILL.md` | The skill contract: scope boundary + version gate, CORE PRINCIPLES, capability map, Phases A–F (ship → compute → route → automate → observe/protect → agent surface), anti-patterns, checklist, REFERENCE, MCP SURFACE, subagent orchestration |
| `tools/` | Three read-only triage scripts — project/deployment status, env-var audit (names only, never values), domain/DNS check (see `tools/AGENTS.md`) |

## Subdirectories
| Directory | Purpose |
|-----------|---------|
| `tools/` | Read-only `curl` + `jq` (+ optional `dig`) scripts against `api.vercel.com`, shipped with the skill |

## For AI Agents

### Working In This Directory
- **Read `SKILL.md` first and obey its CORE PRINCIPLES.** The five that constrain
  almost every edit: production changes by **promotion**, not deploy; **rollback
  re-points but does not rebuild** (env vars and crons are NOT updated); the
  **dashboard domain card is the source of truth for DNS values** (never
  hardcode `76.76.21.21` / `cname.vercel-dns.com`); **reads are free, mutations
  are gated**; and **stdout of `vercel deploy` is the URL** — the only
  contractual CLI output.
- **Pin no versions in prose.** Vercel ships weekly and renames surfaces (Edge
  Config → Global Config, Edge Middleware → Routing Middleware, KV/Postgres →
  Marketplace). REST endpoints are versioned per path (`/v7/deployments`,
  `/v13/deployments/{id}`) and move independently — verify against
  `vercel.com/docs` and `openapi.vercel.sh` before editing any endpoint, flag,
  or limit here.
- **Facts were extracted verbatim from vercel.com/docs (2026-08).** Header
  names (`x-vercel-cache`, `x-vercel-protection-bypass`), env vars
  (`VERCEL_OIDC_TOKEN`, `CRON_SECRET`, `AI_GATEWAY_API_KEY`), config keys
  (`ignoreCommand`, `bulkRedirectsPath`, `proxy`, `fluid`), MCP tool names, and
  limits are character-exact on purpose. **Do not "tidy" them from memory** —
  re-fetch the doc page and quote it.
- **Keep the stale-knowledge traps intact.** The skill exists partly to
  override confidently-wrong training data: pooled anycast DNS IPs +
  per-project CNAMEs; `public: true` now *fails* deployments; `functions.memory`
  invalid under Fluid; `ignoreCommand` exit 0 = *skip*; first deploy of a new
  project is always production; cron delivery is best-effort. Don't soften
  these.
- **Never put a real token, deploy-hook URL, or bypass secret in an example.**
  Placeholders only; tokens come from the environment.
- Keep the **scope boundary** accurate: framework internals, workflow YAML, and
  cloud IAM belong to sibling skills — add a handoff line instead of duplicating.
- The six companion subagents live in **`../../.claude/agents/`** (repo-scoped),
  not here: `vercel-project-deployer`, `vercel-functions-engineer`,
  `vercel-domains-router`, `vercel-cli-api-automator`,
  `vercel-observability-securer`, `vercel-mcp-ai-integrator`. Adding or renaming
  one means updating both `SKILL.md`'s orchestration table and
  `../../.claude/agents/AGENTS.md`.

### Testing Requirements
- Run `./scripts/validate-skills.sh` from the repo root before every push.
  `platform-engineering/` is in the validator's `DOMAIN_DIRS`, so this SKILL.md
  is CI-checked on every push and PR.
- The check that bites a long skill is **balanced code fences** — an odd number
  of ``` markers fails CI. Count them before running the validator.
- Frontmatter must keep `name`, `description`, `license: BSD-3-Clause`,
  `compatibility: opencode`, and a non-empty `metadata` map.
- `bash -n` every script under `tools/`; keep them executable.

### Common Patterns
- `description:` opens with `MUST USE when …` and exhaustively lists
  Vercel-specific triggers (config filenames, `VERCEL_*` env vars, hosts,
  error codes, CLI commands). Keep the surface triggers (`vercel.json`,
  `.vercel/`, `*.vercel.app`, `mcp.vercel.com`, `ai-gateway.vercel.sh`)
  specific — they discriminate this skill from framework skills.
- Body order: scope boundary + version gate → CORE PRINCIPLES → capability map →
  phases with verbatim commands/JSON → anti-patterns table → pre-done checklist
  → REFERENCE → MCP SURFACE → SUBAGENT ORCHESTRATION.
- Every phase hands *decisions* to a human and keeps *analysis* read-only; the
  MCP section explicitly gates `deploy_to_vercel` and every `buy_*` tool.

## Dependencies

### Internal
- `../github-actions/` — workflow YAML that wraps the CLI's CI sequence.
- `../aws-cli/` / `../azure-cli/` — cloud IAM beyond the Vercel OIDC trust policy.
- `../../operations/observability-stack/` — the backends that receive Drains.
- `../../operations/agentic-k8s-ops/` — the read-mostly / gated-write
  blast-radius doctrine the MCP guidance follows.
- `../../.claude/agents/` — the six companion subagents.

### External
- Vercel — `vercel.com/docs`, `openapi.vercel.sh`, the `vercel` CLI,
  `api.vercel.com`, `mcp.vercel.com`, `ai-gateway.vercel.sh`.
- `curl`, `jq` (required by the env-audit script), optional `dig`.

<!-- MANUAL: -->
