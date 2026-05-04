---
name: kusto-kql-api
description: 'MUST USE when authoring, reviewing, or debugging anything that talks to a **Kusto** engine (Azure Data Explorer / Microsoft Fabric Eventhouse / Log Analytics / Application Insights / Microsoft Sentinel) over its **REST API** or via **KQL** itself. Use when the user asks to "query Log Analytics from a script", "call Kusto from .NET / Python / Java / Go / Node", "write a KQL query", "fix a slow KQL query", "validate KQL in CI", "parse KQL programmatically", "lint queries before deploy", "build a workbook", "alert on a Kusto query", "stream metrics to Log Analytics and query them", "wrap az monitor log-analytics query in a script", "run cross-cluster KQL", "use the Kusto v2 progressive response", "handle 200 OK with errors in body". Triggers on phrases — "csl", "kusto v1 vs v2", "results_progressive_enabled", "DataSetHeader", "DataSetCompletion", "TableFragment", "DataAppend / DataReplace", "TableKind PrimaryResult", "QueryCompletionInformation", "OneApiErrors", "innerunique", "x-ms-client-request-id", "servertimeout", "truncationmaxsize", "notruncation", "request_app_name", "query_now", "query_datetimescope_column", "query_consistency", "query_language=csl", "Microsoft.Azure.Kusto.Language", "Microsoft.Azure.Kusto.Data", "KustoCode.Parse", "KustoCode.ParseAndAnalyze", "GlobalState.Default", "TableSymbol", "ColumnSymbol", "FunctionSymbol", "ClusterSymbol", "DatabaseSymbol", "Kusto.Toolkit", "azure-kusto-data", "azure-monitor-query", "api.loganalytics.io", "api.applicationinsights.io", "kusto.windows.net", "kusto.fabric.microsoft.com", "ingest- prefix endpoint", "Cluster URI vs Data ingestion URI". Triggers on file patterns — `*.kql`, `*.csl`, scripts containing `az monitor log-analytics query`, `KustoClientFactory.CreateCslQueryProvider`, `from azure.kusto.data import`, `from azure.monitor.query import`, `azure-kusto-data` in package.json, `Microsoft.Azure.Kusto.*` in csproj, GitHub Actions workflows that run `kqlmagic` or `azure/CLI@v2` with KQL strings, Helm charts that mount Kusto credentials, Bicep / Terraform that provisions `Microsoft.Kusto/clusters`, `Microsoft.Synapse/workspaces/kustopools`, or a Log Analytics workspace + saved searches. Covers — the full **REST surface** (5 endpoints under `/v1/rest/{query,mgmt,ingest}` and `/v2/rest/query`, engine vs Data Management endpoints with the `ingest-` host prefix); the **service-specific base URLs** (kusto.windows.net, kusto.fabric.microsoft.com, api.loganalytics.io, api.applicationinsights.io) and their **OAuth audience strings**; the **request body schema** (`db`, `csl`, `properties.Options`, `properties.Parameters`); the full **request-property catalogue** (servertimeout 4-min default / 1-hour max, truncationmaxrecords 500k, truncationmaxsize 64 MB, notruncation, results_progressive_enabled, query_now, query_datetimescope_column/from/to, query_consistency, request_readonly[_hardline], request_external_data_disabled, validatepermissions, query_results_cache_*); **mandatory headers** (`x-ms-client-request-id` is load-bearing for `.show queries` correlation); the **v1 vs v2 response shapes** (Tables array vs frame protocol with DataSetHeader / TableHeader / TableFragment {DataAppend|DataReplace} / TableProgress / TableCompletion / DataTable / DataSetCompletion); the **TableKind enum** (PrimaryResult, QueryCompletionInformation, QueryProperties, QueryTraceLog, QueryPerfLog, QueryPlan, TableOfContents, Unknown); the **three-layer error model** (HTTP 4xx/5xx with OneApiErrors body, 200 OK with `DataSetCompletion.HasErrors=true`, in-band per-row errors via `results_error_reporting_placement`); **KQL essentials** (case-sensitive everywhere, pipe data flow, `;`-separated statements, management commands start with `.`, read-only by default, 5 universal facts); the **operator catalogue** (where/project/extend/summarize/join/union/take/top/sort/distinct/range/materialize, mv-expand/mv-apply, parse/parse_json/parse_url, render); **time-series operators** (bin, bin_at, make-series, series_decompose*, ago, datetime literals, startofday); **aggregation functions** (count/dcount, sum/avg/min/max, percentile/percentiles, make_list/make_set, arg_max/arg_min, hll/tdigest); **join kinds** with the `innerunique` default trap; **performance heuristics** (`has` vs `contains` token-index difference, filter-early, hint.shufflekey for high-cardinality summarize, materialize for repeated subqueries); the **standalone parser library** (`Microsoft.Azure.Kusto.Language` Apache-2.0, `KustoCode.Parse` syntax-only, `KustoCode.ParseAndAnalyze` with `GlobalState`, the Symbol hierarchy ClusterSymbol → DatabaseSymbol → TableSymbol → ColumnSymbol / FunctionSymbol, the `Kusto.Toolkit` companion for live-schema loading); **sister SDK packages** (Microsoft.Azure.Kusto.Data for execution, .Ingest for bulk/streaming, .Tools CLI); **cross-language SDKs** (azure-kusto-data Python/Java/Node/Go, azure-monitor-query for Log Analytics specifically). Authored by a distinguished Platform Engineer — emphasizes correctness traps (200-OK-with-errors, innerunique deduplication, DataReplace overwrite semantics), evidence-based query authoring, and the deliberate API/security boundary that makes management commands start with `.` so they cannot be embedded inside queries.'
license: BSD-3-Clause
compatibility: opencode
metadata:
  domain: platform-engineering
  pattern: telemetry-query-api
  platform: azure
  service: kusto + log-analytics + application-insights + microsoft-sentinel + microsoft-fabric
  stack: kusto-rest-api + kql + azure-cli + dotnet-sdk + python-sdk
