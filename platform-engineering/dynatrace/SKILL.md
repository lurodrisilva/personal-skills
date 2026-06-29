---
name: dynatrace
description: >-
  MUST USE when working with **Dynatrace** programmatically — calling the
  Dynatrace API, authenticating (API tokens / OAuth clients / platform tokens),
  writing **DQL** (Dynatrace Query Language) queries on **Grail**, ingesting
  **OpenTelemetry** (OTLP) traces / metrics / logs, configuring the **AWS** cloud
  connector, or managing Dynatrace configuration as code (Terraform provider /
  Monaco). Covers the two-plane model that trips everyone up: the **Classic**
  plane (`{env}.live.dynatrace.com`, `/api/v1` `/api/v2` `/api/config/v1`,
  `Api-Token dt0c01…` header) versus the **Platform / Grail** plane
  (`{env}.apps.dynatrace.com`, `/platform/…`, `Bearer` platform-token `dt0s16…`
  or OAuth-client `dt0s02…`) — and which auth each endpoint needs. Use for —
  minting and scoping API tokens (`metrics.ingest` / `logs.ingest` /
  `openTelemetryTrace.ingest` / `settings.read|write` / `entities.read`),
  Settings 2.0 objects (`/api/v2/settings/objects`, schemaId + scope + value),
  Environment API v2 (metrics / entities / problems / events / logs / tokens) with
  `nextPageKey` pagination, DQL pipelines (`fetch | filter | summarize | sort`,
  `timeseries`, `makeTimeseries`, `parse` + DPL) and the Grail
  `query:execute` / `query:poll` API, OTLP ingest (`/api/v2/otlp/v1/{traces,metrics,logs}`,
  HTTP/protobuf only, delta temporality), the Dynatrace OpenTelemetry Collector
  distribution, the agentless role-based **AWS** connector (`da-aws` extension,
  cross-account IAM role + ExternalId), and monitoring-as-code with the
  `dynatrace-oss/dynatrace` Terraform provider or Monaco. Triggers on phrases —
  "dynatrace api", "dynatrace token", "Api-Token", "platform token", "DQL",
  "dynatrace query language", "grail", "fetch logs", "timeseries", "dynatrace
  otlp", "send opentelemetry to dynatrace", "dynatrace collector", "dynatrace aws
  connection", "da-aws", "settings 2.0", "monaco", "dynatrace terraform",
  "nextPageKey". Triggers on file patterns — `**/monaco/**`, `**/*.monaco.yaml`,
  YAML/JSON with `com.dynatrace.extension.da-aws` / `Api-Token dt0c01` /
  `apps.dynatrace.com/platform`, OTel collector configs exporting to
  `*.live.dynatrace.com/api/v2/otlp`, Terraform using the `dynatrace` provider.
  For the Azure Kusto/KQL telemetry-query API see the sibling `kusto-kql-api`
  skill (different vendor; DQL ≠ KQL). Authored by a distinguished Observability
  Platform Engineer — emphasizes right-plane-right-auth, least-scope tokens,
  Grail/DQL over legacy polling, delta-temporality OTLP, and monitoring-as-code
  over click-ops.
license: BSD-3-Clause
compatibility: opencode
metadata:
  domain: platform-engineering
  pattern: observability-platform
  platform: dynatrace
  stack: dynatrace-api + dql-grail + opentelemetry + aws-connector + config-as-code
  surfaces: api-auth, dql, otlp-ingest, cloud-integration, monitoring-as-code
  use_cases: telemetry-query, telemetry-ingest, observability-automation
---

# Dynatrace

You are an Observability Platform Engineer working with **Dynatrace**
programmatically — querying it (DQL/Grail), feeding it (OpenTelemetry, the AWS
connector), automating it (API, Settings 2.0, config-as-code). Dynatrace exposes
a large API surface across **two coexisting planes**; getting the plane and the
credential right is most of the battle.

> **Scope boundary.** Sibling query-API skill `kusto-kql-api` covers Azure
> Kusto/KQL — a different vendor and a different language (DQL ≠ KQL). Don't
> conflate them.

---

## CORE PRINCIPLES (NON-NEGOTIABLE)

> Violating any of these is an automatic review failure.

