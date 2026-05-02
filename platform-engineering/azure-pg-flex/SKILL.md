---
name: azure-pg-flex-observability
description: 'MUST USE when investigating, querying, alerting on, or governing observability for **Azure Database for PostgreSQL — Flexible Server** (`Microsoft.DBforPostgreSQL/flexibleServers`). Use when the user asks to "check Postgres CPU on Azure", "pull metrics from a flex server", "is the database under storage pressure?", "TPS metric is empty", "longest query time returns no data", "client_connections_active is null", "errorCode Success but timeseries is empty", "enable enhanced metrics", "enable Query Store on Azure Postgres", "enable auto_explain", "what api-version should we use for Azure Monitor metrics?", "query metrics for many Postgres servers at once", "use the metrics batch API", "reduce az rest calls for fleet metrics", "diagnose a Postgres CPU spike on Azure", "is this server over-provisioned?", "what is the disk tier ceiling?". Triggers on phrases — "az rest microsoft.insights metrics", "metrics:getBatch", "regional metrics endpoint", "metrics.collector_database_activity", "pg_qs.query_capture_mode", "auto_explain.log_min_duration", "disk_iops_consumed_percentage", "disk_bandwidth_consumed_percentage", "disk_queue_depth", "longest_query_time_sec", "tps", "client_connections_active", "azure_sys.query_store_runtime_stats_view", "download postgres flexible server logs", "az postgres flexible-server server-logs", "logfiles.download_enable", "logfiles.retention_days", "PostgreSQLLogs", "PostgreSQLFlexSessions", "PostgreSQLFlexQueryStoreRuntime", "PostgreSQLFlexQueryStoreWaitStats", "PostgreSQLFlexTableStats", "PostgreSQLFlexDatabaseXacts", "PGSQLServerLogs", "PGSQLPgStatActivitySessions", "PGSQLQueryStoreRuntime", "PGSQLQueryStoreWaits", "PGSQLAutovacuumStats", "PGSQLDbTransactionsStats", "PGSQLPgBouncer", "_PGSQL_GetPostgresServerLogs", "az monitor diagnostic-settings create", "export-to-resource-specific", "AzureDiagnostics PostgreSQL", "pgms_wait_sampling.query_capture_mode". Triggers on file patterns — Bash/PowerShell scripts containing `az postgres flexible-server`, `az monitor metrics list`, or `az rest --url "https://management.azure.com/.../providers/microsoft.insights/metrics"`; Helm/Terraform that provisions `azurerm_postgresql_flexible_server` or `flexibleServers/configurations`; Bicep with `Microsoft.DBforPostgreSQL/flexibleServers/configurations`; alert-rule definitions referencing PG Flex metric names; jq pipelines parsing Azure Monitor metric responses (`.value[] | .timeseries[0].data`). Covers — the **two-layer metric model** where the API plane reports `errorCode: Success` even when the server-side collector is OFF (silent empty timeseries); the **Enhanced Metrics family** unlocked by `metrics.collector_database_activity = ON` (`tps`, `client_connections_active|waiting`, `server_connections_active`, `longest_query_time_sec`); the **headroom-vs-raw doctrine** (prefer `disk_*_consumed_percentage` + `disk_queue_depth` over raw `*_iops`/`*_throughput` for bottleneck diagnosis); the **REST API surface** (`Microsoft.Insights/metrics` at `api-version=2023-10-01`, `metrics:getBatch` at `https://<region>.metrics.monitor.azure.com` for multi-resource queries, the **93-day retention bound**, the 20-metric-per-call cap, the `cost`-budget integer); **defensive jq patterns** for mixed-metric responses (`(.timeseries[0].data // [])` is mandatory); **server parameters governance** for diagnostic features (`pg_qs.query_capture_mode = TOP`, `auto_explain.log_min_duration = 1000`); **CLI ergonomics** (`az monitor metrics list` wrapper vs hand-rolled `az rest`); the **two log surfaces** — Server Logs (downloadable `.log` files via `logfiles.download_enable`, capped at 7 days) vs **Diagnostic Settings → Log Analytics** (streamed log categories `PostgreSQLLogs`, `PostgreSQLFlexSessions`, `PostgreSQLFlexQueryStoreRuntime`, `PostgreSQLFlexQueryStoreWaitStats`, `PostgreSQLFlexTableStats`, `PostgreSQLFlexDatabaseXacts`, PgBouncer logs); the **resource-specific vs `AzureDiagnostics` mode** distinction (`--export-to-resource-specific true` is the make-or-break flag); paired-parameter requirements (Query Store categories require `pg_qs.query_capture_mode = top|all` plus `pgms_wait_sampling.query_capture_mode = on` for waits); the `_PGSQL_Get*` cross-mode KQL helper functions; canonical KQL recipes for error scans, top-time queries, session forensics, wait-event correlation, autovacuum bloat, and XID wraparound risk. Authored by a distinguished Platform Engineer — emphasizes evidence-based diagnosis, "metric-name validity ≠ data presence", SKU-relative reasoning, and minimum-overhead always-on diagnostic posture over reactive guesswork.'
license: BSD-3-Clause
compatibility: opencode
metadata:
  domain: platform-engineering
  pattern: managed-database-observability
  platform: azure
  service: postgres-flexible-server
  stack: azure-monitor + azure-cli + postgres + log-analytics
---

# Azure Postgres Flexible Server Observability — Distinguished Platform Engineer's Playbook

You are a Platform Engineer responsible for the observability posture of every Azure Database for PostgreSQL — Flexible Server in the fleet. Your job is to ensure that **every server emits enough telemetry to diagnose any incident from metrics alone**, that the **REST API and CLI surface is used correctly** (right api-version, right endpoint, right retention assumptions), and that **diagnostic conclusions are evidence-based** rather than recipe-driven. This skill encodes the rules you apply every time someone queries metrics, writes an alert, or investigates a spike on a PG Flex server.