---

# Kusto / KQL API Access — Distinguished Platform Engineer's Playbook

You are a Platform Engineer responsible for every script, dashboard, alert rule, CI gate, and tool that talks to a **Kusto engine** — Azure Data Explorer (ADX), Microsoft Fabric Eventhouse, Azure Monitor Log Analytics, Application Insights (workspace-based or classic), or Microsoft Sentinel. Your job is to ensure that queries are **correct first, fast second, and cheap third**, that **errors actually surface** (not silently masked behind 200 OK), and that **CI pre-flight catches typos before they hit production**. This skill encodes the rules you apply every time someone reaches for KQL or its REST API.

**Non-negotiables encoded in this skill:**

1. Every API call sets `x-ms-client-request-id`. It is the only stable handle for "find this exact request later" — surfaces in `.show queries`, error context, traces, and your support tickets.
2. Every API call sets `request_app_name` and (where applicable) `request_user`. Without them you cannot distinguish your dashboard's traffic from anyone else's in the audit log.
3. Every API call **explicitly checks `DataSetCompletion.HasErrors`** even when HTTP status is `200 OK`. The doc says verbatim: *"The request may return a status code of 200 OK, but the HTTP response body will indicate an error."* Naïve clients miss this.
4. Every query that runs untrusted user input sets `request_readonly_hardline=true`. This is the strict mode that disables plugins and any noncompliant functionality. `request_readonly` alone is not enough.
5. New query-execution code uses **api-version `/v2/rest/query`** with `results_progressive_enabled=true` for any result that might exceed a few hundred rows. v1 buffers the entire response; v2 streams.
6. Every join in production code declares its `kind=` explicitly. The default `innerunique` deduplicates the left side — half of "my join is missing rows" mysteries are this default.
7. CI parses every checked-in `.kql` / `.csl` file with `Microsoft.Azure.Kusto.Language` and fails the build on syntax errors. Schema-aware (`ParseAndAnalyze`) is even better when the workspace tables are static.
8. Time-bounded queries use `query_datetimescope_column` + `query_datetimescope_from/to` request properties to apply the time filter at the API boundary, not inside trustable-but-not-mandatory `where` clauses authored by users.
9. Cache hits are explicit: long-running dashboard queries set `query_results_cache_max_age` to leverage server-side cache; "give me fresh data" UIs set `query_results_cache_force_refresh=true`. Default behavior is implicit and surprises engineers.
10. Management commands (anything starting with `.`) go through `/v1/rest/mgmt`, never embedded inside query text. The `.`-prefix is a deliberate security boundary — keep it.

If a PR / runbook / dashboard / alert / library you are reviewing violates any of these, flag them before anything else.

---

## WHEN TO USE THIS SKILL

| Scenario | Use this skill? |
|----------|-----------------|
| Hand-rolling an HTTP client against `/v2/rest/query` | **Yes** |
| Calling Kusto / Log Analytics / App Insights from any language SDK | **Yes** |
| Writing a `.kql` / `.csl` file that ships in source | **Yes** |
| Authoring an Azure Monitor or Sentinel alert rule | **Yes** |
| Building a workbook / dashboard / Grafana panel that runs KQL | **Yes** |
| Adding a CI gate that validates KQL syntax | **Yes** |
| Debugging "my query returned 200 OK but no data" | **Yes** |
| Investigating why a join silently drops rows | **Yes** |
| Tuning a slow KQL query | **Yes** |
| Wrapping `az monitor log-analytics query` in a helper script | **Yes** |
| Building a parser-driven KQL editor with Monaco / VS Code | **Yes** |
| Streaming ingestion to a Kusto cluster | **Partially** — apply only the auth + endpoint sections; ingestion is a separate skill |
| Authoring T-SQL that gets translated to KQL via `query_language=sql` | **Yes** — but T-SQL coverage is partial; verify with `validatepermissions=true` |
| KQL from PromQL-translation tools (Managed Prometheus → Kusto) | **No** — different abstraction; this is the underlying engine, not the consumer surface |

---

## THE REST SURFACE — FIVE ENDPOINTS, TWO ROLE CLASSES

```
                ┌──────────────────────────────────────────────┐
                │           ENGINE ENDPOINT                     │
                │  https://{cluster}.{region}.kusto.windows.net │
                │                                                │
                │  POST /v1/rest/query     ← legacy             │
                │  POST /v2/rest/query     ← current             │
                │  POST /v1/rest/mgmt      ← management commands │
                │  POST /v1/rest/ingest    ← stream ingest        │
                │  GET  /                   ← UI redirect        │
                │  GET  /{db}              ← UI redirect        │
                └──────────────────────────────────────────────┘

                ┌──────────────────────────────────────────────┐
                │       DATA MANAGEMENT ENDPOINT                │
                │  https://ingest-{cluster}.{region}.kusto.windows.net  │
                │                                                │
                │  POST /v1/rest/mgmt      ← only this one      │
                └──────────────────────────────────────────────┘
```

The **Data Management endpoint** is the cluster URI prefixed with `ingest-`. It only accepts management commands — used by the queued ingestion pipeline. Do not point query traffic here.

### Service-specific base URLs and OAuth audiences