### 1. Right plane → right credential
Dynatrace runs **two API planes**. An endpoint on the wrong plane, or with the
wrong token type, returns 401/403 no matter how correct the rest of the request
is. Internalize the PLANE & AUTH MAP below before writing any call.

### 2. The same telemetry is INGESTED and QUERIED on different planes
You **send** OpenTelemetry to the **Classic** plane
(`{env}.live.dynatrace.com/api/v2/otlp`, `Api-Token dt0c01…`) but **read it back**
with DQL on the **Platform/Grail** plane
(`{env}.apps.dynatrace.com/platform/storage/query…`, `Bearer` token). One
credential will **not** do both. This split is invisible if you think per-task —
keep it front of mind.

### 3. Least-scope tokens, one per purpose
Never a single god-token. Separate **ingest** (`*.ingest`), **read**
(`*.read` / `storage:*:read`), and **config** (`settings.write`) tokens, scoped
per environment. Pass via the `Authorization` header, **never** the
`?api-token=` query param (URLs get logged). Never commit a token to Git.

### 4. Prefer Grail/DQL and Settings 2.0 over the legacy surfaces
For new work: query with **DQL on Grail**, not the classic Metrics/log-search
polling; configure with **Settings 2.0** (`/api/v2/settings/objects`), not the
deprecated `/api/config/v1` Configuration API.

### 5. OTLP: HTTP/protobuf + DELTA temporality only
Dynatrace OTLP ingest accepts **OTLP/HTTP with binary protobuf only** — **no
gRPC, no JSON**. Metric streams must be **delta** temporality; cumulative is
rejected. (Terminate gRPC / convert cumulative at a Collector.)

### 6. AWS: agentless, role-based, Grail-native
Use the modern **`da-aws`** connector: a cross-account **IAM role** trusted via
an **ExternalId** (no static keys, no ActiveGate polling). The legacy
ActiveGate/key-based "AWS monitoring" is **deprecated (2026-03-31)** — migrate.

### 7. Monitoring-as-code, never click-ops production
Dashboards, SLOs, alerting, and Settings 2.0 objects belong in Git via the
**Terraform provider** or **Monaco**, applied per environment with scoped tokens.

### 8. Cardinality discipline
Never put unbounded values (request id, full URL, user id, pod UUID, timestamp)
into metric dimensions — you'll exhaust the tuple limit and Dynatrace drops new
series.

---

## PLANE & AUTH MAP (READ THIS FIRST)

The single most important reference in this skill:

| Plane | Host (SaaS) | Path roots | Credential | Header |
|---|---|---|---|---|
| **Classic (Gen2)** | `{env-id}.live.dynatrace.com` | `/api/v1`, `/api/v2`, `/api/config/v1` | **API token** (`dt0c01.…`, scope-gated) | `Authorization: Api-Token dt0c01.…` |
| **Platform / Grail (Gen3)** | `{env-id}.apps.dynatrace.com` | `/platform/…` (incl. DQL, Settings, Extensions v2, Automation) | **Platform token** (`dt0s16.…`) or **OAuth client** (`dt0s02.…`) | `Authorization: Bearer …` |
| **Account management** | `api.dynatrace.com/iam/v1` | `/accounts/{accountUuid}/…` | **OAuth client** (client_credentials) | `Authorization: Bearer …` |

- **Managed** (on-prem) is **classic-only**, env-prefixed:
  `https://{your-domain}/e/{env-id}/api/v2/…` with an API token. No `.apps`/Grail.
- **Rule of thumb:**
  - `*.live.dynatrace.com/api/{v1,v2,config/v1}` → **API token** (`Api-Token`).
  - `*.apps.dynatrace.com/platform/…` (DQL, Settings, Extensions v2) → **Bearer** platform token / OAuth client.
  - `api.dynatrace.com/iam/v1` (users/groups/accounts) → **OAuth client** Bearer.
- A **platform token works only on the platform plane** — it will *not*
  authenticate a classic `/api/v2` call, and vice-versa.

### The three credentials (how they differ)

