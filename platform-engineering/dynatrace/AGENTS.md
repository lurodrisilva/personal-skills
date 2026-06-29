<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-29 | Updated: 2026-06-29 -->

# dynatrace

## Purpose
Skill that guides working with **Dynatrace** programmatically across its whole
surface: the Dynatrace API + authentication, **DQL** queries on **Grail**,
**OpenTelemetry (OTLP)** ingest + the Dynatrace OpenTelemetry Collector
distribution, the agentless role-based **AWS** connector (`da-aws`), and
**monitoring-as-code** (Terraform provider / Monaco). Its spine is the **two-plane
model**: the Classic plane (`{env}.live.dynatrace.com`, `/api/v1|v2|config/v1`,
`Api-Token dt0c01…`) versus the Platform/Grail plane (`{env}.apps.dynatrace.com`,
`/platform/…`, `Bearer` platform-token `dt0s16…` or OAuth-client `dt0s02…`) — and
which credential each endpoint requires.

## Key Files
| File | Description |
|------|-------------|
| `SKILL.md` | The skill definition — `name: dynatrace`, `domain: platform-engineering`, `pattern: observability-platform`, `platform: dynatrace`, `surfaces: api-auth, dql, otlp-ingest, cloud-integration, monitoring-as-code` |

## Subdirectories
None.

## For AI Agents

### Working In This Directory
- Edit `SKILL.md` only.
- The **CORE PRINCIPLES** and the **PLANE & AUTH MAP** at the top are the
  load-bearing review gate — do not soften them. Highest-blast-radius facts:
  - **Two planes, two credential families:** Classic `.live` + `Api-Token dt0c01`
    vs Platform/Grail `.apps` + `Bearer` (`dt0s16` platform token / `dt0s02` OAuth
    client). A platform token does NOT work on a classic `/api/v2` call (and
    vice-versa).
  - **Ingest vs query split (Principle 2):** OpenTelemetry is **ingested** on the
    Classic plane (`/api/v2/otlp`, `Api-Token`) but **queried** with DQL on the
    Platform plane (`/platform/storage/query…`, `Bearer`). This is invisible
    per-phase — keep it stated loudly.
  - Token prefix is **`dt0c01`** (not `dt0s01`).
  - **OTLP is HTTP/protobuf only** (no gRPC, no JSON); metrics must be **delta**
    temporality; explicit-bucket histograms need Dynatrace ≥ 1.300.
  - **AWS connector is role-based** (`da-aws`, cross-account IAM role + ExternalId);
    legacy ActiveGate/key monitoring is **deprecated 2026-03-31**. Always query the
    `da-aws` `activeVersion`; the Dynatrace trust account id varies by region.
- **Do NOT confabulate the AWS connection-object Settings-2.0 schema** — the
  research could not verify it; the body points to the tenant's "Create an AWS
  connection" page instead. Keep that pointer; only the *monitoring-configuration*
  POST body is verbatim.
- **`dt.entity.*` vs `dt.smartscape.*`:** the body leads with `dt.entity.*`
  (current docs) and flags `dt.smartscape.*` as the emerging Gen3 form — keep both.
- Don't hardcode tenant/env URLs, schema versions, or trust account ids — point
  readers to `/platform/swagger-ui` and their tenant. Don't hardcode a Dynatrace
  product version in prose.
- The `description:` uses a `>-` YAML block scalar **on purpose** (it is
  colon-dense: `Api-Token dt0c01…`, `mode:`, `scope:`); a plain scalar would
  mis-parse as a map under `yq`. Keep the block scalar and re-verify after editing.

### Testing Requirements
- **`scripts/validate-skills.sh` validates this directory** (its `DOMAIN_DIRS`
  includes `platform-engineering/`); CI runs it on every push and PR. Run it
  locally before pushing; it checks:
  1. YAML frontmatter parses and contains `name`, `description`, `license`, `compatibility`, non-empty `metadata` map.
  2. Markdown body after the closing `---` is non-empty.
  3. Fenced code-block markers are even in count — this skill ships many bash/yaml/dql/json blocks; `grep -c '^```' SKILL.md` must be even.
- After editing the frontmatter, confirm `.description` still parses as a **string**, not a map: `yq '.description | type'` should print `!!str`.

### Companion Subagents
- Orchestrated by five repo-scoped subagents in `../../.claude/agents/`:
  `dynatrace-api-client`, `dynatrace-dql-author`, `dynatrace-otel-ingest-engineer`,
  `dynatrace-cloud-integrator`, `dynatrace-monitoring-as-code`. The "Subagent
  Orchestration" table at the end of `SKILL.md` maps surfaces → agents. Rename a
  surface or agent → update both sides.

### Common Patterns
- "CORE PRINCIPLES (NON-NEGOTIABLE)" numbered list + a PLANE & AUTH MAP, then a
  surface-by-surface body (API client → DQL → OTel ingest → AWS connector →
  monitoring-as-code → ops), closing with an anti-patterns table (violation → why
  it breaks → do instead) and a pre-done checklist — same authoring shape as
  `crossplane`, `kubernetes-operator-golang`, `kafka-strimzi-operator`. One
  runnable example per surface rather than an exhaustive feature tour.

## Dependencies

### Internal
- `../../scripts/validate-skills.sh` — enforces the frontmatter + body + fenced-block contract.
- `../../README.md` — references this skill in the "Platform Engineering" table; rename → README update required.
- `../../.claude/agents/dynatrace-*.md` — the five companion subagents this skill delegates to.
- `../kusto-kql-api/SKILL.md` — sibling observability-query-API skill for **Azure Kusto/KQL**; different vendor, DQL ≠ KQL. Cross-referenced to prevent conflation, not overlapping.

### External
None at runtime — this is documentation, not code. The skill *describes* the
Dynatrace API / DQL / OTLP / `da-aws` / Terraform provider / Monaco but does not
depend on them being installed in this repo.

<!-- MANUAL: -->