| Service | Base URL pattern | OAuth audience |
|---|---|---|
| Azure Data Explorer | `https://{cluster}.{region}.kusto.windows.net` | `https://kusto.kusto.windows.net` |
| Microsoft Fabric Eventhouse / KQL DB | `https://{workspace}.kusto.fabric.microsoft.com` | `https://kusto.kusto.windows.net` |
| Azure Monitor Log Analytics (data plane) | `https://api.loganalytics.io` (or `api.loganalytics.azure.com`) | `https://api.loganalytics.io` |
| Application Insights classic (data plane, deprecated) | `https://api.applicationinsights.io` | `https://api.loganalytics.io` |
| Microsoft Sentinel | uses Log Analytics endpoint underneath | `https://api.loganalytics.io` |

For Log Analytics, the actual query path is **`/v1/workspaces/{workspaceId}/query`** with body `{"query":"...","timespan":"PT1H"}`. The shape is v1-style (one big `tables` array) even though the underlying engine is the same Kusto.

### Authentication

- **Azure AD bearer token** in `Authorization: Bearer <token>` for every call.
- Acquire via MSAL (interactive, device-code, client-credentials, on-behalf-of, MSI/managed identity). The audience determines which token to use.
- Tokens are 1-hour-lived; cache and refresh proactively. Every Microsoft SDK does this; hand-rolled clients should too.
- For Azure CLI: `az account get-access-token --resource <audience>` returns a usable token for scripts.

---

## THE QUERY REQUEST — BODY, HEADERS, PROPERTIES

### Canonical request

```http
POST /v2/rest/query HTTP/1.1
Host: {cluster}.{region}.kusto.windows.net
Authorization: Bearer {token}
Content-Type: application/json; charset=utf-8
Accept: application/json
x-ms-client-request-id: myapp;{uuid}
x-ms-app: myapp/1.0
x-ms-user: user@contoso.com

{
  "db": "MyDatabase",
  "csl": "Requests | where TimeGenerated > ago(1h) | take 100",
  "properties": {
    "Options": {
      "servertimeout": "00:04:00",
      "results_progressive_enabled": true,
      "truncationmaxrecords": 500000,
      "request_app_name": "myapp/v1.0",
      "request_user": "user@contoso.com",
      "query_now": "2026-05-02T19:00:00Z",
      "query_datetimescope_column": "TimeGenerated",
      "query_datetimescope_from": "2026-05-02T18:00:00Z",
      "query_datetimescope_to": "2026-05-02T19:00:00Z"
    },
    "Parameters": {
      "minDuration": 1000
    }
  }
}
```

### The full request-property catalogue (under `properties.Options`)

#### Time / size / timeout

| Property | Type | What it controls |
|---|---|---|
| `servertimeout` | `timespan` | Default **4 minutes**, max **1 hour**. Hard ceiling. |
| `norequesttimeout` | `bool` | Sets timeout to maximum (1h). |
| `truncationmaxrecords` | `long` | Default **500,000 rows** before truncation. |
| `truncationmaxsize` | `long` | Default **64 MB** result size. |
| `notruncation` | `bool` | Disable result-set truncation entirely. **Dangerous in production** — produces massive payloads. |
| `query_take_max_records` | `long` | Hard cap on rows returned, regardless of `take` operator. |

#### Determinism / time scoping

| Property | Type | Purpose |
|---|---|---|
| `query_now` | `datetime` | Override `now()` — **critical for deterministic queries / replays / golden-dataset tests**. |
| `query_datetimescope_column` | `string` | Column name for the auto-applied time filter. |
| `query_datetimescope_from` | `datetime` | Auto-applied lower bound. |
| `query_datetimescope_to` | `datetime` | Auto-applied upper bound. |

The `datetimescope` triple is the doc-recommended way to scope a query to a time window without trusting user-authored `where` clauses to do it correctly.

#### Streaming / progressive

| Property | Type | Purpose |
|---|---|---|
| `results_progressive_enabled` | `bool` | Switch v2 response to streaming frames (vs single DataTable). |
| `query_results_progressive_row_count` | `long` | Hint for rows per progressive update. |
| `query_results_progressive_update_period` | `timespan` | Hint for how often to send progress frames. |

#### Caching

| Property | Type | Purpose |
|---|---|---|
| `query_results_cache_max_age` | `timespan` | Cache hits within this window are served instead of re-running. |
| `query_results_cache_force_refresh` | `bool` | Force a cache miss for this request. |
| `query_results_cache_per_shard` | `bool` | Per-extent cache instead of per-query. |

#### Security / sandboxing

| Property | Type | Purpose |
|---|---|---|
| `request_readonly` | `bool` | Block writes. |
| `request_readonly_hardline` | `bool` | Strict read-only — disables plugins, sandboxed code, anything noncompliant. **Use this for untrusted KQL.** |
| `request_external_data_disabled` | `bool` | Block `externaldata()` operator and external tables. |
| `request_external_table_disabled` | `bool` | Block external tables only. |
| `request_callout_disabled` | `bool` | Block any outbound HTTP from the query (`http_request`, etc.). |
| `request_remote_entities_disabled` | `bool` | Block `cluster()/database()` cross-cluster queries. |
| `request_sandboxed_execution_disabled` | `bool` | Block Python / R / sandboxed plugins. |
| `request_impersonation_disabled` | `bool` | Block on-behalf-of impersonation downstream. |
| `request_force_row_level_security` | `bool` | Enforce RLS even if policy is disabled. |
| `request_block_row_level_security` | `bool` | Block access to RLS-protected tables. |
| `validatepermissions` | `bool` | Returns `OK` / `Incomplete` / `KustoRequestDeniedException` without running. |

#### Reporting / observability