| Credential | Prefix | Grant / creation | Used for |
|---|---|---|---|
| **API token** | `dt0c01.` | Access Tokens UI, or `POST /api/v2/tokens` (needs `apiTokens.write`); 3-part `prefix.public.secret` | Classic plane: ingest, read, Settings 2.0, OTLP |
| **Platform token** | `dt0s16.` | Account/access management; name + expiry + scopes + target env; ≤10/user | Platform plane: DQL/Grail, app-engine, automation, document |
| **OAuth client** | `dt0s02.` | Account Mgmt → IAM → OAuth clients; `client_credentials` @ `https://sso.dynatrace.com/sso/oauth2/token` | Account Management API + platform plane + Apps |

> **Token prefix is `dt0c01`** for the user API token — not `dt0s01` (a different,
> internal token class). Get this right or every Classic call fails.

### Scopes you reach for (exact names)
- **Ingest:** `metrics.ingest`, `logs.ingest`, `openTelemetryTrace.ingest`, `events.ingest`, `bizevents.ingest`.
- **Read (classic):** `metrics.read`, `entities.read`, `problems.read`, `events.read`, `settings.read`.
- **Config:** `settings.write`, `apiTokens.read|write`, `extensions.read|write`.
- **Grail/DQL (platform, on the token/OAuth client):** `storage:logs:read`, `storage:events:read`, `storage:bizevents:read`, `storage:metrics:read`, `storage:spans:read`, `storage:entities:read`, `storage:buckets:read`.

---

## PHASE A — API CLIENT (Classic plane, `Api-Token`)

### A.1 Mint a token (least scope)

```bash
curl -X POST "https://${ENV}.live.dynatrace.com/api/v2/tokens" \
  -H "Authorization: Api-Token ${ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"name":"otel-ingest","scopes":["openTelemetryTrace.ingest","metrics.ingest","logs.ingest"]}'
# needs apiTokens.write. Response carries the secret ONCE — capture it.
```

### A.2 Environment API v2 — the endpoints you actually use

| Area | Endpoint | Scope |
|---|---|---|
| Metrics query | `GET /api/v2/metrics/query?metricSelector=…&from=…` | `metrics.read` |
| Metrics ingest | `POST /api/v2/metrics/ingest` (MINT line protocol) | `metrics.ingest` |
| Entities | `GET /api/v2/entities?entitySelector=type("HOST")` | `entities.read` |
| Problems | `GET /api/v2/problems` · `/{id}` | `problems.read` |
| Events ingest | `POST /api/v2/events/ingest` | `events.ingest` |
| Logs ingest | `POST /api/v2/logs/ingest` | `logs.ingest` |
| Tokens | `GET|POST /api/v2/tokens` | `apiTokens.read|write` |

### A.3 Settings 2.0 — the Config-API replacement

Every settings object is a **`schemaId` + `scope` + `value`** triple:

```bash
curl -X POST "https://${ENV}.live.dynatrace.com/api/v2/settings/objects" \
  -H "Authorization: Api-Token ${TOKEN}" -H "Content-Type: application/json" \
  -d '[{
    "schemaId": "builtin:logmonitoring.log-storage-settings",
    "scope": "environment",
    "value": { "enabled": true, "...": "schema-specific payload" }
  }]'
```

- `GET /api/v2/settings/schemas` lists schemas; `…/schemas/{schemaId}` returns the
  JSON schema the `value` must validate against.
- `scope` = `environment` / `tenant` / an entity id (`HOST-XXXX`) / management zone.
- Update/delete by `objectId` (returned on create); updates may need an
  `updateToken` for optimistic locking. This supersedes most of `/api/config/v1`.

### A.4 Pagination — the `nextPageKey` cursor (easy to get wrong)

Collection endpoints return `nextPageKey`, `totalCount`, `pageSize`. To page,
resend with **only** `nextPageKey` — **all other filters are baked into the key**;
re-sending them alongside errors. No `nextPageKey` in the response = last page.

```bash
curl "https://${ENV}.live.dynatrace.com/api/v2/entities?nextPageKey=AQAAABQBAAAABQ%3D%3D" \
  -H "Authorization: Api-Token ${TOKEN}"   # NOTHING else in the query string
```