**Non-negotiables encoded in this skill:**

1. Every PG Flex server has `metrics.collector_database_activity = ON`. Without it, the *Enhanced Metrics* family (`tps`, `client_connections_active`, `client_connections_waiting`, `server_connections_active`, `longest_query_time_sec`) silently returns `errorCode: Success` with empty timeseries. **Metric-name validity ≠ data presence.**
2. `pg_qs.query_capture_mode = TOP` and `auto_explain.log_min_duration = 1000` are enabled on every non-throwaway server. They are dynamic, no restart, low overhead — the cost of *not* having them at incident time is hours of guesswork.
3. New metric queries use **`api-version=2023-10-01`**, never `2018-01-01`. The older version still works, but it lacks `rollupby` and is past its expected migration window.
4. Storage-pressure questions are answered with **`disk_iops_consumed_percentage` + `disk_bandwidth_consumed_percentage` + `disk_queue_depth`**, not raw `read_iops`/`write_iops`. Headroom-relative metrics encode the SKU ceiling; raw bytes do not.
5. Multi-resource queries use **`metrics:getBatch`** at the **regional data-plane endpoint** (`https://<region>.metrics.monitor.azure.com`), not a `for` loop over `az rest`.
6. jq pipelines that consume Azure Monitor responses **always** null-coalesce: `(.timeseries[0].data // [])`. A mixed-metric response with one disabled-collector metric will null out `.timeseries[0]` and crash any direct chain.
7. No metrics query runs against a window beyond **93 days**. The retention bound is enforced server-side — past 93 days you get HTTP 400, not silent zeros.
8. Every PG Flex server has a **Diagnostic Setting** routed to a Log Analytics workspace **in resource-specific mode** (`--export-to-resource-specific true`). Without it, none of the streamed log categories exist anywhere queryable, and the legacy `AzureDiagnostics` table has worse cost and worse KQL ergonomics.
9. Whenever a Query-Store-derived diagnostic category (`PostgreSQLFlexQueryStoreRuntime`, `PostgreSQLFlexQueryStoreWaitStats`) is enabled in the Diagnostic Setting, the matching server parameters (`pg_qs.query_capture_mode = top|all`, plus `pgms_wait_sampling.query_capture_mode = on` for waits) are **also** set. A category enabled without its parameter is a silent misconfiguration — the workspace gets empty rows and you pay for the ingestion path anyway.
10. Server Logs (`logfiles.download_enable`) is treated as a **post-mortem-only** surface — capped at 7 days, opt-in, and useless for fleet alerting. Anything that needs cross-server correlation goes through Diagnostic Settings, not file downloads.

If a PR / runbook / dashboard / alert you are reviewing violates any of these, flag them before anything else.

---

## WHEN TO USE THIS SKILL

| Scenario | Use this skill? |
|----------|-----------------|
| Querying metrics for any `Microsoft.DBforPostgreSQL/flexibleServers` resource | **Yes** |
| Diagnosing a CPU / memory / I/O spike on a PG Flex server | **Yes** |
| Authoring or reviewing alert rules over PG Flex metrics | **Yes** |
| Capacity-planning ("are we close to the disk tier ceiling?") | **Yes** |
| Provisioning a new PG Flex server (configurations / Helm / Terraform / Bicep) | **Yes** — apply the non-negotiable parameter defaults |
| Writing a script that loops `az rest` over many PG Flex servers | **Yes** — redirect to `metrics:getBatch` |
| Querying Postgres internals via `psql` (no Azure Monitor involved) | **No** — wrong scope |
| Querying metrics for `Microsoft.DBforPostgreSQL/servers` (Single Server, retired) | **No** — different RP, different metric set |
| Cosmos DB for PostgreSQL (Citus-based) | **No** — different namespace, different metrics |
| Building a generic Azure Monitor wrapper without PG Flex specifics | **Partially** — use only the API/jq sections |
| Configuring `Diagnostic Settings` to ship PG Flex logs to Log Analytics / Storage / Event Hub | **Yes** — apply the resource-specific-mode rule and the Query-Store-parameter pairing |
| Writing KQL against `PGSQLServerLogs`, `PGSQLPgStatActivitySessions`, `PGSQLQueryStoreRuntime`, `PGSQLQueryStoreWaits`, `PGSQLAutovacuumStats`, `PGSQLDbTransactionsStats`, `PGSQLPgBouncer` | **Yes** |
| Downloading raw `.log` files for offline post-mortem (`auto_explain` plans, error scans) | **Yes** — Server Logs surface |
| Using legacy `AzureDiagnostics` table for PG Flex (because the workspace was set up before resource-specific mode existed) | **Yes** — but the skill's resolution path is to migrate to resource-specific tables; queries should use the `_PGSQL_Get*` helper functions until migration |

---

## THE TWO-LAYER METRIC MODEL

The Azure Monitor Metrics API for PG Flex is **not** a single system. It is two layers stacked behind one URL:

```
                      ┌──────────────────────────────┐
HTTP request  ───────▶│   API plane                  │
                      │   (knows every metric NAME)  │
                      └──────────────┬───────────────┘
                                     │ asks
                      ┌──────────────▼───────────────┐
                      │   Server-side collector      │
                      │   (decides whether to EMIT)  │
                      └──────────────────────────────┘
```

The API plane will happily accept any metric name listed in `metricDefinitions` and will return `errorCode: Success` for it. **It does not check whether the collector behind that metric is actually emitting values.** When the collector is off, you get one of these two shapes:

```json
{
  "name": { "value": "tps" },
  "errorCode": "Success",
  "timeseries": []
}
```

```json
{
  "name": { "value": "longest_query_time_sec" },
  "errorCode": "Success",
  "timeseries": [{
    "data": [
      { "timeStamp": "2026-05-02T13:45:00Z" },
      { "timeStamp": "2026-05-02T13:46:00Z" }
    ]
  }]
}
```