| Property | Type | Purpose |
|---|---|---|
| `request_app_name` | `string` | Surfaces in `.show queries`. **Always set in production code.** |
| `request_user` | `string` | Surfaces in `.show queries`. |
| `request_description` | `string` | Arbitrary text describing the request. |
| `query_log_query_parameters` | `bool` | Log parameter values for `.show queries` audit. |

#### Behavioural

| Property | Type | Purpose |
|---|---|---|
| `query_language` | `string` | `csl` (default), `kql`, or `sql`. SQL mode parses limited T-SQL. |
| `queryconsistency` | `string` | `strongconsistency` (default), `weakconsistency`, `weakconsistency_by_session_id`. Weak modes return faster from cache but may miss recent writes. |
| `best_effort` | `bool` | Tolerate unresolvable `union` legs — query proceeds with what it can find. |
| `materialized_view_shuffle_query` | `dynamic` | Hint shuffle keys for materialized views. |
| `results_error_reporting_placement` | `string` | `in_data`, `end_of_table`, or `end_of_dataset`. |

### Properties that CANNOT be set via `set` statement inside KQL

These must be HTTP request properties, not in the query text:

```
norequesttimeout
queryconsistency
query_language
query_log_query_parameters
query_weakconsistency_session_id
request_app_name
request_readonly
request_readonly_hardline
request_user
results_progressive_enabled
results_v2_fragment_primary_tables
servertimeout
truncationmaxsize
```

### Mandatory headers

| Header | Purpose |
|---|---|
| `Content-Type: application/json; charset=utf-8` | Required body type |
| `Accept: application/json` | Required response type |
| `Authorization: Bearer {token}` | AAD bearer for the right audience |
| `Host: {cluster}.{region}.kusto.windows.net` | Target |
| `x-ms-client-request-id: myapp;{uuid}` | **Load-bearing** — surfaces in `.show queries`, error context, support correlation |
| `x-ms-app: myapp/1.0` | Application name fallback |
| `x-ms-user: user@contoso.com` | User identity for audit |

For progressive mode, set `Accept: application/json; format=fragmented` to opt into the frame protocol explicitly.

---

## THE V2 RESPONSE SHAPE — THE MOST-MISUNDERSTOOD PART

Logically: a **DataSet** containing N **Tables**. Each Table has a `TableKind`:

```
PrimaryResult                 ← your actual data; one per tabular statement
QueryCompletionInformation    ← success/cancel/errors/resource accounting (analogous to QueryStatus in v1)
QueryProperties               ← visualization hints from `render`, cursor info
QueryTraceLog                 ← perf-trace info (only with perftrace=true)
QueryPerfLog                  ← per-operator timing
QueryPlan                     ← .show queryplan style output
TableOfContents               ← server-internal
Unknown                       ← future-compat
```

### Plain mode (default) — one frame per table

```json
[
  { "FrameType": "DataSetHeader", "Version": "v2.0", "IsProgressive": false },
  {
    "FrameType": "DataTable",
    "TableId": 0,
    "TableKind": "PrimaryResult",
    "TableName": "PrimaryResult",
    "Columns": [{"ColumnName":"TimeGenerated","ColumnType":"datetime"}, ...],
    "Rows": [["2026-05-02T19:00:00Z", ...], ...]
  },
  { "FrameType": "DataTable", "TableKind": "QueryProperties", ... },
  { "FrameType": "DataTable", "TableKind": "QueryCompletionInformation", ... },
  { "FrameType": "DataSetCompletion", "HasErrors": false, "Cancelled": false }
]
```

### Progressive mode (`results_progressive_enabled=true`) — streaming

```json
[
  { "FrameType": "DataSetHeader", "Version": "v2.0", "IsProgressive": true },
  { "FrameType": "TableHeader", "TableId": 1, "TableKind": "PrimaryResult", "Columns": [...] },
  { "FrameType": "TableFragment", "TableId": 1, "TableFragmentType": "DataAppend", "Rows": [...] },
  { "FrameType": "TableProgress", "TableId": 1, "TableProgress": 23.4 },
  { "FrameType": "TableFragment", "TableId": 1, "TableFragmentType": "DataAppend", "Rows": [...] },
  { "FrameType": "TableProgress", "TableId": 1, "TableProgress": 67.2 },
  { "FrameType": "TableFragment", "TableId": 1, "TableFragmentType": "DataReplace", "Rows": [...] },
  { "FrameType": "TableCompletion", "TableId": 1, "RowCount": 12345 },
  { "FrameType": "TableHeader", "TableId": 2, ... },
  ...
  { "FrameType": "DataSetCompletion", "HasErrors": false, "Cancelled": false }
]
```

**Critical subtlety: `TableFragmentType` can be `DataReplace`.** The server uses replace when it has refined an aggregate (e.g. an early estimate for a top-level `summarize` is replaced with exact values). A naïve "concatenate all fragments" client gets wrong totals on replace events.

**Correct progressive consumer pseudocode:**

```
buffer = []
for frame in stream:
  if frame.FrameType == "TableHeader":
    buffer = []
  elif frame.FrameType == "TableFragment":
    if frame.TableFragmentType == "DataAppend":
      buffer.extend(frame.Rows)
    elif frame.TableFragmentType == "DataReplace":
      buffer = list(frame.Rows)
  elif frame.FrameType == "TableCompletion":
    yield buffer
```

### The three-layer error model

1. **Transport (4xx/5xx)** — body is `OneApiErrors`-shaped JSON:

