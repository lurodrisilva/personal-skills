<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-05-03 | Updated: 2026-05-03 -->

# kusto-kql-api

## Purpose
Skill that guides every script, dashboard, alert, library, or CI gate that talks to a **Kusto** engine — Azure Data Explorer (ADX), Microsoft Fabric Eventhouse / KQL DB, Azure Monitor Log Analytics, Application Insights (workspace-based or classic), and Microsoft Sentinel — over its **REST surface** and via **KQL** itself. Covers the five engine endpoints (`/v1/rest/{query,mgmt,ingest}` plus `/v2/rest/query`) and the separate Data Management endpoint with the `ingest-` host prefix; the four service-specific base URLs (`kusto.windows.net`, `kusto.fabric.microsoft.com`, `api.loganalytics.io`, `api.applicationinsights.io`) and their OAuth audience strings; the request body schema (`db` / `csl` / `properties.Options` / `properties.Parameters`); the full request-property catalogue (`servertimeout`, `truncationmaxrecords`, `truncationmaxsize`, `notruncation`, `results_progressive_enabled`, `query_now`, `query_datetimescope_*`, `query_consistency`, `request_readonly[_hardline]`, `request_external_data_disabled`, `validatepermissions`, `query_results_cache_*`); the v1-vs-v2 response shapes (Tables array vs frame protocol with `DataSetHeader` / `TableHeader` / `TableFragment {DataAppend|DataReplace}` / `TableProgress` / `TableCompletion` / `DataTable` / `DataSetCompletion`); the `TableKind` enum; the **three-layer error model** (HTTP 4xx/5xx with `OneApiErrors`, **200 OK with `DataSetCompletion.HasErrors=true`**, in-band per-row errors via `results_error_reporting_placement`); KQL essentials (case sensitivity, pipe data flow, `;`-separated statements, `.`-prefixed management commands, read-only by default); the operator + aggregation + time-series catalogue; the **`innerunique` join trap**; the standalone parser library (`Microsoft.Azure.Kusto.Language` Apache-2.0, `KustoCode.Parse[AndAnalyze]`, the Symbol hierarchy `ClusterSymbol → DatabaseSymbol → TableSymbol → ColumnSymbol/FunctionSymbol`, `Kusto.Toolkit` for live-schema loading); and the cross-language SDK family (`Microsoft.Azure.Kusto.Data/.Ingest/.Tools`, `azure-kusto-data` for Python/Java/Node/Go, `azure-monitor-query` for Log Analytics).

## Key Files
| File | Description |
|------|-------------|
| `SKILL.md` | The skill definition — `name: kusto-kql-api`, `domain: platform-engineering`, `pattern: telemetry-query-api`, `platform: azure`, `service: kusto + log-analytics + application-insights + microsoft-sentinel + microsoft-fabric`, `stack: kusto-rest-api + kql + azure-cli + dotnet-sdk + python-sdk` |

## Subdirectories
None.

## For AI Agents