### A.5 Rate limits
Throttling is **per-environment** (a bounded request queue), not per-token. Over
capacity → **HTTP 429** after up to ~10s queued; honor **`Retry-After`**. Payload
caps: default 1 MB; log ingest 10 MB; OTLP traces 8 MB / metrics 4 MB / logs 2 MB.

---

## PHASE B — DQL / GRAIL (Platform plane, `Bearer`)

DQL is a **piped, read-only** language: a leading data-loading command, then
`|`-chained transforms, left-to-right.

### B.1 Pipeline + core commands

```dql
fetch logs                                   // leading: load records
| filter loglevel == "ERROR"                 // keep matching
| filterOut matchesPhrase(content, "health") // drop matching
| fieldsAdd svc = dt.entity.service          // add/compute a field (keeps others)
| summarize errors = count(), by: {svc}      // group + aggregate (by: in {braces})
| sort errors desc                           // order (sort == sortBy)
| limit 10                                    // top-N
```

Other commands: `fields` (keep only listed), `fieldsRemove`/`fieldsKeep`/`fieldsRename`,
`dedup`, `search "text"` (free-text), `parse` (DPL extraction), `expand` (unnest array),
`lookup`/`join` (enrich from a subquery), `append` (concatenate a subquery's records).

### B.2 Metrics: `timeseries` (leading) vs `makeTimeseries`

```dql
// metrics → charting-ready series (timeseries is its own loader; do NOT follow fetch)
timeseries p90 = percentile(dt.service.request.response_time, 90),
           by: {dt.entity.service}, interval: 5m, from: -24h

// non-metric records (logs/events) → series by time-bucketing
fetch logs | filter loglevel == "ERROR"
| makeTimeseries count(), interval: 5m, by: {dt.entity.service}
```

`timeseries` modifiers: `interval:`/`bins:` (mutually exclusive), `filter:`,
`by:`, `from:`/`to:`/`shift:`, per-agg `default:`/`rollup:`/`rate:`. Don't pipe
`timeseries` into `makeTimeseries`.

### B.3 Functions you reach for
- **Aggregations** (in `summarize`/`makeTimeseries`/`timeseries`): `count`, `countDistinct`, `sum`, `avg`, `min`, `max`, `median`, `percentile(f,n)`, `takeFirst`, `collectArray`.
- **String/match:** `matchesPhrase(field,"text")` (idiomatic log search), `matchesValue`, `concat`, `splitString`, `lower`/`upper`, `contains`.
- **Conditional/null:** `if(cond, then, else:)`, `coalesce(a,b)`, `in(f,"a","b")`, `isNotNull`.
- **Type/time:** `toString`/`toLong`/`toDouble`/`toTimestamp`, `now()`, duration literals (`1h`,`7d`,`5m`).
- **`parse … , "&lt;DPL pattern&gt;"`** — extract fields: matchers `IPV4`, `INT`, `LONG`, `DOUBLE`, `TIMESTAMP`, `HTTPDATE`, `DQS`, `LD` (lazy any), bound as `MATCHER:field`, literals in single quotes.

### B.4 Timeframe
Most queries inherit the timeframe from the **execution context** (Notebook/
Dashboard selector, or the API request's `defaultTimeframeStart`/`End`) — usually
**not** inline. Override per-source with `from:`/`to:` (e.g. `fetch logs, from: -2h`).

### B.5 Run DQL via the Grail Query API (async execute/poll)

```bash
# 1) start the query (platform plane, Bearer)
curl -X POST "https://${ENV}.apps.dynatrace.com/platform/storage/query/v1/query:execute" \
  -H "Authorization: Bearer ${PLATFORM_TOKEN}" -H "Content-Type: application/json" \
  -d '{"query":"fetch logs | filter loglevel == \"ERROR\" | limit 100",
       "requestTimeoutMilliseconds":10000,
       "defaultTimeframeStart":"2026-06-29T00:00:00Z",
       "defaultTimeframeEnd":"2026-06-29T01:00:00Z"}'
# response: {state: SUCCEEDED|RUNNING, requestToken, result?}

# 2) if RUNNING, poll until SUCCEEDED
curl "https://${ENV}.apps.dynatrace.com/platform/storage/query/v1/query:poll?request-token=${TOKEN}" \
  -H "Authorization: Bearer ${PLATFORM_TOKEN}"
```

Needs a **platform token or OAuth client** + the relevant `storage:*:read` scopes.
The official `@dynatrace-sdk/client-query` SDK wraps the execute/poll loop.

> **`dt.entity.*` vs `dt.smartscape.*`:** lead with **`dt.entity.host` /
> `dt.entity.service`** (current docs + most examples). In newer Gen3/Smartscape
> contexts Dynatrace is moving toward `dt.smartscape.*` — flag it and verify which
> generation your environment uses before standardizing. Exact `query:execute`
> body field names should be confirmed against your env's `/platform/swagger-ui`.

---

## PHASE C — OPENTELEMETRY INGEST (Classic plane, `Api-Token`)

> **Remember Principle 2:** you ingest here on `.live` with an `Api-Token`, but
> you query the result with DQL on `.apps` with a `Bearer` token.

### C.1 OTLP endpoint + scopes

Base: `https://{env-id}.live.dynatrace.com/api/v2/otlp`, with the standard OTel
signal paths appended:

| Signal | Full URL | Token scope |
|---|---|---|
| Traces | `…/api/v2/otlp/v1/traces` | `openTelemetryTrace.ingest` |
| Metrics | `…/api/v2/otlp/v1/metrics` | `metrics.ingest` |
| Logs | `…/api/v2/otlp/v1/logs` | `logs.ingest` |

**OTLP/HTTP with binary protobuf only — no gRPC, no JSON.** (Strip a trailing
`.apps` if you copied the env id from the browser bar.)

### C.2 SDK exporter config

```bash
export OTEL_EXPORTER_OTLP_ENDPOINT="https://${ENV}.live.dynatrace.com/api/v2/otlp"
export OTEL_EXPORTER_OTLP_HEADERS="Authorization=Api-Token dt0c01.XXXX..."
export OTEL_EXPORTER_OTLP_PROTOCOL="http/protobuf"
# Dynatrace REQUIRES delta temporality for metrics:
export OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE="delta"
```

Cumulative monotonic sums are rejected (HTTP 400). Explicit-bucket histograms are
supported on **Dynatrace ≥ 1.300** (version-gated); exponential/cumulative
histograms are not ingested.

### C.3 Dynatrace OpenTelemetry Collector distribution

`github.com/Dynatrace/dynatrace-otel-collector` — a Dynatrace-verified **subset**
of `otelcol-contrib` with a Dynatrace **`resourcedetection`** detector (adds
`dt.entity.host` / Smartscape attributes). Use it to centralize batching, tail
sampling, `cumulativetodelta` conversion, k8s enrichment, and to **terminate gRPC**
(the collector may receive gRPC, then export OTLP/HTTP to Dynatrace).

```yaml
receivers:
  otlp:
    protocols: { grpc: { endpoint: 0.0.0.0:4317 }, http: { endpoint: 0.0.0.0:4318 } }
processors:
  memory_limiter: { check_interval: 1s, limit_percentage: 80, spike_limit_percentage: 25 }
  cumulativetodelta: {}                 # cumulative → delta for Dynatrace metrics
  resourcedetection/dynatrace: { detectors: [dynatrace], override: false }
  k8sattributes: {}
  batch: { send_batch_max_size: 1000, timeout: 30s }
exporters:
  otlphttp/dynatrace:                   # canonical id is `otlphttp`
    endpoint: "${env:DT_ENDPOINT}"      # https://{env}.live.dynatrace.com/api/v2/otlp
    headers: { Authorization: "Api-Token ${env:DT_API_TOKEN}" }
service:
  pipelines:
    traces:  { receivers: [otlp], processors: [memory_limiter, resourcedetection/dynatrace, k8sattributes, batch], exporters: [otlphttp/dynatrace] }
    metrics: { receivers: [otlp], processors: [memory_limiter, cumulativetodelta, resourcedetection/dynatrace, k8sattributes, batch], exporters: [otlphttp/dynatrace] }
    logs:    { receivers: [otlp], processors: [memory_limiter, resourcedetection/dynatrace, k8sattributes, batch], exporters: [otlphttp/dynatrace] }
```

The Collector appends `/v1/{signal}` automatically when `endpoint` is the base
`/api/v2/otlp`. Pin to a specific `dynatrace-otel-collector` release (the bundled
component set drifts across versions).

### C.4 Enrichment — OneAgent + OTel coexist
OneAgent gives auto-instrumentation + Smartscape topology; OTel gives portable
custom signals — they coexist, with Dynatrace stamping `dt.*` entity attributes so
OTel data maps to the right entities. Align resource attributes to **OTel semantic
conventions** (`service.name` required; `k8s.*` via the `k8sattributes` processor /
Dynatrace Operator annotations; `host.name`) for automatic entity correlation.

---

## PHASE D — AWS CLOUD CONNECTOR (Platform plane)

The modern integration is **agentless, role-based, and Grail-native** (the
`com.dynatrace.extension.da-aws` Extensions 2.0 framework) — it does **not** use an
ActiveGate to poll CloudWatch, and it needs **no static AWS keys**. The legacy
ActiveGate/key "AWS monitoring" is **deprecated (2026-03-31)** — migrate to the
enhanced connection schema.

### D.1 The flow (role-based, ExternalId)

1. **Create the AWS connection object** in Dynatrace (Settings → Connections →
   AWS, or its dedicated API/UI wizard) **without** a Role ARN yet → Dynatrace
   assigns it an **`objectId`**.
   > Author the connection object via the Dynatrace **"Create an AWS connection"**
   > UI/API page for your tenant — do not hand-craft the connection Settings-2.0
   > schema from memory; its exact `schemaId`/shape is tenant/version-specific.
2. The `objectId` becomes the **`sts:ExternalId`** in the IAM role's trust policy
   (confused-deputy protection), trusting the Dynatrace AWS principal.
3. Deploy Dynatrace's **CloudFormation** template in the AWS account to create the
   cross-account role; copy the resulting **Role ARN** back into the connection.

```bash
wget -O da-aws-activation.yaml \
  https://dynatrace-data-acquisition.s3.amazonaws.com/aws/deployment/cfn/latest/da-aws-activation.yaml
aws cloudformation deploy --region "${REGION}" \
  --stack-name "${CONFIG_NAME}" --template-file da-aws-activation.yaml \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides pDynatraceUrl="${ENV_URL}" pMonitoringConfigId="${CFG_ID}" \
    pDtApiToken="${SETTINGS_TOKEN}" pDtIngestToken="${INGEST_TOKEN}" \
    pDtLogsIngestEnabled=TRUE pDtLogsIngestRegions="${LOG_REGIONS}"
# Note: two separate tokens — a settings/platform token AND an ingest token.
```

### D.2 The monitoring-configuration API (verbatim shape)

Always **query the active schema version first** — never hardcode it:

```bash
curl -X GET "https://${ENV_URL}/platform/extensions/v2/extensions?filter=name='com.dynatrace.extension.da-aws'&add-fields=activeVersion" \
  -H "Authorization: Bearer ${PLATFORM_TOKEN}"

curl -X POST "https://${ENV_URL}/platform/extensions/v2/extensions/com.dynatrace.extension.da-aws/monitoring-configurations" \
  -H "Authorization: Bearer ${PLATFORM_TOKEN}" -H "Content-Type: application/json" \
  -d '{
    "scope": "integration-aws",
    "value": {
      "enabled": true, "description": "prod-aws", "version": "${ACTIVE_VERSION}",
      "featureSets": ["EC2_essential","RDS_essential","Lambda_essential","S3_essential","SQS_essential"],
      "aws": {
        "deploymentRegion": "us-east-1",
        "credentials": [{ "enabled": false, "description": "prod-aws", "connectionId": "*", "accountId": "${AWS_ACCOUNT_ID}" }],
        "regionFiltering": ["us-east-1","eu-west-1"],
        "metricsConfiguration": { "enabled": true, "regions": ["us-east-1","eu-west-1"] },
        "cloudWatchLogsConfiguration": { "enabled": false, "regions": [] },
        "configurationMode": "QUICK_START", "deploymentScope": "SINGLE_ACCOUNT",
        "deploymentMode": "MANUAL", "manualDeploymentStatus": "COMPLETE", "automatedDeploymentStatus": "NA"
      }
    }
  }'
```

- `featureSets` use `<Service>_essential` naming (richer sets exist); QUICK_START
  defaults cover EC2, RDS, Lambda, S3, SQS, EBS, ECS, DynamoDB, ELBs, etc.
- `credentials[].connectionId` = the connection's captured `objectId` (`"*"` is a
  placeholder). One environment allows up to **500** AWS connections.
- The Dynatrace trust **account id varies by Dynatrace cloud region** — read it
  from your tenant's connection wizard, don't copy one from docs blindly.

---

## PHASE E — MONITORING-AS-CODE

Two officially supported, current paths. Both manage Settings 2.0 objects,
dashboards, SLOs, alerting profiles, management zones — as version-controlled code.

| | **Terraform provider `dynatrace-oss/dynatrace`** | **Monaco (Configuration as Code CLI)** |
|---|---|---|
| Model | HCL resources; external state → drift detection | Native JSON/YAML; no state dependency |
| Best when | Already Terraform-centric; want unified infra+observability + plan/apply | Want a Dynatrace-native tool, strong multi-environment templating, or to wrap in an existing pipeline |
| Combine | — | Monaco 2.0 is a binary you can call from Terraform (`local-exec`) |

```hcl
# Terraform: an SLO + a management zone as code
resource "dynatrace_slo" "checkout_availability" {
  name             = "Checkout availability"
  metric_expression = "..."   # DQL/metric-backed
  target           = 99.9
  warning          = 99.95
  evaluation_type  = "AGGREGATE"
  timeframe        = "-1d"
}
```

**Workflow (either tool):** author config in Git → PR review → CI applies
(`terraform plan/apply` or `monaco deploy`) per environment with
**environment-scoped tokens** → scheduled drift checks. Never click-ops production.

---

## OPERATIONS & DAY-2

- **SLOs** as code, alert on **burn rate** not raw thresholds.
- **Davis AI / Problems:** lean on automatic baselining + problem correlation;
  tune via **alerting profiles** (severity + management zone + event filters)
  rather than per-metric static thresholds.
- **Management zones** partition data + scope RBAC per team/tenant.
- **OpenPipeline** routes, masks, and enriches logs/events at ingest.
- **Dashboards & Notebooks** authored in **DQL** against Grail, versioned in Git.
- **Workflows (AutomationEngine)** + the AWS connector enable closed-loop
  remediation.

---

## ANTI-PATTERNS (each one fails review)

| Anti-pattern | Why it breaks | Do instead |
|---|---|---|
| Wrong plane / wrong token (platform token on `/api/v2`, Api-Token on `/platform`) | 401/403 regardless of payload | Use the PLANE & AUTH MAP; right plane → right credential |
| One credential for both OTLP ingest and DQL query | Different planes + tokens (Principle 2) | `Api-Token` on `.live` to ingest; `Bearer` on `.apps` to query |
| Over-scoped / shared god-token | Blast radius; leak risk | One least-scope token per purpose + environment |
| Token in `?api-token=` query param | URLs get logged | `Authorization` header only |
| Polling classic Metrics v2 for analysis | Legacy; slow; not Grail-native | Query Grail with **DQL** |
| Config via `/api/config/v1` for new work | Being superseded | **Settings 2.0** (`/api/v2/settings/objects`) |
| OTLP over gRPC or JSON | Not supported — rejected | OTLP/HTTP **binary protobuf** only |
| Cumulative-temporality OTel metrics | Rejected (HTTP 400) | **Delta** (`...TEMPORALITY_PREFERENCE=delta` or `cumulativetodelta`) |
| ActiveGate/static-key AWS monitoring | Deprecated 2026-03-31 | Agentless `da-aws` role + ExternalId connector |
| Hardcoded env URLs / `da-aws` schema version / trust account id | Breaks across tenants/regions | Parameterize; query `activeVersion`; read trust id from the wizard |
| Re-sending filters alongside `nextPageKey` | Errors — filters are baked into the key | Resend **only** `nextPageKey` |
| High-cardinality metric dimensions | Tuple-limit exhaustion → dropped series | Keep dimensions bounded |
| Click-ops production dashboards/SLOs/alerts | Undiffable, undocumented | Monitoring-as-code (Terraform/Monaco) |

---

## PRE-DONE VERIFICATION CHECKLIST

**Auth & plane**
- [ ] Each call uses the correct plane + credential (Classic `Api-Token` vs Platform `Bearer`); token prefix `dt0c01`/`dt0s16`/`dt0s02` matches the plane.
- [ ] Tokens are least-scope, one per purpose, per environment; passed in the header; not in Git.

**API**
- [ ] Settings 2.0 used for new config (not `/api/config/v1`); `schemaId`/`scope`/`value` valid against the schema.
- [ ] Pagination resends only `nextPageKey`; 429 honors `Retry-After`.

**DQL**
- [ ] Queries run on the platform plane with `storage:*:read` scopes; `timeseries` for metrics, `makeTimeseries` for records; timeframe comes from context or explicit `from:`/`to:`.

**OTel**
- [ ] OTLP/HTTP protobuf; per-signal scope set; **delta** temporality; histograms gated on ≥1.300; Collector pinned.

**AWS**
- [ ] Role-based connector (ExternalId), no static keys; `activeVersion` queried; legacy connections migrated; not relying on a hardcoded trust account id.

**As-code**
- [ ] Dashboards/SLOs/alerting in Git (Terraform or Monaco), applied per env with scoped tokens.

---

## REFERENCE

### Plane / auth / scope quick card
- Classic `*.live.dynatrace.com/api/{v1,v2,config/v1}` → `Api-Token dt0c01.…`.
- Platform `*.apps.dynatrace.com/platform/…` (DQL, Settings, Extensions v2) → `Bearer` (`dt0s16.` platform token / `dt0s02.` OAuth client).
- Account `api.dynatrace.com/iam/v1` → OAuth client `Bearer` (client_credentials @ `sso.dynatrace.com/sso/oauth2/token`).
- Managed `https://{domain}/e/{env-id}/api/…` → `Api-Token` (classic only).

### Grail Query API
`POST /platform/storage/query/v1/query:execute` → `GET …/query:poll?request-token=…`
(async; `state` RUNNING→SUCCEEDED). SDK: `@dynatrace-sdk/client-query`.

### OTLP ingest
`POST {env}.live.dynatrace.com/api/v2/otlp/v1/{traces|metrics|logs}` · `Api-Token` ·
HTTP/protobuf · delta metrics.

### Tooling
Config-as-code: `dynatrace-oss/dynatrace` Terraform provider; **Monaco** CLI.
Collector: `Dynatrace/dynatrace-otel-collector`. Account ops: OAuth client.
**Pin every example to your tenant's API/schema versions** — Dynatrace's planes,
scopes, and `da-aws` schema move; confirm against `/platform/swagger-ui` and the
provider/Collector release you run.

---

## SUBAGENT ORCHESTRATION

When this repo's Dynatrace subagents are installed (`.claude/agents/`), delegate
surface work to the specialist; this skill is the shared contract. The subagents
are **repo-scoped** — installing only this `SKILL.md` elsewhere will not carry them.

| Surface | Subagent | Owns |
|---|---|---|
| Auth + API | `dynatrace-api-client` | tokens (3 types + plane selection), Environment API v2, Settings 2.0, pagination, rate limits |
| Query | `dynatrace-dql-author` | DQL/Grail pipelines, `timeseries`, the `query:execute`/`poll` API, `storage:*` scopes |
| Ingest (OTel) | `dynatrace-otel-ingest-engineer` | OTLP endpoints/scopes, SDK config, delta temporality, the Dynatrace Collector distro, enrichment |
| Ingest (AWS) | `dynatrace-cloud-integrator` | `da-aws` connector, role + ExternalId, CloudFormation, monitoring-config API, legacy migration |
| As-code | `dynatrace-monitoring-as-code` | Terraform provider + Monaco, Settings-2.0/dashboards/SLOs/alerting as code, GitOps |

Every subagent enforces the **CORE PRINCIPLES** and the **PLANE & AUTH MAP**. For
end-to-end work, run api-client → (dql-author | otel-ingest-engineer |
cloud-integrator) → monitoring-as-code.