```json
{
  "error": {
    "code": "General_BadRequest",
    "message": "Request is invalid and cannot be executed.",
    "@type": "Kusto.Data.Exceptions.KustoBadRequestException",
    "@message": "Semantic error: SEM0100: 'table' operator: Failed to resolve table expression named 'aaa'",
    "@context": { "timestamp": "...", "clientRequestId": "...", "activityId": "..." },
    "@permanent": true,
    "innererror": {
      "code": "SEM0100",
      "@errorCode": "SEM0100",
      "@errorMessage": "'table' operator: Failed to resolve table expression named 'aaa'"
    }
  }
}
```

The inner error code is the actionable piece (e.g. `SEM0100` = unresolved table reference).

2. **In-band errors with HTTP 200** — `DataSetCompletion.HasErrors=true`, `OneApiErrors` populated. **A check-only-the-status reader misses these.** Always inspect `DataSetCompletion`.

3. **Per-row partial errors** — `results_error_reporting_placement` controls placement. `in_data` mixes them into the result rows. `end_of_table` puts them after each table.

### Response headers

```
x-ms-client-request-id: <echoed from request, or server-generated>
x-ms-activity-id: <unique per response, even if request-id is reused>
```

Both **always present** regardless of success/failure. Capture them — they're the only correlation handles when filing a support ticket.

---

## V1 VS V2 — WHEN TO USE WHICH

| | v1 | v2 |
|---|---|---|
| Path | `/v1/rest/query` | `/v2/rest/query` |
| Body shape | `{Tables:[{TableName, Columns, Rows}]}` (one big object) | Frame array (header + tables + completion) |
| Progressive | No | Optional via `results_progressive_enabled` |
| Stream-friendly | Buffer entire response | Parse frame-by-frame, can backpressure |
| Used by | Older SDKs, Log Analytics endpoint | Modern SDKs, ADX Web UI, large queries |

**Recommendation:** v2 for new code unless integrating with legacy v1-shape consumers. **For Log Analytics specifically**, the public endpoint is `/v1/workspaces/{id}/query` which is v1-style — same engine, simpler shape.

---

## THE LANGUAGE — KQL ESSENTIALS

### Five universal facts the docs emphasize

1. **Case-sensitive everywhere.** `Requests` ≠ `requests`. `where` ≠ `Where`. `count` ≠ `Count`.
2. **Pipe (`|`) data flow.** Operator order matters for both correctness and performance. Filter (`where`) early, project (`project`/`extend`) late, aggregate (`summarize`) last.
3. **Statements separated by `;`.** Three kinds: tabular expression, `let`, `set`.
4. **Management commands start with `.`** (`.show tables`, `.create table`). They cannot start with a query character. **This is a deliberate security boundary** — you cannot embed `.drop table` inside a query.
5. **Read-only by default.** Queries cannot mutate. `.set/.append` and friends are management commands, gated separately.

### Operator catalogue

**Tabular shaping:**
- `where`, `project`, `project-away`, `project-rename`, `extend`
- `take` (random sample! — not the most-recent), `top` (sorted), `sort by` / `order by`
- `distinct`, `count`, `summarize`
- `union`, `join`, `range`, `materialize` (cache a tabular subexpression)
- `mv-expand`, `mv-apply`, `pack`, `pack_array`, `bag_unpack`
- `parse`, `parse_json`, `parse_url`, `parse_path`
- `serialize`, `as`, `evaluate`

**Aggregations** (inside `summarize`):
- `count()`, `dcount(col)`, `dcountif(col, predicate)`, `count_distinct`
- `sum`/`sumif`, `avg`/`avgif`, `min`, `max`, `stdev`, `variance`
- `percentile(col, 95)`, `percentiles(col, 50, 95, 99)`
- `make_list`, `make_set`, `make_bag`
- `arg_max(metric, *)`, `arg_min(metric, *)` — return entire row at the extremum
- `hll(col)` — HyperLogLog for streaming dcount
- `tdigest`/`percentile_tdigest` — approximate percentiles

**Time-series:**
- `bin(timestamp, 5m)`, `bin_at(timestamp, 5m, datetime(2026-05-02))`
- `make-series x = avg(v) on ts step 1m by group`
- `series_decompose`, `series_decompose_anomalies`, `series_outliers`
- `series_fit_line`, `series_iir`, `series_fir`
- `startofday`, `endofday`, `startofweek`
- `now()`, `ago(1h)`, `datetime(2026-05-02T19:00:00Z)`

**Joins** with explicit `kind=`:

| Kind | Behavior |
|---|---|
| `innerunique` (default) | **Left side deduplicated by join keys** before joining. Surprising. |
| `inner` | True inner join, no dedup |
| `leftouter` | Left preserved |
| `rightouter` | Right preserved |
| `fullouter` | Both preserved |
| `leftanti` | Left rows with no match — useful for "missing" |
| `rightanti` | Right rows with no match |
| `leftsemi` | Left rows with at least one match (no right cols) |
| `rightsemi` | Right rows with at least one match |
| `cross` | Cartesian product |

**Always declare `kind=` explicitly.** The `innerunique` default has caused more silent data loss than any other KQL feature.

**String ops:**
- `strcat`, `substring`, `strlen`, `tolower`, `toupper`, `split`
- `replace_string`, `replace_regex`
- `extract(regex, captureIndex, col)`, `extract_all`
- `format_datetime`, `format_timespan`

**Conditional:**
- `iff(cond, a, b)` (or `iif` — same thing)
- `case(c1, v1, c2, v2, default)`
- `coalesce(a, b, c)`

**Membership:**
- `in`, `!in`, `in~` (case-insensitive)
- `has` (token-aware, **fast**, indexed), `!has`, `has_cs`, `has_any`, `has_all`
- `contains` (substring, **slower**, scan), `!contains`, `contains_cs`
- `startswith`, `endswith`, `matches regex`

