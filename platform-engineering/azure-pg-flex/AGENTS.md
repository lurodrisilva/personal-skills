<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-05-02 | Updated: 2026-05-02 -->

# azure-pg-flex

## Purpose
Skill that guides observability work for **Azure Database for PostgreSQL — Flexible Server** (`Microsoft.DBforPostgreSQL/flexibleServers`): metric queries via Azure Monitor REST + `az rest` + `metrics:getBatch`, alert authoring, capacity diagnosis, server-parameter governance for diagnostic features (`metrics.collector_database_activity`, `pg_qs.query_capture_mode`, `auto_explain.log_min_duration`, `pgms_wait_sampling.query_capture_mode`), and the dual log surfaces — downloadable Server Logs (`logfiles.download_enable`, 7-day cap) vs Diagnostic Settings streamed to Log Analytics in **resource-specific mode** (`PostgreSQLLogs`, `PostgreSQLFlexSessions`, `PostgreSQLFlexQueryStoreRuntime`, `PostgreSQLFlexQueryStoreWaitStats`, `PostgreSQLFlexTableStats`, `PostgreSQLFlexDatabaseXacts`, PgBouncer logs). Encodes the **two-layer metric model** (API plane reports `errorCode: Success` even when the server-side collector is OFF — silent empty timeseries), the **headroom-vs-raw doctrine** (prefer `disk_*_consumed_percentage` + `disk_queue_depth` over raw `*_iops`/`*_throughput`), the **93-day retention bound**, and **defensive jq patterns** (`(.timeseries[0].data // [])`).

## Key Files
| File | Description |
|------|-------------|
| `SKILL.md` | The skill definition — `name: azure-pg-flex-observability`, `domain: platform-engineering`, `pattern: managed-database-observability`, `platform: azure`, `service: postgres-flexible-server`, `stack: azure-monitor + azure-cli + postgres + log-analytics` |
| `azure-pg-flex-empty-metrics-expertise.md` | Companion expertise note — distilled "errorCode=Success but empty timeseries" insight (the two-layer API/collector model and the recognition pattern). Loaded via `triggers:` frontmatter (not the SKILL.md contract); kept alongside the skill so the underlying lesson is preserved separately from the full playbook |

## Subdirectories
None.

## For AI Agents

### Working In This Directory
- Edit `SKILL.md` for the full Distinguished Platform Engineer's Playbook. Edit `azure-pg-flex-empty-metrics-expertise.md` only when the empty-metrics insight itself changes — keep it short and focused on the recognition pattern.
- The 10 non-negotiables at the top of `SKILL.md` are flag-first rules in any PR / runbook / dashboard / alert review. Particular load-bearers: `metrics.collector_database_activity = ON` (#1, the silent-collector trap), `api-version=2023-10-01` (#3, never `2018-01-01`), headroom-percentage metrics over raw IOPS (#4), `metrics:getBatch` instead of `for`-looped `az rest` (#5), null-coalesced jq (#6, `(.timeseries[0].data // [])`), 93-day retention bound (#7, HTTP 400 past it), Diagnostic Settings in **resource-specific mode** (#8, `--export-to-resource-specific true`), Query-Store-category-and-server-parameter pairing (#9, enabling a category without its parameter is a silent misconfig), and Server Logs as post-mortem-only (#10, never for fleet alerting). Do not soften these without intent.
- The skill draws a hard line at scope: it covers `Microsoft.DBforPostgreSQL/flexibleServers` only. **Do not extend** to `Microsoft.DBforPostgreSQL/servers` (Single Server, retired) or Cosmos DB for PostgreSQL (Citus) — they have different RPs, different metric sets, and would dilute the playbook. Add a sibling skill instead.
- The `description:` is intentionally exhaustive (auto-detection trigger surface for metric names, KQL table names, parameter names, CLI verbs, REST endpoints, jq patterns). When extending coverage to a new metric / category / parameter / KQL helper, extend the description's trigger list to match — the auto-loader matches on it verbatim.
- The skill is the canonical reference for "metric-name validity ≠ data presence" — that phrasing appears in both files and is the load-bearing lesson. Preserve it on edits.

### Testing Requirements
- **`scripts/validate-skills.sh` does NOT walk this directory** (the validator is hardcoded to `coding/`). After editing, manually verify per the parent skill's three checks:
  1. YAML frontmatter parses and contains `name`, `description`, `license`, `compatibility`, non-empty `metadata` map.
  2. Markdown body after the closing `---` is non-empty.
  3. Fenced code-block markers are even in count.
- The skill ships many fenced JSON / Bash / KQL / SQL blocks (server parameters, `az rest` invocations, `metrics:getBatch` payloads, KQL recipes for `_PGSQL_Get*` helpers) — fence-balance is the most likely regression vector. Run `grep -c '^```' SKILL.md` and confirm the count is even.
- The companion `azure-pg-flex-empty-metrics-expertise.md` uses a different frontmatter schema (`triggers:` list instead of the SKILL.md contract) — do not run the SKILL.md validator against it.

### Common Patterns
- "Non-negotiables encoded in this skill" numbered list — same authoring style as `addons-and-building-blocks`, `github-actions`, and `wiremock-api-mocks`.
- "WHEN TO USE THIS SKILL" matrix opens the body, distinguishing in-scope (Flex Server metric queries, alert authoring, provisioning) from look-alike out-of-scope (Single Server, Cosmos for PG, raw `psql` queries) — keep this format on extensions.
- Two-layer model is rendered as ASCII art (API plane → server-side collector). Same convention as the layered-architecture diagrams in `coding/golang-hex-clean` and `coding/dotnet-hex-clean`.
- Defensive jq pattern `(.timeseries[0].data // [])` appears in every example pipeline — extending with a new metric query should preserve the null-coalesce.

## Dependencies

### Internal
- `../../README.md` — references this skill in the "Platform Engineering" table.
- `../../scripts/validate-skills.sh` — *currently does not validate this file*; expanding the validator is a tracked follow-up in `CLAUDE.md`.

### External
None at runtime — this is documentation, not code. The skill *describes* usage of `az`, `az rest`, `jq`, Azure Monitor REST API (`api-version=2023-10-01`), `metrics:getBatch` (regional data-plane endpoint), Log Analytics KQL, and PG Flex server parameters, but ships no executable artifacts.

<!-- MANUAL: -->