Both are *legal* responses per the [Metrics List 2023-10-01 schema](https://learn.microsoft.com/en-us/rest/api/monitor/metrics/list?view=rest-monitor-2023-10-01) — `MetricValue` makes `average`, `minimum`, `maximum`, `total`, `count` all optional. A bare `{ "timeStamp": "..." }` means "no value emitted for this minute."

### The Enhanced Metrics family (collector-gated)

These metrics are **only populated** when `metrics.collector_database_activity = ON`:

| Metric | Unit | What it answers |
|---|---|---|
| `tps` | Count | Transactions per second across all databases |
| `client_connections_active` | Count | Currently active client connections |
| `client_connections_waiting` | Count | Connections waiting on a lock or resource |
| `server_connections_active` | Count | Backend processes currently active |
| `longest_query_time_sec` | Seconds | The single longest-running query in flight |

If any of these returns empty in your investigation, **stop querying and turn the collector on**. Do not waste cycles re-running with a wider time window — backfill is impossible (see *No backfill* below).

### The non-collector-gated set (always populated)

These are emitted whether or not the collector is enabled — so they are also the metrics you can rely on for retroactive analysis:

```
cpu_percent                          memory_percent
read_iops              write_iops    read_throughput      write_throughput
disk_iops_consumed_percentage        disk_bandwidth_consumed_percentage
disk_queue_depth                     network_bytes_egress
network_bytes_ingress                storage_used         storage_percent
backup_storage_used                  active_connections   (some legacy)
```

### Enabling the collector — the canonical command

```bash
az postgres flexible-server parameter set \
  --subscription "$SUB" \
  --resource-group "$RG" \
  --server-name   "$SERVER" \
  --name  metrics.collector_database_activity \
  --value ON
```

Properties of this parameter (verify against your server with `parameter show`):

```json
{
  "isDynamicConfig": true,
  "default": "off",
  "allowedValues": "on,off"
}
```

Dynamic = no restart, no connection drop. Effective within ~1 minute.

### NO BACKFILL

The single most-misunderstood property of the collector toggle: **enabling it does not retroactively populate historical minutes**. Every `timestamp` before the enable will remain null forever. Plan for this — if an incident is in flight and the collector is off, you have already lost the diagnostic data for the spike that is happening *right now*. Turn it on as a routine *before* incidents, not during them.

---

## THE COMPANION DIAGNOSTIC PARAMETERS

Enable alongside the collector. All three are dynamic — no restart.

| Parameter | Value | What it gives you | Cost |
|---|---|---|---|
| `metrics.collector_database_activity` | `ON` | Enhanced Metrics family populates | Negligible (probe per minute) |
| `pg_qs.query_capture_mode` | `TOP` | Query Store records top-N runtime stats into `azure_sys.query_store_runtime_stats_view` | Few MB/day depending on workload variety |
| `auto_explain.log_min_duration` | `1000` (ms) | EXPLAIN plan logged for every query >1s into the server log | Per-query planner overhead **only on slow queries** — most workloads barely notice |

```bash
az postgres flexible-server parameter set -g "$RG" -s "$SERVER" \
  -n pg_qs.query_capture_mode --value TOP

az postgres flexible-server parameter set -g "$RG" -s "$SERVER" \
  -n auto_explain.log_min_duration --value 1000
```

Without these three, an incident investigation has CPU/memory/disk numbers but **no way to attribute them to specific queries or sessions**. With them, the question "what was running at 13:45?" is answerable from telemetry alone.

### Querying the Query Store after the fact

```sql
SELECT
  query_sql_text,
  total_time,
  mean_time,
  call_count,
  rows
FROM azure_sys.query_store_runtime_stats_view
WHERE start_time > now() - interval '6 hours'
ORDER BY total_time DESC
LIMIT 20;
```

### Reading the auto_explain log

```bash
az postgres flexible-server logs list -g "$RG" -n "$SERVER"
# Or via the Server logs blade in the portal.
```

---

## THE HEADROOM-VS-RAW DIAGNOSTIC DOCTRINE

Every PG Flex server publishes two parallel I/O metric families:

| Family | Metrics | What it tells you |
|---|---|---|
| **Raw** | `read_iops`, `write_iops`, `read_throughput`, `write_throughput` | Absolute IOPS / bytes-per-second |
| **Consumption %** | `disk_iops_consumed_percentage`, `disk_bandwidth_consumed_percentage` | Same workload as **fraction of provisioned SKU ceiling** |

**Default to consumption %.** Raw IOPS without the ceiling is meaningless — 750 IOPS could be 5% of one SKU or 250% of another. Consumption % does the math server-side: 100% = saturated, period.

### The diagnostic triple

For "is storage the bottleneck?" the answer comes from these three metrics:

```
disk_iops_consumed_percentage      → are we hitting the IOPS ceiling?
disk_bandwidth_consumed_percentage → are we hitting the throughput ceiling?
disk_queue_depth                   → is I/O actually queuing (waiting)?
```

### Decision rules

| Reading | Verdict |
|---|---|
| Both `consumed_percentage < 50%` AND `queue_depth ≤ 1` | Storage **not** the bottleneck. Look at CPU, memory, query plans. |
| One `consumed_percentage > 80%` OR `queue_depth` consistently `> 5` | Storage **is** the bottleneck. Scale the SKU or fix query patterns. |
| Both `consumed_percentage < 20%` AND CPU is spiked | Server is **CPU-bound, not I/O-bound**. Storage is over-provisioned for this workload. |

### Reverse-engineering the SKU ceiling

When you have the same minute in raw + consumption %, you can back out the provisioned ceiling:

```
provisioned_iops ≈ raw_iops / (consumed_percentage / 100)
```

Example from a real diagnostic: `750 wIOPS @ 11.67% consumed → ~6,400 provisioned IOPS` ⇒ ~P30 / Premium SSD ~1 TiB tier. Useful when nobody documented which storage tier was selected.

### When raw is the right choice

- **Capacity forecasting over months** — model growth independent of the current SKU
- **Cross-environment workload-shape comparison** when SKUs differ
- **Application-developer dashboards** — raw bytes are more intuitive than %

---

## THE METRICS REST API SURFACE

Three endpoints. Pick the right one.

### 1. `Metrics > List` — single resource, control plane

For ad-hoc per-server reads. This is what `az monitor metrics list` wraps.

```
GET https://management.azure.com/{resourceUri}/providers/Microsoft.Insights/metrics
    ?api-version=2023-10-01
    &timespan={ISO8601_START}/{ISO8601_END}
    &interval=PT1M
    &metricnames=cpu_percent,memory_percent,disk_iops_consumed_percentage
    &aggregation=Average,Maximum
```

OAuth scope: standard ARM (`https://management.azure.com/.default`).

### 2. `Metrics > List At Subscription Scope` — fleet-wide GET (or POST)

For "where in this subscription is CPU > 80%?". Same response shape, no specific resource in the URL.

### 3. `Metrics-Batch > Batch` — multi-resource, **regional data plane**

This is the right endpoint for "metrics across N resources" — including most fleet alerting and capacity-planning queries.

```
POST https://<region>.metrics.monitor.azure.com/subscriptions/{subscriptionId}/metrics:getBatch
     ?api-version=2023-10-01
     &metricnamespace=Microsoft.DBforPostgreSQL/flexibleServers
     &metricnames=cpu_percent,memory_percent
     &starttime=2026-05-02T13:00:00.000Z
     &endtime=2026-05-02T14:00:00.000Z
     &interval=PT1M
     &aggregation=average,maximum

Body:
{
  "resourceids": [
    "/subscriptions/.../flexibleServers/pg-1",
    "/subscriptions/.../flexibleServers/pg-2",
    "/subscriptions/.../flexibleServers/pg-3"
  ]
}
```

| | `Metrics/List` | `Metrics-Batch/Batch` |
|---|---|---|
| **HTTP method** | GET | POST (with JSON body) |
| **Host** | `management.azure.com` (control plane) | `https://<region>.metrics.monitor.azure.com` (regional data plane) |
| **OAuth scope** | `https://management.azure.com/.default` | `https://metrics.monitor.azure.com/.default` |
| **Time params** | `timespan=START/END` | `starttime=` + `endtime=` (separate) |
| **`metricnamespace`** | optional | **required** |
| **Resources targeted** | one (in URL path) | many (in request body, `resourceids[]`) |
| **Region constraint** | none | host region must match resource region (or `global`) |
| **Response shape** | `value[]` of metrics | `values[]` of *resources*, each with `value[]` of metrics |

**Rule:** if you are about to write `for server in $(az postgres flexible-server list ...); do az rest ... ; done` — stop. Use `metrics:getBatch` instead. One regional POST returns the full fleet.

### Hard limits (verbatim from the 2023-10-01 spec)

| Limit | Value |
|---|---|
| `metricnames` per call | **20 metrics** |
| Retention window | **93 days** (server-side enforced; past this returns HTTP 400) |
| Default `interval` | `PT1M` |
| Special `interval=FULL` | Single datapoint over the entire timespan |
| `top` parameter | Effective **only** when `$filter` is also specified |
| `cost` field | Integer relative-cost budget (**not dollars**) — used for internal throttling |

### The `cost` field, demystified

Empirically, for PG Flex with `interval=PT1M` over a ~35-hour window, `cost ≈ 2099 × N_metrics`. Stay under the call's implicit budget by:

- Narrowing the timespan
- Reducing `metricnames` count (≤ 10 is a comfortable default; 20 is the hard cap)
- Increasing `interval` (`PT5M`, `PT15M`, `PT1H`) for wider windows

---

## CLI ERGONOMICS — `az rest` vs `az monitor metrics list`

Both call the same API. The wrapper handles auth scope, regional endpoint discovery, and api-version automatically.

### Default to `az monitor metrics list`

```bash
az monitor metrics list \
  --resource "$RESOURCE_ID" \
  --metrics cpu_percent memory_percent \
            disk_iops_consumed_percentage \
            disk_bandwidth_consumed_percentage \
            disk_queue_depth \
  --interval PT1M \
  --start-time 2026-05-02T13:00:00Z \
  --end-time   2026-05-02T14:00:00Z \
  --aggregation Average Maximum \
  --output json
```

### Drop down to `az rest` only when you need something the wrapper doesn't expose

- `AutoAdjustTimegrain=true` — auto-fall-back to a supported interval if the requested one is invalid for the timespan
- `rollupby=<dim>` — collapse a dimension's breakdown into one timeseries
- `interval=FULL` — single datapoint over the entire timespan
- `ValidateDimensions=false` — tolerate invalid filter dimensions
- The `metrics:getBatch` endpoint (the wrapper does not yet ship this)

```bash
az rest --method GET \
  --url "https://management.azure.com${RESOURCE_ID}/providers/microsoft.insights/metrics" \
  --url-parameters \
    "metricnames=cpu_percent,memory_percent" \
    "interval=PT1M" \
    "timespan=${UTC_START}/${UTC_END}" \
    "AutoAdjustTimegrain=true" \
    "api-version=2023-10-01" \
  --output json
```

---

## DEFENSIVE jq PATTERNS

Mixed-metric responses **will** include some metrics with empty `timeseries`. Direct chaining crashes with `Cannot iterate over null (null)`.

```jq
# ❌ BAD — crashes the moment one metric has empty timeseries
.value[] | .timeseries[0].data[] | .average

# ✅ GOOD — null-coalesce both layers
.value[] | (.timeseries[0].data // []) | .[] | select(.average != null) | .average
```

Use `// []` everywhere `.timeseries[0].data` appears.

### The first-pass diagnostic block

Run this before any analysis on a multi-metric response:

```bash
F=response.json

# Identify which metrics returned empty
jq -r '.value[] |
  "\(.name.value): pts=\([.timeseries[0].data // [] | .[] | select(.average != null)] | length)"' "$F"
```

Output telling you the collector is OFF:

```
cpu_percent: pts=47
memory_percent: pts=47
tps: pts=0                       ← Enhanced Metrics OFF
client_connections_active: pts=0 ← Enhanced Metrics OFF
disk_iops_consumed_percentage: pts=49
```

The fix is one CLI call (the parameter set above), **not more queries**.

### Per-metric stats with null safety

```bash
jq -r '
  .value[] |
  ((.timeseries[0].data // [])) as $d |
  ([$d[] | select(.average != null) | .average]) as $v |
  {
    metric: .name.value,
    unit: .unit,
    pts: ($v | length),
    min: ($v | if length>0 then min else null end),
    avg: ($v | if length>0 then (add/length) else null end),
    max: ($v | if length>0 then max else null end)
  } | @json
' response.json
```

### Wall-clock alignment around an event

```bash
jq -r '
  [ .value[] | {m: .name.value, d: (.timeseries[0].data // [])} ] as $all |
  (range(35;49) | tostring | if length==1 then "0"+. else . end) as $mm |
  ("2026-05-02T13:" + $mm + ":00Z") as $ts |
  "--- \($ts) ---",
  ($all[] |
    ((.d[] | select(.timeStamp == $ts) | .average) // "—") as $v |
    "  \(.m): \($v)"
  )
' response.json
```

---

## STANDARD DIAGNOSTIC RECIPE — "what happened on this server?"

Use this as the first query for any incident:

```bash
RESOURCE_ID="/subscriptions/${SUB}/resourceGroups/${RG}/providers/Microsoft.DBforPostgreSQL/flexibleServers/${SERVER}"

az rest --method GET \
  --url "https://management.azure.com${RESOURCE_ID}/providers/microsoft.insights/metrics" \
  --url-parameters \
    "metricnames=cpu_percent,memory_percent,disk_iops_consumed_percentage,disk_bandwidth_consumed_percentage,disk_queue_depth,tps,client_connections_active,longest_query_time_sec" \
    "interval=PT1M" \
    "timespan=${UTC_START}/${UTC_END}" \
    "api-version=2023-10-01" \
  --output json > /tmp/pg-metrics.json
```

Eight metrics, well under the 20-metric cap. The first five are always populated; the last three depend on the collector being on.

Then:

```bash
# Step 1 — coverage check
jq -r '.value[] | "\(.name.value): pts=\([.timeseries[0].data // [] | .[] | select(.average != null)] | length)"' /tmp/pg-metrics.json

# Step 2 — if any of {tps, client_connections_active, longest_query_time_sec} == 0, enable the collector now
#         and re-run for the *next* incident; this incident's data is gone.

# Step 3 — bottleneck verdict (apply the decision rules above)

# Step 4 — if Query Store is enabled, ask Postgres what ran:
#   psql ... -c "SELECT ... FROM azure_sys.query_store_runtime_stats_view ..."
```

---

## THE TWO LOG SURFACES

PG Flex publishes diagnostic data on **two completely separate surfaces**. Choosing the wrong one wastes hours.

```
                  ┌────────────────────────────────────────────┐
                  │  Surface A — SERVER LOGS (downloadable)    │
                  │  Filesystem .log files exposed via REST    │
                  │  Toggle: logfiles.download_enable = on     │
                  │  Retention cap: 7 days (logfiles.retention_days) │
                  │  Use for: post-mortem on ONE server,       │
                  │           grepping auto_explain plans      │
                  └────────────────────────────────────────────┘

                  ┌────────────────────────────────────────────┐
                  │  Surface B — DIAGNOSTIC SETTINGS (streamed)│
                  │  Categories → Log Analytics / Storage /    │
                  │              Event Hub                      │
                  │  Toggle: az monitor diagnostic-settings    │
                  │  Retention: workspace-controlled (any)     │
                  │  Use for: fleet alerting, KQL analytics,   │
                  │           cross-server correlation         │
                  └────────────────────────────────────────────┘
```

### Surface A — Server Logs

Two server parameters control it:

| Parameter | Default | Range | Purpose |
|---|---|---|---|
| `logfiles.download_enable` | `off` | `on` / `off` | Master toggle for downloadable Server Logs |
| `logfiles.retention_days` | `3` | `1..7` | How long files stay before deletion (server-side caps at 7) |

```bash
az postgres flexible-server parameter set -g "$RG" -s "$SERVER" \
  --name logfiles.download_enable --value on
az postgres flexible-server parameter set -g "$RG" -s "$SERVER" \
  --name logfiles.retention_days  --value 7
```

**Storage gotcha:** files live on the **data disk** for ~1 hour, then move to **backup storage**. Verbose logging on a small SKU can briefly push `storage_percent` close to 100 — watch for it the first day after enabling.

**File naming:** `postgresql_yyyy_mm_dd_hh_00_00.log`, new file every ~10 minutes.

**List:**
```bash
# Default: last 72h
az postgres flexible-server server-logs list -g "$RG" -n "$SERVER"

# Filter: written in last 10h, name contains "01_07", under 30 KiB
az postgres flexible-server server-logs list -g "$RG" -n "$SERVER" \
  --file-last-written 10 \
  --filename-contains 01_07 \
  --max-file-size 30
```

**Download (multi-name):**
```bash
az postgres flexible-server server-logs download -g "$RG" -n "$SERVER" \
  --name postgresql_2026_05_02_13_00_00.log \
         postgresql_2026_05_02_14_00_00.log
```

### Surface B — Diagnostic Settings

**Not enabled automatically.** Enable per-server. Costs apply (Log Analytics ingestion + retention + queries).

```bash
WS=/subscriptions/$SUB/resourceGroups/$RG/providers/Microsoft.OperationalInsights/workspaces/$WORKSPACE
RID=/subscriptions/$SUB/resourceGroups/$RG/providers/Microsoft.DBforPostgreSQL/flexibleServers/$SERVER

az monitor diagnostic-settings create \
  --name pgflex-to-loganalytics \
  --resource "$RID" \
  --workspace "$WS" \
  --export-to-resource-specific true \
  --logs '[
    {"category":"PostgreSQLLogs","enabled":true},
    {"category":"PostgreSQLFlexSessions","enabled":true},
    {"category":"PostgreSQLFlexQueryStoreRuntime","enabled":true},
    {"category":"PostgreSQLFlexQueryStoreWaitStats","enabled":true},
    {"category":"PostgreSQLFlexTableStats","enabled":true},
    {"category":"PostgreSQLFlexDatabaseXacts","enabled":true}
  ]'
```

**`--export-to-resource-specific true` is the single most important flag.** Without it data lands in the legacy `AzureDiagnostics` table with a `Category` column — slower queries, higher cost, no schema typing. With it, each category gets its own typed table.

---

## DIAGNOSTIC CATEGORIES & THEIR DEPENDENCIES

Seven streamable categories. The right-hand column is the trap — categories that need a paired server parameter to actually emit anything.

| Category | Frequency | Resource-specific table | Required server parameter(s) |
|---|---|---|---|
| `PostgreSQLLogs` | 10 sec | `PGSQLServerLogs` | none (always emits if enabled) |
| `PostgreSQLFlexSessions` | 5 min | `PGSQLPgStatActivitySessions` | none |
| `PostgreSQLFlexQueryStoreRuntime` | 5 min* | `PGSQLQueryStoreRuntime` | `pg_qs.query_capture_mode = top` (or `all`) |
| `PostgreSQLFlexQueryStoreWaitStats` | 5 min* | `PGSQLQueryStoreWaits` | `pg_qs.query_capture_mode = top\|all` **AND** `pgms_wait_sampling.query_capture_mode = on` |
| `PostgreSQLFlexTableStats` | 30 min | `PGSQLAutovacuumStats` | none (but `metrics.autovacuum_diagnostics = on` for the matching metrics surface) |
| `PostgreSQLFlexDatabaseXacts` | 30 min | `PGSQLDbTransactionsStats` | none |
| (PgBouncer logs) | 10 sec | `PGSQLPgBouncer` | `pgbouncer.enabled = on` |

\* For Query Store categories, the actual frequency is `min(5 min, pg_qs.interval_length_minutes)`. Default is 5; raise it if you want coarser sampling.

**Misconfiguration shape that bites:** the diagnostic category is enabled in the workspace, the table exists, but every query returns zero rows. Cause: the paired server parameter is off. Cost is unchanged (you're paying the ingestion path's fixed overhead). Fix is one `parameter set` call.

### Cross-mode KQL helper functions

If a workspace has been migrated mid-flight from `AzureDiagnostics` to resource-specific mode (or vice versa), data is split across both tables. Microsoft ships UNION-resolver functions so dashboards don't break:

| Helper function | Resolves |
|---|---|
| `_PGSQL_GetPostgresServerLogs` | `PostgreSQLLogs` from either mode |
| `_PGSQL_GetPgStatActivitySessions` | `PostgreSQLFlexSessions` from either mode |
| `_PGSQL_GetQueryStoreRuntime` | `PostgreSQLFlexQueryStoreRuntime` from either mode |
| `_PGSQL_GetQueryStoreWaits` | `PostgreSQLFlexQueryStoreWaitStats` from either mode |
| `_PGSQL_GetAutovacuumStats` | `PostgreSQLFlexTableStats` from either mode |
| `_PGSQL_GetDbTransactionsStats` | `PostgreSQLFlexDatabaseXacts` from either mode |
| `_PGSQL_GetPgBouncerLogs` | PgBouncer logs from either mode |

**Rule:** in any reusable workbook / saved KQL, prefer the helper function over the table name. Direct table references break for any tenant whose workspace is in the other mode.

---

## CANONICAL KQL DIAGNOSTIC RECIPES

Resource-specific table names below — swap to the `_PGSQL_Get*` helpers if the workspace might be in legacy mode.

### Recent server-side errors

```kql
PGSQLServerLogs
| where TimeGenerated > ago(1h)
| where errorLevel_s in ("ERROR", "FATAL", "PANIC", "WARNING")
| project TimeGenerated, errorLevel_s, Message, processId_d, errorRegex_s
| order by TimeGenerated desc
```

### Top-time queries in the last 6 hours

```kql
PGSQLQueryStoreRuntime
| where TimeGenerated > ago(6h)
| summarize
    total_ms  = sum(total_time_d),
    calls     = sum(calls_d),
    rows      = sum(rows_d),
    avg_ms    = avg(mean_time_d)
  by query_sql_text_s
| top 10 by total_ms
```

### What was the database doing at 13:45?

```kql
PGSQLPgStatActivitySessions
| where TimeGenerated between (datetime(2026-05-02T13:45) .. datetime(2026-05-02T13:48))
| project TimeGenerated, datname_s, usename_s, state_s,
          wait_event_type_s, wait_event_s, query_s
| order by TimeGenerated asc
```

### Wait-event hotspots correlated to queries (last 24h)

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

### Bloat / autovacuum laggards

```kql
PGSQLAutovacuumStats
| where TimeGenerated > ago(2h)
| summarize arg_max(TimeGenerated, *) by datname_s, schemaname_s, relname_s
| where n_dead_tup_d > 100000
| project datname_s, schemaname_s, relname_s,
          n_dead_tup_d, n_live_tup_d,
          last_autovacuum_t, last_autoanalyze_t
| order by n_dead_tup_d desc
```

### Transaction-ID wraparound risk

```kql
PGSQLDbTransactionsStats
| where TimeGenerated > ago(1h)
| summarize arg_max(TimeGenerated, *) by datname_s
| extend pct_to_wraparound =
    100.0 * age_d / 2147483647.0
| project datname_s, age_d, pct_to_wraparound,
          autovacuum_freeze_max_age_d
| order by age_d desc
```

If `pct_to_wraparound > 50%` for any database, autovacuum is falling behind — escalate.

### Cross-server CPU + slowest query at the same minute

```kql
let highCpu =
  AzureMetrics
  | where ResourceId has "/flexibleServers/"
  | where MetricName == "cpu_percent" and Average > 80
  | project ResourceId, TimeGenerated, cpu = Average;
let topQuery =
  PGSQLQueryStoreRuntime
  | summarize arg_max(total_time_d, query_sql_text_s) by ResourceId = _ResourceId, bin(TimeGenerated, 5m);
highCpu
| join kind=leftouter topQuery on ResourceId, $left.TimeGenerated == $right.TimeGenerated
| project TimeGenerated, ResourceId, cpu, query_sql_text_s
```

---

## DIAGNOSTIC SETTINGS — PROVISIONING CHEAT-SHEET

The full "good defaults" enable for a new server, paired with the metrics-side parameters from the cheat-sheet later in this skill:

```bash
SUB=...; RG=...; SERVER=...; WORKSPACE=...

# 1. Server parameters that unlock diagnostic categories
for kv in \
  "metrics.collector_database_activity=on" \
  "metrics.autovacuum_diagnostics=on" \
  "pg_qs.query_capture_mode=top" \
  "pgms_wait_sampling.query_capture_mode=on" \
  "auto_explain.log_min_duration=1000" \
  "log_min_duration_statement=1000" \
  "log_lock_waits=on" \
  "track_io_timing=on"
do
  K="${kv%%=*}"; V="${kv#*=}"
  az postgres flexible-server parameter set \
    --subscription "$SUB" -g "$RG" -s "$SERVER" \
    -n "$K" --value "$V" --only-show-errors
done

# 2. Server Logs feature (post-mortem fallback)
az postgres flexible-server parameter set \
  --subscription "$SUB" -g "$RG" -s "$SERVER" \
  -n logfiles.download_enable --value on
az postgres flexible-server parameter set \
  --subscription "$SUB" -g "$RG" -s "$SERVER" \
  -n logfiles.retention_days --value 7

# 3. Diagnostic Setting → Log Analytics in resource-specific mode
WS=/subscriptions/$SUB/resourceGroups/$RG/providers/Microsoft.OperationalInsights/workspaces/$WORKSPACE
RID=/subscriptions/$SUB/resourceGroups/$RG/providers/Microsoft.DBforPostgreSQL/flexibleServers/$SERVER

az monitor diagnostic-settings create \
  --subscription "$SUB" \
  --name pgflex-to-loganalytics \
  --resource "$RID" \
  --workspace "$WS" \
  --export-to-resource-specific true \
  --logs '[
    {"category":"PostgreSQLLogs","enabled":true},
    {"category":"PostgreSQLFlexSessions","enabled":true},
    {"category":"PostgreSQLFlexQueryStoreRuntime","enabled":true},
    {"category":"PostgreSQLFlexQueryStoreWaitStats","enabled":true},
    {"category":"PostgreSQLFlexTableStats","enabled":true},
    {"category":"PostgreSQLFlexDatabaseXacts","enabled":true}
  ]'
```

Output of step 3 should show `logAnalyticsDestinationType: AzureDiagnostics` if you forgot the `--export-to-resource-specific true` flag — that's the failure mode to grep for in CI / drift detection.

---

## ANTI-PATTERNS

| Anti-pattern | Why it bites | Do this instead |
|---|---|---|
| Concluding "TPS was 0 during the spike" from a metrics query | The collector might be off; you cannot tell from the API response alone | Coverage-check empty metrics; if collector-gated, enable and re-run *next time* |
| Using `api-version=2018-01-01` in new code | Lacks `rollupby`; past expected migration window | Use `api-version=2023-10-01` |
| Looping `az rest` per server for fleet metrics | N HTTP calls, N auth roundtrips, slow | One `metrics:getBatch` POST to the regional endpoint |
| Querying the last 6 months of metrics | Server-side 93-day cap returns HTTP 400 | Stay within 93 days; use Diagnostic Settings → Log Analytics for older data |
| Reasoning about IOPS without the SKU ceiling | "750 IOPS" is meaningless without "of how many?" | `disk_iops_consumed_percentage` directly; `disk_queue_depth` for queuing |
| `jq '.value[] \| .timeseries[0].data[]'` without `// []` | Crashes the first time a metric returns empty timeseries | `(.timeseries[0].data // [])` everywhere |
| Enabling `auto_explain.log_min_duration = 0` "to capture everything" | Logs every query, planner overhead on every call, log volume explodes | Use `1000` (ms) — captures slow queries, ignores the chatty fast ones |
| Treating the `cost` field as billing dollars | It is an internal throttling budget integer | Interpret as relative cost; size queries to fit |
| Enabling collectors only when an incident starts | No backfill — you've lost the spike's data forever | Enable as a routine on every server during provisioning |
| Reading `errorCode: Success` as proof of data presence | Means the metric *name* is valid, not that data is being collected | Always check populated-point counts |
| Configuring Diagnostic Settings without `--export-to-resource-specific true` | Data lands in `AzureDiagnostics` — slower KQL, higher cost, no schema typing | Always set `--export-to-resource-specific true`; CI-grep for diagnostic settings missing this |
| Enabling `PostgreSQLFlexQueryStoreRuntime` without `pg_qs.query_capture_mode = top` | Table exists, queries return nothing, you pay the ingestion path's overhead anyway | Pair every Query Store category with its server parameter at the same time |
| Treating Server Logs (`logfiles.download_enable`) as the fleet-observability surface | 7-day cap, opt-in, per-server file downloads, no KQL | Use Server Logs only for one-server post-mortems; route everything else through Diagnostic Settings → Log Analytics |
| Direct `PGSQLServerLogs` references in shared workbooks | Breaks for tenants whose workspace is in legacy `AzureDiagnostics` mode | Use `_PGSQL_GetPostgresServerLogs()` helper functions in any reusable KQL |
| Enabling Server Logs verbose logging on a Burstable / small-storage SKU without watching `storage_percent` | Files briefly land on the data disk before moving to backup storage; verbose `auto_explain` output can spike `storage_percent` close to 100 | Enable, then watch `storage_percent` for the first day; if it rises, narrow `log_min_duration_statement` / `auto_explain.log_min_duration` |
| Linking to docs under `/azure/postgresql/flexible-server/concepts-server-logs` | The page was reorganized — that path 404s | Pin to `/azure/postgresql/monitor/concepts-monitoring` and `/azure/postgresql/monitor/how-to-configure-server-logs` |

---

## VERIFICATION CHECKLIST — before declaring an investigation complete

- [ ] `metrics.collector_database_activity` is `ON` on the target server (`az postgres flexible-server parameter show -n metrics.collector_database_activity ...`)
- [ ] `pg_qs.query_capture_mode = TOP` is set
- [ ] `auto_explain.log_min_duration ≥ 1` (not the default `-1`)
- [ ] All metrics queried against `api-version=2023-10-01`
- [ ] Coverage check has been run: every queried metric has populated points OR the empty ones are all collector-gated and the collector was provably off during the window
- [ ] Storage verdict is based on `disk_*_consumed_percentage` + `disk_queue_depth`, not raw IOPS
- [ ] Time window is within the 93-day retention bound
- [ ] If multi-server: the query used `metrics:getBatch`, not a loop
- [ ] If a CPU/memory spike was observed: Query Store has been queried for the matching window to attribute the spike to specific SQL
- [ ] All jq pipelines used in the investigation have `(.timeseries[0].data // [])` null-safety
- [ ] Server has a Diagnostic Setting routed to a Log Analytics workspace **in resource-specific mode** (`az monitor diagnostic-settings show ... | jq '.logAnalyticsDestinationType'` is **not** `AzureDiagnostics`)
- [ ] Every enabled Query-Store-derived diagnostic category (`PostgreSQLFlexQueryStoreRuntime`, `PostgreSQLFlexQueryStoreWaitStats`) has its paired server parameter set (`pg_qs.query_capture_mode = top|all`, plus `pgms_wait_sampling.query_capture_mode = on` for waits)
- [ ] If a CPU / memory / I/O spike was investigated and the diagnostic categories are enabled, KQL has been run against `PGSQLQueryStoreRuntime` / `PGSQLQueryStoreWaits` / `PGSQLPgStatActivitySessions` for the matching window
- [ ] If raw `auto_explain` plans are needed, Server Logs is enabled (`logfiles.download_enable = on`) and the relevant `.log` file has been listed/downloaded
- [ ] Reusable KQL artifacts (workbooks, saved searches) reference `_PGSQL_Get*` helper functions, not raw resource-specific table names

---

## CHEAT SHEET — provisioning a new PG Flex server

Run these *during creation*, before any workload lands:

```bash
RG=...; SERVER=...; SUB=...

for kv in \
  "metrics.collector_database_activity=ON" \
  "pg_qs.query_capture_mode=TOP" \
  "auto_explain.log_min_duration=1000" \
  "log_min_duration_statement=1000" \
  "log_lock_waits=on" \
  "track_io_timing=on"
do
  K="${kv%%=*}"; V="${kv#*=}"
  az postgres flexible-server parameter set \
    --subscription "$SUB" -g "$RG" -s "$SERVER" \
    -n "$K" --value "$V" --only-show-errors
done
```

The last three (`log_min_duration_statement`, `log_lock_waits`, `track_io_timing`) are non-collector but high-value Postgres-native logging toggles that pair naturally with the auto_explain stack.

---

## REFERENCES (canonical, pin in any runbook)

- [Metrics List, api-version 2023-10-01](https://learn.microsoft.com/en-us/rest/api/monitor/metrics/list?view=rest-monitor-2023-10-01)
- [Metrics-Batch Batch, api-version 2023-10-01](https://learn.microsoft.com/en-us/rest/api/monitor/metrics-batch/batch?view=rest-monitor-2023-10-01)
- [Azure Monitor REST API index](https://learn.microsoft.com/en-us/azure/azure-monitor/fundamentals/azure-monitor-rest-api-index)
- [Supported metrics — Microsoft.DBforPostgreSQL/flexibleServers](https://learn.microsoft.com/en-us/azure/azure-monitor/reference/supported-metrics/microsoft-dbforpostgresql-flexibleservers-metrics)
- [PG Flex server parameters reference](https://learn.microsoft.com/en-us/azure/postgresql/flexible-server/concepts-server-parameters)
- [Query Store overview](https://learn.microsoft.com/en-us/azure/postgresql/flexible-server/concepts-query-store)
- [Monitoring & metrics on PG Flex (canonical post-reorg URL)](https://learn.microsoft.com/en-us/azure/postgresql/monitor/concepts-monitoring)
- [Configure server logs (download .log files)](https://learn.microsoft.com/en-us/azure/postgresql/monitor/how-to-configure-server-logs)
- [`az monitor diagnostic-settings`](https://learn.microsoft.com/en-us/cli/azure/monitor/diagnostic-settings)
- [`az postgres flexible-server server-logs`](https://learn.microsoft.com/en-us/cli/azure/postgres/flexible-server/server-logs)