**Prefer `has` over `contains`** — `has` uses the per-extent token index. `contains` does a full scan.

**Schema / metadata:**
- `getschema`, `print 1`, `.show tables`, `.show columns`
- Cross-cluster: `cluster('other').database('Db').Table`
- `database()`, `cluster()`, `table()`

**Render directives** (visualization hints emitted in `QueryProperties` table):
- `render timechart`, `render barchart`, `render piechart`
- `render columnchart`, `render scatterchart`, `render areachart`
- `render table` (force tabular)
- `with(title="...", xtitle="...", ytitle="...")` modifiers

**`let` for parameters and reuse:**

```kql
let win = 1h;
let svc = "hex-scaffold";
let topRoles = (n:int) {
  AppRequests | summarize c = count() by AppRoleName | top n by c
};
topRoles(5)
```

### Performance heuristics

1. **Filter early on indexed columns.** `where TimeGenerated > ago(1h)` first; the server skips entire extents.
2. **`has` >> `contains`.** Token index vs full scan.
3. **`summarize` with high-cardinality `by` blows up memory.** Use `hint.shufflekey=col` to distribute.
4. **`take` returns arbitrary rows.** For "most recent N", use `top N by TimeGenerated desc`.
5. **`materialize(...)` repeated subqueries.** Computes once, reused per reference.
6. **Avoid `extend` before `where`** if the new column is only used after filtering — wasted compute.
7. **`project` early to reduce row width.** Especially before `join` or `summarize` over many columns.
8. **`union withsource=col Tables` is cheap;** `union *` enumerates all tables.

### Idiomatic style

```kql
let win = 1h;
let svc = "hex-scaffold";
AppRequests
| where TimeGenerated > ago(win)
| where AppRoleName == svc
| where Success == false
| summarize
    failures   = sum(ItemCount),
    distinct_clients = dcount(ClientIP),
    sample_url = any(Url)
  by ResultCode, bin(TimeGenerated, 5m)
| order by TimeGenerated desc, failures desc
```

---

## THE STANDALONE PARSER — `Microsoft.Azure.Kusto.Language`

Apache-2.0 NuGet package. Powers the ADX Web UI, VS Code KQL extension, and any tool that needs to validate, autocomplete, or rewrite KQL **without a server round-trip**.

### Entry-point classes

| Class | Purpose |
|---|---|
| `KustoCode` | Represents parsed query with syntax tree + analysis results |
| `GlobalState` | Immutable container holding cluster/database/table/column/function definitions |
| `Symbol` | Base for all named entities (tables, columns, functions) |
| `TypeSymbol` | Data type representation |
| `TableSymbol` | Table with columns and schema |
| `ColumnSymbol` | Column within a table |
| `FunctionSymbol` | User-defined or built-in function |
| `ClusterSymbol` | Cluster containing databases |
| `DatabaseSymbol` | Database containing tables and functions |

### Core methods

| Method | Purpose |
|---|---|
| `KustoCode.Parse(text)` | Syntax-only parse; no schema needed |
| `KustoCode.ParseAndAnalyze(text, globals)` | Full parse + semantic analysis with custom schema |
| `code.GetDiagnostics()` | Return all syntax + semantic errors |
| `code.GetSyntaxDiagnostics()` | Syntax errors only |
| `code.Syntax` | Root of parsed syntax tree |
| `code.Globals` | The `GlobalState` used for analysis |

**Tree navigation:**
- `GetDescendants<T>(predicate)` — Find all descendants of type T
- `GetAncestors()` — Walk up
- `WalkNodes()` — Stack-safe traversal
- `GetTokenAt(pos)`, `GetNodeAt(pos)` — Query by position (for editor tooltips)

### Build a `GlobalState` with custom schema

```csharp
using Kusto.Language;
using Kusto.Language.Symbols;

var requests = new TableSymbol(
    "AppRequests",
    "(TimeGenerated: datetime, Name: string, ResultCode: int, DurationMs: real, " +
    "ItemCount: int, AppRoleName: string, AppRoleInstance: string, Success: bool)"
);
var dependencies = new TableSymbol(
    "AppDependencies",
    "(TimeGenerated: datetime, Type: string, Target: string, Name: string, " +
    "DurationMs: real, ItemCount: int, AppRoleName: string, Success: bool)"
);

var workspace = new DatabaseSymbol("DefaultWorkspace", requests, dependencies);
var globals   = GlobalState.Default.WithDatabase(workspace);
```

### Parse + validate (the CI-gate pattern)

```csharp
var query = "AppRequests | where TimeGenerated > ago(1h) | take 100";
var code  = KustoCode.ParseAndAnalyze(query, globals);

var errors = code.GetDiagnostics()
    .Where(d => d.Severity == DiagnosticSeverity.Error)
    .ToList();

if (errors.Any())
{
    foreach (var e in errors)
        Console.Error.WriteLine($"{e.Start}: {e.Code} {e.Message}");
    Environment.Exit(1);
}
```

### Walking the tree for lineage

```csharp
SyntaxElement.WalkNodes(code.Syntax, fnBefore: n =>
{
    if (n is NameReference nr && nr.ReferencedSymbol is ColumnSymbol c)
    {
        Console.WriteLine($"References column {c.Name} of type {c.Type}");
    }
});
```

### What the parser does NOT do

- **Does not fetch schema from a live cluster.** Use the **`Kusto.Toolkit`** companion NuGet (community, by `mattwar`) for `LoadDatabaseAsync()` against a real server.
- **Does not execute queries.** Pair with `Microsoft.Azure.Kusto.Data` for execution.
- **Does not implement plugins** — `python_eval`, `R_eval`, `http_request` are server-side only.

### Sister NuGets and SDKs