### Working In This Directory
- Edit `SKILL.md` only.
- The 10 non-negotiables at the top of the body are flag-first rules in any PR / runbook / dashboard / alert / library review. Particular load-bearers: `x-ms-client-request-id` on every call (#1, only stable handle for `.show queries` correlation), `request_app_name` + `request_user` (#2, audit-log distinguishability), **explicitly check `DataSetCompletion.HasErrors` even on HTTP 200** (#3, the load-bearing trap — the doc itself warns "200 OK, but the HTTP response body will indicate an error"), `request_readonly_hardline=true` for untrusted input (#4, plain `request_readonly` is not enough), `/v2/rest/query` + `results_progressive_enabled=true` for streaming (#5, v1 buffers the entire response), explicit `kind=` on every join (#6, the `innerunique` default silently dedupes the left side), CI parses every `.kql` / `.csl` with `Microsoft.Azure.Kusto.Language` (#7), API-boundary time scoping via `query_datetimescope_*` (#8), explicit cache hits via `query_results_cache_max_age` / `query_results_cache_force_refresh` (#9), and management commands (`.`-prefixed) routed through `/v1/rest/mgmt` only — never embedded in query text (#10, deliberate security boundary).
- The `description:` field is intentionally exhaustive (auto-detection trigger surface for endpoint paths, request properties, response-frame names, `TableKind` values, `OneApiErrors`, parser symbols, SDK package names, file patterns like `*.kql` / `*.csl`, and CLI verbs). When extending coverage to a new endpoint / property / SDK / parser API, extend the description's trigger list to match — the auto-loader matches on it verbatim.
- The skill is the canonical reference for the **"200 OK with errors in body"** trap. Preserve that phrasing on edits — it is the single most-cited recognition pattern for Kusto debugging.
- The skill draws a hard line at scope: **query** + **management** + **API surface**. Streaming ingestion is acknowledged ("Partially — apply only the auth + endpoint sections; ingestion is a separate skill") but not covered in depth. Do not let the file grow into a full ingestion playbook — add a sibling skill instead.

### Testing Requirements
- **`scripts/validate-skills.sh` does NOT walk this directory** (the validator is hardcoded to `coding/`). After editing, manually verify per the parent skill's three checks:
  1. YAML frontmatter parses and contains `name`, `description`, `license`, `compatibility`, non-empty `metadata` map.
  2. Markdown body after the closing `---` is non-empty.
  3. Fenced code-block markers are even in count.
- The skill ships many fenced HTTP / JSON / KQL / C# / Python / Bash blocks (request canonicals, `/v2` frame examples, `OneApiErrors` payloads, parser snippets, `KustoClientFactory` invocations, `azure-kusto-data` examples). Fence balance is the most likely regression vector — run `grep -c '^```' SKILL.md` and confirm the count is even.

### Common Patterns
- "Non-negotiables encoded in this skill" numbered list — same authoring style as `addons-and-building-blocks`, `github-actions`, `wiremock-api-mocks`, and `azure-pg-flex`.
- "WHEN TO USE THIS SKILL" matrix opens the body and distinguishes in-scope (REST/SDK calls, `.kql` files, alert/workbook authoring, CI gates, slow-query tuning, "200 OK no data" debugging) from look-alike out-of-scope (Managed Prometheus → Kusto translation tools).
- ASCII-art topology of the engine vs Data Management endpoint sits at the top of "THE REST SURFACE" — same convention as the layered diagrams in `coding/golang-hex-clean`, `coding/dotnet-hex-clean`, and `azure-pg-flex`.
- Every example HTTP call carries `x-ms-client-request-id`, `x-ms-app`, `x-ms-user` headers — extending with a new request snippet should preserve all three.
- Service / audience / endpoint trios are rendered as a single table (ADX, Fabric Eventhouse, Log Analytics data plane, App Insights classic, Sentinel) — keep this shape on extensions.

## Dependencies

### Internal
- `../../README.md` — references this skill in the "Platform Engineering" table.
- `../../scripts/validate-skills.sh` — *currently does not validate this file*; expanding the validator is a tracked follow-up in `CLAUDE.md`.
- `../azure-pg-flex/SKILL.md` — sibling Azure-observability skill; both reference the Log Analytics REST surface but from different angles (PG-Flex-specific KQL recipes vs the generic Kusto API mechanics here). Cross-reference rather than duplicate.

### External
None at runtime — this is documentation, not code. The skill *describes* usage of the Kusto REST API (`/v1/rest/query`, `/v2/rest/query`, `/v1/rest/mgmt`, `/v1/rest/ingest`), Log Analytics REST (`/v1/workspaces/{id}/query`), Azure CLI (`az monitor log-analytics query`, `az account get-access-token`), MSAL auth flows, the .NET SDKs (`Microsoft.Azure.Kusto.Data`, `.Ingest`, `.Tools`, `Microsoft.Azure.Kusto.Language`, `Kusto.Toolkit`), and the cross-language SDKs (`azure-kusto-data` for Python/Java/Node/Go, `azure-monitor-query`), but ships no executable artifacts.

<!-- MANUAL: -->
