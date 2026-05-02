---
name: azure-pg-flex-empty-metrics-expertise
description: Azure Monitor returns errorCode=Success but empty timeseries for Postgres Flex "Enhanced Metrics" when metrics.collector_database_activity is OFF — silent lie, not an error
triggers:
  - azure metrics empty
  - errorCode Success but no data
  - tps metric empty
  - longest_query_time_sec empty
  - client_connections_active empty
  - server_connections_active empty
  - postgres flexible server metrics
  - az rest microsoft.insights metrics
  - timeseries empty array
  - metrics.collector_database_activity
  - pg_qs.query_capture_mode
---

# Azure Postgres Flex: Empty Metrics with errorCode=Success

## The Insight

Azure Monitor's Metrics API for `Microsoft.DBforPostgreSQL/flexibleServers` is a **two-layer system**: the API plane (which always knows about every published metric name) and the **server-side collector** (which only emits values when its corresponding server parameter is enabled).

When the collector is **disabled**, the API still returns the metric in the response with `errorCode: "Success"` — but with **empty `timeseries: []` arrays** or with data points where every `average` is `null`. This is intentional API behavior, not a bug, but it looks like a successful query that returned "no activity," when in reality **the metric was never being emitted**.

**The principle:** for Azure Monitor on Postgres Flex, `errorCode: Success` means "the metric name is valid," not "data was being collected." Always cross-check `timeseries[0].data | map(select(.average != null)) | length` before concluding "the server was idle."

## Why This Matters

You'll burn time investigating phantom workload patterns:
- "Why was TPS zero during the spike?" — because `tps` was never being collected, not because TPS was zero
- "Why are there no active connections?" — same reason
- You may make capacity decisions based on metrics that don't exist

Worse: the Azure Portal *Metrics blade* and the Diagnostic Settings export to Log Analytics have the **same blind spot** — disabled-collector metrics show flat lines, not "metric unavailable" warnings.

## Recognition Pattern

When parsing Azure Monitor responses, you'll see this shape:

```json
{
  "name": { "value": "tps" },
  "errorCode": "Success",          ← LIES
  "timeseries": []                  ← real signal
}
```

Or, more deceptively:

```json
{
  "name": { "value": "longest_query_time_sec" },
  "errorCode": "Success",
  "timeseries": [{
    "data": [
      { "timeStamp": "2026-05-02T13:45:00Z" },   ← no `average` key
      { "timeStamp": "2026-05-02T13:46:00Z" }    ← all-null
    ]
  }]
}
```

Symptoms in practice:
- Some metrics in a multi-metric query have data, others don't
- The "missing" metrics are always from this family: `tps`, `client_connections_active`, `client_connections_waiting`, `server_connections_active`, `longest_query_time_sec` (the **Enhanced Metrics** family)
- Storage and resource metrics (`cpu_percent`, `memory_percent`, `*_iops`, `*_throughput`, `disk_*_consumed_percentage`, `disk_queue_depth`) work fine
- jq pipelines crash with `Cannot iterate over null (null)` when accessing `.timeseries[0].data` — because for empty-collector metrics, `.timeseries` is `[]`, so `[0]` is `null`

## The Approach

**Diagnostic step before any analysis** — when an Azure Monitor query returns mixed populated/empty metrics, first check if the empty ones belong to the Enhanced Metrics family:

```bash
jq -r '.value[] | "\(.name.value): timeseries_count=\(.timeseries | length)"' response.json
```

**Empty Enhanced Metrics → enable the collector**, don't keep querying:

```bash
az postgres flexible-server parameter set \
  -g <rg> -s <server> \
  -n metrics.collector_database_activity --value ON
```

This is **dynamic** (`isDynamicConfig: true`) — no restart, no connection drop. Takes effect within ~1 minute.

**Critical caveat:** there is **no backfill**. Historical minutes from before the enable will remain `null` forever. Don't re-query a wide historical window expecting it to fill in.

**Companion parameters worth enabling at the same time** (also dynamic):
- `pg_qs.query_capture_mode = TOP` — populates `azure_sys.query_store_runtime_stats_view`
- `auto_explain.log_min_duration = 1000` — logs EXPLAIN plans for queries >1s

These three together unlock the diagnostic surface needed to investigate "what was running at 13:45." Without them, you have CPU/memory/disk numbers but no way to attribute them to specific queries or sessions.

## Defensive jq Pattern

Because `timeseries: []` makes `.timeseries[0]` evaluate to `null`, **never** chain `.timeseries[0].data[]` directly in scripts that handle multi-metric responses:

```jq
# BAD — crashes on empty-collector metrics
.value[] | .timeseries[0].data[] | .average

# GOOD — null-coalesces empty arrays to []
.value[] | (.timeseries[0].data // []) | .[] | .average
```

Use `// []` everywhere `.timeseries[0].data` appears.

## Example: The Detection Block

```bash
F=response.json

# Identify which metrics returned empty
jq -r '.value[] | "\(.name.value): pts=\([.timeseries[0].data // [] | .[] | select(.average != null)] | length)"' "$F"

# If any of these show pts=0, the collector is OFF:
#   tps, client_connections_active, client_connections_waiting,
#   server_connections_active, longest_query_time_sec
```

Output telling you the collector is OFF:

```
cpu_percent: pts=47
memory_percent: pts=47
tps: pts=0                       ← Enhanced Metrics OFF
client_connections_active: pts=0 ← Enhanced Metrics OFF
disk_iops_consumed_percentage: pts=49
```

The fix is one CLI call, not more queries.