| Package | Purpose |
|---|---|
| `Microsoft.Azure.Kusto.Language` | Parser + semantic analyzer (this lib) |
| `Microsoft.Azure.Kusto.Data` | Execution: `KustoConnectionStringBuilder`, `CreateCslQueryProvider`, `ExecuteQuery` |
| `Microsoft.Azure.Kusto.Ingest` | Bulk + streaming ingestion |
| `Microsoft.Azure.Kusto.Tools` | CLI tools (Kusto.Cli, etc.) |

**Cross-language SDKs:**

| Language | Package |
|---|---|
| Python | `azure-kusto-data`, `azure-kusto-ingest` |
| Python (Log Analytics-specific, cleaner API) | `azure-monitor-query` |
| Java | `com.microsoft.azure.kusto:kusto-data` |
| Node/TypeScript | `azure-kusto-data` |
| Go | `github.com/Azure/azure-kusto-go` |
| Rust | community SDK, not Microsoft-supported |

All Microsoft-published SDKs internally use **v2 progressive mode** by default, handle token refresh, and expose typed iterators. Hand-rolling against `/v2/rest/query` is rarely worth it unless embedding in a runtime that doesn't have an SDK.

---

## STANDARD DIAGNOSTIC RECIPES

Idiomatic queries against the most common workspace tables.

### Recent server errors with sample URL (Application Insights)

```kql
AppRequests
| where TimeGenerated > ago(1h)
| where AppRoleName == "hex-scaffold"
| where Success == false
| summarize
    failures   = sum(ItemCount),
    sample_url = any(Url),
    distinct_clients = dcount(ClientIP)
  by ResultCode, bin(TimeGenerated, 5m)
| order by TimeGenerated desc, failures desc
```

### Top-time queries in the last 6h

```kql
AppDependencies
| where TimeGenerated > ago(6h)
| where AppRoleName == "hex-scaffold"
| where Type == "SQL"
| summarize
    total_ms = sum(DurationMs),
    p95      = percentile(DurationMs, 95),
    calls    = sum(ItemCount)
  by Name, bin(TimeGenerated, 15m)
| top 20 by total_ms
```

### Wait-event correlated to query (Postgres Flex via diagnostic settings)

```kql
PGSQLQueryStoreWaits
| where TimeGenerated > ago(24h)
| summarize total_wait_ms = sum(call_count_d)
  by event_type_s, event_s, query_id_d
| top 20 by total_wait_ms
| join kind=leftouter (
    PGSQLQueryStoreRuntime
    | summarize arg_max(TimeGenerated, query_sql_text_s) by query_id_d
  ) on query_id_d
| project event_type_s, event_s, total_wait_ms, query_sql_text_s
```

### Cross-table operation tracing (App Insights)

```kql
let opId = "abc123-...";
union AppRequests, AppDependencies, AppExceptions, AppTraces
| where OperationId == opId
| project TimeGenerated, ItemType=tostring(parse_json(_BilledSize)), Name, DurationMs, ResultCode
| order by TimeGenerated asc
```

### Anomaly detection on a metric

```kql
let win    = 7d;
let bucket = 5m;
AppMetrics
| where TimeGenerated > ago(win)
| where Name == "requests/duration"
| make-series avg_ms = avg(Value) default=0 on TimeGenerated step bucket
| extend (anomalies, score, baseline) = series_decompose_anomalies(avg_ms, 1.5)
| render timechart with(title="Request duration anomalies")
```

---

## ANTI-PATTERNS

| Anti-pattern | Why it bites | Do this instead |
|---|---|---|
| Reading only HTTP status to determine success | 200 OK can have `DataSetCompletion.HasErrors=true` with partial data | Always inspect `DataSetCompletion.HasErrors` and `OneApiErrors` even on 200 |
| Implicit `kind` on `join` | Default is `innerunique` which deduplicates the left side | Always specify `kind=inner|leftouter|...` explicitly |
| `where col contains "x"` for hot filters | Full scan, no index | `where col has "x"` — uses token index |
| `take 100` for "most recent" | `take` returns arbitrary rows, not sorted | `top 100 by TimeGenerated desc` |
| Passing user-authored time filters in the KQL string | User can omit, accidentally widen, or remove them | Use `query_datetimescope_column` + `_from` + `_to` request properties |
| Concatenating progressive `TableFragment` rows naïvely | `DataReplace` overwrites prior fragments; concatenation gives wrong totals | Branch on `TableFragmentType`: `DataAppend` → extend, `DataReplace` → reset buffer |
| Running untrusted KQL with `request_readonly=true` only | Plugins, sandboxed code, callouts can still leak data | Use `request_readonly_hardline=true` for strict mode |
| Not setting `x-ms-client-request-id` | No correlation when filing a support ticket | Always set, format `<app>;<uuid>` |
| Calling `notruncation=true` "to get all the data" | Produces huge payloads, OOMs clients, hammers cluster | Page via `top N by ts desc` repeatedly with cursor-style pagination |
| Embedding management commands inside query text | `.`-prefix is a security boundary; cannot start a query | Send to `/v1/rest/mgmt` separately |
| Buffering the entire v2 response into memory before parsing | Defeats progressive mode; slow + OOM-prone for large queries | Stream-parse with a JSON streaming parser; consume frames as they arrive |
| Using `now()` directly in unit-tested KQL | Non-deterministic; tests flake at midnight UTC | Set `query_now` request property for replays / tests |
| Caching at the client when the server already does it | Wasted memory, stale results | Set `query_results_cache_max_age` on the request; let the server cache |
| Writing the same complex subquery twice in a `union` or `join` | Computed twice | Wrap in `let` + `materialize()` |
| Hand-rolling against `/v2/rest/query` when an SDK exists | Re-implementing token refresh, frame parsing, retries | Use `Microsoft.Azure.Kusto.Data` / `azure-kusto-data` / `azure-monitor-query` |
| Treating Log Analytics like raw ADX | Different endpoint (`/v1/workspaces/{id}/query`), v1-style response, different audience | Use the v1 path or use `azure-monitor-query` SDK |
| Filtering App Insights `AppRoleName == "<service>"` against a workspace fed by the **.NET OpenTelemetry distro** (`Azure.Monitor.OpenTelemetry.Exporter`) | The exporter packs `service.namespace` + `service.name` as `"[<namespace>]/<service>"` (e.g. `"[hex-scaffold]/Hex.Scaffold"`), not the bare service name. `==` returns 0 rows silently; you conclude telemetry is broken when it is just routed under a different role string | Confirm the exact string first — `AppRequests \| summarize cnt=count() by AppRoleName \| order by cnt desc \| take 10` — then filter `where AppRoleName startswith "[<namespace>]"`, or `has "<namespace>"` for token-indexed scans. Same gotcha applies to `AppDependencies`, `AppExceptions`, and any cross-table join that filters on `AppRoleName` |

---

## VERIFICATION CHECKLIST — before declaring a Kusto integration complete

- [ ] All API calls set `x-ms-client-request-id` (format: `<app>;<uuid>`) and `request_app_name`
- [ ] All API calls inspect `DataSetCompletion.HasErrors` even when HTTP status is 200
- [ ] Untrusted KQL paths use `request_readonly_hardline=true`
- [ ] Time-bounded queries use `query_datetimescope_column` + `_from` + `_to` request properties (not just user-authored `where`)
- [ ] Every `join` declares `kind=` explicitly
- [ ] Hot-path filters use `has` (or `==`) instead of `contains`
- [ ] Long-running queries use `results_progressive_enabled=true` and the consumer correctly handles `DataReplace` fragments
- [ ] Result-size-bounded queries set `truncationmaxrecords` and `truncationmaxsize` to reasonable values; `notruncation` is **not** set in production code
- [ ] Cache behavior is explicit: `query_results_cache_max_age` for dashboards, `query_results_cache_force_refresh=true` for "fresh data" UIs
- [ ] CI parses every checked-in `.kql` / `.csl` file with `Microsoft.Azure.Kusto.Language.KustoCode.Parse` (syntax) or `ParseAndAnalyze` (semantic, with workspace schema)
- [ ] Audit logs (`.show queries`) can identify your traffic via `request_app_name` / `request_user`
- [ ] Long-form telemetry queries are deterministic via `query_now` for tests / replays
- [ ] Errors surface to the user with both `code` and `innererror.code` (e.g. `SEM0100`)

---

## CHEAT SHEET — `az monitor log-analytics query` against a workspace

```bash
WS_GUID=7104c6dc-8269-4283-9699-1840c52bbbe0  # Log Analytics workspace customerId

az extension add --name log-analytics --only-show-errors

az monitor log-analytics query \
  --workspace "$WS_GUID" \
  --analytics-query 'AppRequests | where TimeGenerated > ago(1h) | take 10' \
  --timespan PT1H \
  -o json
```

Under the hood this hits `https://api.loganalytics.io/v1/workspaces/{id}/query` with audience `https://api.loganalytics.io`, using the AAD token from `az login`. Returns v1-style `{tables:[...]}`.

For programmatic use prefer:

```python
# Python — azure-monitor-query (cleaner than azure-kusto-data for Log Analytics)
from azure.identity import DefaultAzureCredential
from azure.monitor.query import LogsQueryClient
from datetime import timedelta

client = LogsQueryClient(DefaultAzureCredential())
response = client.query_workspace(
    workspace_id="7104c6dc-8269-4283-9699-1840c52bbbe0",
    query="AppRequests | where TimeGenerated > ago(1h) | take 10",
    timespan=timedelta(hours=1),
)
for table in response.tables:
    for row in table.rows:
        print(row)
```

```csharp
// .NET — Azure.Monitor.Query
using Azure.Identity;
using Azure.Monitor.Query;
using Azure.Monitor.Query.Models;

var client = new LogsQueryClient(new DefaultAzureCredential());
LogsQueryResult result = await client.QueryWorkspaceAsync(
    workspaceId: "7104c6dc-8269-4283-9699-1840c52bbbe0",
    query: "AppRequests | where TimeGenerated > ago(1h) | take 10",
    timeRange: new QueryTimeRange(TimeSpan.FromHours(1))
);
foreach (var row in result.Table.Rows) { /* ... */ }
```

---

## REFERENCES (canonical, pin in any runbook)

- [Kusto REST API overview](https://learn.microsoft.com/en-us/kusto/api/rest/)
- [Request properties (full list)](https://learn.microsoft.com/en-us/kusto/api/rest/request-properties)
- [Query V2 HTTP response (frame protocol)](https://learn.microsoft.com/en-us/kusto/api/rest/response-v2)
- [KQL overview](https://learn.microsoft.com/en-us/kusto/query/)
- [`Microsoft.Azure.Kusto.Language` GitHub](https://github.com/microsoft/kusto-query-language)
- [`Kusto.Toolkit` (live-schema loader)](https://github.com/mattwar/Kusto.Toolkit)
- [`azure-monitor-query` Python SDK](https://learn.microsoft.com/en-us/python/api/overview/azure/monitor-query-readme)
- [`Azure.Monitor.Query` .NET SDK](https://learn.microsoft.com/en-us/dotnet/api/overview/azure/monitor.query-readme)
