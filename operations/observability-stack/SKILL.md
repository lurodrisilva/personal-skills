---
name: observability-stack
description: >-
  MUST USE when building or operating **vendor-neutral, open-source
  observability** — the Prometheus / Grafana / OpenTelemetry / Loki / Tempo /
  Alertmanager stack (the Grafana **LGTM** framing) — and **SLOs** on top of it.
  This is the OSS, self-hosted counterpart to the commercial `dynatrace` skill.
  Covers the three signals (**metrics, logs, traces**) correlated into **one
  context** via exemplars / `trace_id` / consistent resource labels and
  **OpenTelemetry semantic conventions**; **PromQL** recording + alerting rules,
  Prometheus Operator **`ServiceMonitor`** / **`PodMonitor`** / **`PrometheusRule`**,
  relabeling, **cardinality** control, and long-term storage (remote-write /
  **Thanos** / **Mimir** / Cortex); the **OpenTelemetry Collector** (receivers /
  processors / exporters / connectors, OTLP, `batch` / `memory_limiter` /
  `k8sattributes` / **tail-sampling**, auto vs manual instrumentation); **Loki** +
  **LogQL** and **Tempo** + **TraceQL** with exemplar-driven **trace ↔ log
  correlation** and structured logging; **Grafana dashboards-as-code** (JSON model
  / provisioning / **grafana-operator** / the Terraform provider), **RED** for
  services and **USE** for resources; **SLI / SLO / error-budget** with **Sloth**
  and **OpenSLO**, and **multi-window multi-burn-rate** alerts; and **Alertmanager**
  routing trees, grouping, inhibition, silences, and on-call routing. Use for —
  "prometheus", "promql", "recording rule", "alerting rule", "servicemonitor",
  "podmonitor", "prometheusrule", "cardinality explosion", "remote write", "thanos",
  "mimir", "opentelemetry collector", "otel collector", "otlp", "tail sampling",
  "k8sattributes", "semantic conventions", "loki", "logql", "tempo", "traceql",
  "exemplars", "trace to logs", "structured logging", "grafana dashboard as code",
  "grafana-operator", "RED method", "USE method", "SLO", "error budget", "burn
  rate", "sloth", "openslo", "alertmanager", "routing tree", "inhibition", "alert
  too noisy", "on-call routing". Triggers on surfaces — `PrometheusRule` /
  `ServiceMonitor` / `PodMonitor` YAML, `otel-collector-config.yaml` (receivers /
  processors / exporters / service.pipelines), `alertmanager.yml` (route /
  receivers / inhibit_rules), Grafana dashboard JSON / provisioning, Sloth /
  OpenSLO SLO specs. Scope boundary — the **commercial APM sibling** Dynatrace
  (DQL / Grail / OneAgent / the Dynatrace API) → `../../platform-engineering/dynatrace/`;
  **Azure-native** Monitor / Log Analytics **KQL** → `../../platform-engineering/kusto-kql-api/`
  (+ `azure-pg-flex`); **generic Day-2 kubectl triage** (Pod failures, rollouts,
  scheduling) → `kubernetes-operations`; the **agentic MCP / blast-radius doctrine**
  → `agentic-k8s-ops`. This skill owns the **OSS Prometheus / Grafana / OTel
  observability + SLO practice**: the correlation model, instrumentation, rules,
  dashboards, SLOs, and read-only telemetry-reading tooling. Authored as an
  observability engineer's playbook — three signals one context, instrument with
  OpenTelemetry, alert on SLO burn not causes, everything as code, and cardinality
  is a budget. **Prometheus, Grafana, the OpenTelemetry Collector, Loki, Tempo, and
  the SLO tooling evolve quickly: state behavior, pin no version, and verify PromQL
  functions, Collector components, LogQL/TraceQL syntax, and Alertmanager config
  against the Prometheus / Grafana / OpenTelemetry docs before relying on them.**
license: BSD-3-Clause
compatibility: opencode
metadata:
  domain: operations
  stack: prometheus, grafana, loki, tempo, opentelemetry, alertmanager
  signals: metrics, logs, traces
  spec: opentelemetry, promql, openslo
  pattern: observability-slo
  surfaces: metrics-rules, otel-collection, logs-traces, dashboards, slo-error-budget, alert-routing
  use_cases: red-use-method, burn-rate-alerting, trace-correlation, dashboards-as-code
---

# Observability Stack (OSS)

You are an observability engineer running **vendor-neutral, open-source
observability** — the **Prometheus / Grafana / OpenTelemetry / Loki / Tempo /
Alertmanager** stack (the Grafana **LGTM** framing) — plus the **SLO** practice on
top of it. Observability is not three disconnected dashboards; it is the ability to
ask *new* questions about a running system from its telemetry, and to know when the
system is failing its users **before** they tell you. This skill is the OSS,
self-hosted counterpart to the commercial `dynatrace` skill: same discipline,
open tooling you assemble and own.

**The mental model.** Three signals, one context. Metrics, logs, and traces answer
different questions, but only become *observability* when they are correlated into a
single narrative for one request, on one context:

```
        ┌──────────── ONE CONTEXT ────────────┐
        │  (OTel resource labels · trace_id ·  │
        │   exemplars · semantic conventions)  │
        ▼                ▼                 ▼
     METRICS  ◄──────►  TRACES  ◄──────►  LOGS
   "is it bad,       "where in the      "why did THIS
    how bad,          request did it     request fail?"
    trending?"        get slow?"         (structured)
   Prometheus         Tempo/TraceQL      Loki/LogQL
```

- **Metrics** (Prometheus) — cheap, aggregate, always-on: *is it bad, how bad, is it
  trending?* Drive SLOs and alerts.
- **Traces** (Tempo) — per-request causal path across services: *where did the latency
  or error come from?* An **exemplar** links a metric bucket to a concrete `trace_id`.
- **Logs** (Loki) — the detail for one event: *why did this specific request fail?*
  Correlated back to a trace by a shared `trace_id` in structured log fields.
- The glue is **OpenTelemetry semantic conventions** + consistent **resource labels**
  (`service.name`, `service.namespace`, `k8s.*`, `deployment.environment`): the same
  entity is named the same way in all three signals, so a dashboard, a trace, and a
  log line line up.

> **Scope boundary.**
> - **The commercial APM sibling — Dynatrace** (DQL on Grail, OneAgent, the two-plane
>   Dynatrace API, the `da-aws` connector) → `../../platform-engineering/dynatrace/`.
>   This skill is the **OSS** side; do not duplicate Dynatrace here — cross-link it.
> - **Azure-native telemetry** — Azure Monitor / Log Analytics / Application Insights
>   **KQL** → `../../platform-engineering/kusto-kql-api/` (+ `azure-pg-flex`). KQL ≠
>   PromQL/LogQL/TraceQL.
> - **Generic Day-2 kubectl triage** — Pod failures, rollouts, scheduling, drain,
>   capacity → `kubernetes-operations`. This skill *observes*; that one *operates*.
> - **The agentic MCP tool-belt + blast-radius doctrine** → `agentic-k8s-ops`.
> This skill owns the **OSS observability + SLO practice**: correlation, rules,
> instrumentation, dashboards, SLOs, and read-only telemetry reading.

> **Version gate (read first).** Prometheus, Grafana, the OpenTelemetry Collector,
> Loki, Tempo, Sloth, and Alertmanager all move quickly and their component sets
> drift. **State behavior, pin no version number, and verify PromQL functions,
> Collector receivers/processors/exporters/connectors, LogQL / TraceQL syntax, SLO
> spec fields, and Alertmanager config against `prometheus.io`, `grafana.com`, and
> `opentelemetry.io` before relying on any of them.** Validate rules/config with
> `promtool` / `otelcol validate` / `amtool` in CI — see `tools/`.

---

## CORE PRINCIPLES (NON-NEGOTIABLE)

1. **Three signals, one context.** Metrics, logs, and traces are worthless in
   isolation — instrument so they *correlate*: exemplars link a metric to a
   `trace_id`, structured logs carry the `trace_id`/`span_id`, and every signal shares
   the same **OTel resource labels** and **semantic conventions**. A dashboard you
   can't pivot from into the offending trace and its logs is decoration.
2. **Instrument with OpenTelemetry; let the Collector decouple you from the backend.**
   Apps emit **OTLP** to a **Collector**, not to a vendor SDK. The Collector is the
   seam: swap Prometheus for Mimir, Loki for something else, add tail-sampling — and
   the apps never change. Vendor-neutral instrumentation is the whole point.
3. **Alert on symptoms and SLO burn rate, not causes.** Page on what the *user*
   experiences (error rate, latency, availability) via **multi-window multi-burn-rate**
   SLO alerts — never on static CPU/memory thresholds that fire nightly and train
   people to ignore the pager. Use **RED** for services, **USE** for resources.
4. **Everything as code.** Prometheus recording/alerting rules, Grafana dashboards,
   Alertmanager routes, and SLO definitions all live in **Git** and are **CI-validated**
   (`promtool check rules`, `otelcol validate`, `amtool check-config`). Click-ops
   dashboards and hand-edited alertmanager.yml on a box are undiffable and un-reviewable.
5. **Cardinality is a budget.** Every distinct label-value combination is a time
   series (Prometheus) or an indexed stream (Loki). A single unbounded label — user id,
   full URL, request id, pod UUID, timestamp — melts Prometheus and blows up Loki cost.
   Keep label sets bounded; drop high-cardinality labels with `metric_relabel_configs`.
6. **SLOs come from SLIs tied to user journeys, with an error-budget policy.** An SLO
   without a defined **error-budget policy** (what you *do* when the budget burns —
   freeze releases, page, review) is a vanity number. Derive SLIs from real user
   journeys (checkout, login, API read), not from whatever is easy to measure.
7. **Dashboards answer a question, don't decorate.** Every panel earns its place by
   answering "is it healthy / where is it broken?" A wall of 60 graphs nobody reads is
   worse than four RED panels and a link to the trace.
8. **The tools are read-only to observe; changing telemetry config is a gated change.**
   Querying Prometheus/Loki/Tempo/Grafana and validating config are **read-only**.
   Changing a recording/alerting rule, a Collector pipeline, a dashboard, or an
   Alertmanager route is a **gated Git change** (PR + CI) — never a live hand-edit,
   never an autonomous mutation. See the MCP surface.

---

## TRIAGE MAP — symptom / question → phase → agent

| Symptom or question | Phase | Agent |
|---|---|---|
| "No memory/CPU signal to right-size from" | A (metrics & rules) | `prometheus-rules-author` |
| "This alert rule fires wrong / recording rule is slow" | A | `prometheus-rules-author` |
| "Prometheus is OOMing / too many series" (cardinality) | A | `prometheus-rules-author` |
| "Scrape target isn't discovered" (`ServiceMonitor`/`PodMonitor`) | A | `prometheus-rules-author` |
| "Need long-term metrics / cross-cluster query" (Thanos/Mimir) | A | `prometheus-rules-author` |
| "App isn't emitting traces / OTLP isn't arriving" | B (collection) | `otel-collector-engineer` |
| "Too many traces — need sampling" (tail-sampling) | B | `otel-collector-engineer` |
| "Spans missing k8s / service metadata" (semantic conventions) | B | `otel-collector-engineer` |
| "Auto- vs manual-instrument this service" | B | `otel-collector-engineer` |
| "Can't correlate a slow trace to its logs" | C (logs & traces) | `loki-tempo-correlation` |
| "LogQL / TraceQL query help" | C | `loki-tempo-correlation` |
| "Logs aren't structured / no trace_id in logs" | C | `loki-tempo-correlation` |
| "Build this dashboard as code" (JSON/operator/Terraform) | D (dashboards) | `grafana-dashboard-author` |
| "RED / USE panels for a service or node" | D | `grafana-dashboard-author` |
| "Define an SLO / error budget for a journey" | D | `slo-alerting-engineer` |
| "Generate burn-rate alerts from an SLO" (Sloth/OpenSLO) | D/E | `slo-alerting-engineer` |
| "Alert too noisy / paging the wrong people" | E (routing) | `slo-alerting-engineer` |
| "Design the Alertmanager routing tree / inhibition" | E | `slo-alerting-engineer` |

---

## PHASE A — METRICS & RULES (Prometheus / PromQL)

**Goal:** trustworthy metrics with bounded cardinality, precomputed recording rules,
and symptom-based alerting rules — the substrate SLOs and dashboards read from.

### PromQL essentials
- **Instant vector** (one sample per series now) vs **range vector** (`[5m]`, samples
  over a window). `rate()` / `increase()` take a **range vector of a counter**; gauges
  use `avg_over_time()` etc.
- Rate-then-aggregate for correctness: `sum by (route) (rate(http_requests_total[5m]))`.
- Latency from a histogram: `histogram_quantile(0.99, sum by (le) (rate(http_request_duration_seconds_bucket[5m])))`.
- Error ratio (a RED "Errors" SLI): `sum(rate(http_requests_total{code=~"5.."}[5m])) / sum(rate(http_requests_total[5m]))`.

### Recording vs alerting rules (both `PrometheusRule`)
```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata: { name: app-rules, labels: { role: alert-rules } }
spec:
  groups:
    - name: app.rules
      rules:
        # recording rule: precompute an expensive/reused expression
        - record: job:http_request_error_rate:ratio5m
          expr: |
            sum by (job) (rate(http_requests_total{code=~"5.."}[5m]))
            / sum by (job) (rate(http_requests_total[5m]))
        # alerting rule: SYMPTOM-based, with for: + labels + annotations
        - alert: HighErrorRate
          expr: job:http_request_error_rate:ratio5m > 0.05
          for: 10m
          labels: { severity: page }
          annotations:
            summary: "5xx error rate >5% for {{ $labels.job }}"
```
- **Recording rules** precompute frequently-used / expensive expressions (SLO burn
  rates, RED aggregates) so dashboards and alerts read a cheap series. Name them
  `level:metric:operation` (Prometheus convention).
- **Alerting rules** = `expr` + `for:` (sustained duration debounces flaps) + `labels`
  (drive routing — `severity`) + `annotations` (human context). Alert on symptoms.

### Scrape discovery (Prometheus Operator)
- **`ServiceMonitor`** selects **Services** (scrape their endpoints); **`PodMonitor`**
  selects **Pods** directly (no Service). Both match by label selector + port name.
- The operator's `serviceMonitorSelector` / `podMonitorSelector` decides which of these
  the Prometheus instance picks up — a common "why isn't my target scraped?" trap.

### Relabeling & cardinality control
- **`relabel_configs`** run **before** the scrape (choose/drop targets, rewrite the
  target label set). **`metric_relabel_configs`** run **after** scrape, **before
  ingestion** — the place to `drop` a high-cardinality metric or label.
```yaml
metric_relabel_configs:
  - source_labels: [__name__]
    regex: 'apiserver_request_duration_seconds_bucket'   # notoriously high-cardinality
    action: drop
  - regex: '(user_id|request_id|full_path)'              # drop unbounded labels
    action: labeldrop
```
- **Cardinality is a budget:** find the offenders with `topk(20, count by (__name__)({__name__=~".+"}))`
  and Prometheus's own `/tsdb-status`. Never put an unbounded value in a label.

### Long-term & global storage
Local Prometheus TSDB is short-retention and single-cluster. For long retention and a
global query view use **`remote_write`** to **Mimir** / Cortex, or front multiple
Prometheis with **Thanos** (Sidecar + Store + Querier). The *decision* is retention +
global-query + HA; the mechanics live in the Prometheus/Thanos/Mimir docs.

---

## PHASE B — COLLECTION & INSTRUMENTATION (OpenTelemetry)

**Goal:** apps emit **OTLP** to a **Collector** that enriches, samples, and fans out to
the backends — apps stay backend-agnostic.

### The Collector pipeline shape
`receivers → processors → exporters`, wired per-signal in `service.pipelines`.
**Connectors** join two pipelines (e.g. `spanmetrics` derives RED metrics from spans).
```yaml
receivers:
  otlp:
    protocols: { grpc: { endpoint: 0.0.0.0:4317 }, http: { endpoint: 0.0.0.0:4318 } }
processors:
  memory_limiter: { check_interval: 1s, limit_percentage: 80, spike_limit_percentage: 25 }
  k8sattributes: {}                       # stamp k8s.* resource attributes
  resource:
    attributes: [{ key: deployment.environment, value: prod, action: upsert }]
  batch: {}                               # batch just before export
exporters:
  otlphttp/tempo:   { endpoint: http://tempo:4318 }
  prometheusremotewrite/mimir: { endpoint: http://mimir/api/v1/push }
  otlphttp/loki:    { endpoint: http://loki:3100/otlp }
service:
  pipelines:
    traces:  { receivers: [otlp], processors: [memory_limiter, k8sattributes, resource, batch], exporters: [otlphttp/tempo] }
    metrics: { receivers: [otlp], processors: [memory_limiter, k8sattributes, resource, batch], exporters: [prometheusremotewrite/mimir] }
    logs:    { receivers: [otlp], processors: [memory_limiter, k8sattributes, resource, batch], exporters: [otlphttp/loki] }
```
- **Ordering matters:** `memory_limiter` **first** (shed load before OOM), `batch`
  **last** before the exporter. `k8sattributes` / `resource` enrich in between.
- **Validate the config** with `otelcol validate --config …` in CI before rollout
  (`tools/otel-config-validate.sh`). Component availability differs between the `core`
  and `contrib` distributions — verify against the distro you run.

### Tail-based sampling (keep the interesting traces)
Head sampling decides at trace start (blind to the outcome); **tail sampling** decides
after seeing the whole trace — keep all errors + slow traces, sample the rest.
```yaml
processors:
  tail_sampling:
    decision_wait: 10s
    policies:
      - { name: errors,     type: status_code, status_code: { status_codes: [ERROR] } }
      - { name: slow,       type: latency,     latency: { threshold_ms: 500 } }
      - { name: sample-rest, type: probabilistic, probabilistic: { sampling_percentage: 5 } }
```
> **Tail sampling needs every span of a trace on the *same* collector instance.** Put a
> **load-balancing exporter** tier (routing by `trace_id`) in front of the sampling
> collectors, or tail sampling silently drops partial traces.

### Semantic conventions & instrumentation
- Set the required **`service.name`** (+ `service.namespace`, `service.version`,
  `deployment.environment`) and align attributes to **OTel semantic conventions** so
  the same entity correlates across signals. `k8sattributes` adds `k8s.pod.name` etc.
- **Auto-instrumentation** (language agent / the OTel Operator's `Instrumentation` CR)
  for zero-code HTTP/DB/RPC spans; **manual** SDK spans for business-meaningful
  operations. Prefer auto for breadth, manual for the spans that matter to an SLO.

---

## PHASE C — LOGS & TRACES (Loki / Tempo, correlation)

**Goal:** given a symptom in metrics, pivot to the exact trace and its logs — the
"one context" payoff.

### Loki + LogQL
LogQL = a **stream selector** (indexed labels, in `{}`) + line/label filters, and can
aggregate into metrics:
```logql
# error lines for one service, as a rate — {} selects INDEXED labels only
sum by (level) (rate({service_name="checkout", level="error"} |= "timeout" [5m]))
# parse a field then filter (label_format / json / logfmt run per-line, not indexed)
{service_name="checkout"} | json | duration > 500ms
```
> **Loki cardinality is the same budget as Prometheus.** Loki **indexes labels**; a
> high-cardinality label (`trace_id`, `user_id`, `path`) as a *stream label* explodes
> stream count. Keep those in the **log line** (extract at query time with `| json`),
> not in the stream selector.

### Tempo + TraceQL
```traceql
{ resource.service.name = "checkout" && status = error && duration > 500ms }
```
TraceQL selects spans by resource/span attributes, duration, and status; you rarely
browse Tempo by hand — you **arrive from an exemplar or a log**.

### Correlation — the exemplar / trace_id spine
- **Exemplars** attach a `trace_id` to specific metric samples (e.g. a slow histogram
  bucket). In Grafana, an exemplar dot on a latency panel is a one-click jump into the
  trace in Tempo. Emit them from the SDK (OTLP carries exemplars).
- **Trace → logs** and **logs → trace**: Grafana **derived fields** / datasource links
  turn a `trace_id` in a Loki log line into a link to the Tempo trace, and Tempo's
  **trace-to-logs** config turns a span into a Loki query scoped by `service_name` +
  time + `trace_id`. This only works if logs are **structured** and carry `trace_id`.
- **Structured logging** is the precondition: emit JSON logs with `trace_id` / `span_id`
  (from the active span context) and consistent `service_name` — free-text logs can't be
  correlated or reliably queried.

---

## PHASE D — DASHBOARDS & SLOs (Grafana, RED/USE, error budgets)

**Goal:** dashboards that answer health questions, and SLOs with burn-rate alerts —
all as code.

### Dashboards as code (four options, same discipline)
| Approach | Use when |
|---|---|
| **JSON model in Git** | full control; the source of truth for every dashboard |
| **Grafana provisioning** (dashboards/datasources as files) | GitOps-mounted config on the Grafana instance |
| **grafana-operator** (`GrafanaDashboard` / `GrafanaDatasource` CRDs) | Kubernetes-native, reconciled from Git |
| **Terraform provider** (`grafana_dashboard`) | dashboards alongside other IaC |
Never hand-edit a production dashboard in the UI without exporting the JSON back to Git.

### RED (services) and USE (resources)
- **RED** for every request-driven service: **R**ate (req/s), **E**rrors (error ratio),
  **D**uration (p50/p90/p99 from the histogram). These are also your SLI candidates.
- **USE** for every resource (node, disk, queue): **U**tilization, **S**aturation,
  **E**rrors. USE finds the *cause* a RED symptom points at.
- Use **template variables** (`$service`, `$namespace`) so one dashboard serves many
  services instead of copy-pasting 40 near-identical boards.

### SLIs, SLOs, and error budgets
- **SLI** = good events / valid events (e.g. `1 - error_ratio`, or fraction of requests
  under a latency threshold). **SLO** = the target (e.g. 99.9% over 28d). **Error
  budget** = `1 − SLO` — the allowed failure you *spend* on releases and incidents.
- Generate the recording + **multi-window multi-burn-rate** alerting rules from a
  declarative spec with **Sloth** (Prometheus-native) or the vendor-neutral **OpenSLO**
  spec — don't hand-author burn-rate math:
```yaml
# Sloth SLO spec → promtool-valid recording + burn-rate alerting rules
version: prometheus/v1
service: checkout
slos:
  - name: requests-availability
    objective: 99.9
    sli:
      events:
        error_query:  sum(rate(http_requests_total{job="checkout",code=~"5.."}[{{.window}}]))
        total_query:  sum(rate(http_requests_total{job="checkout"}[{{.window}}]))
    alerting:
      name: CheckoutHighErrorRate
      page_alert:   { labels: { severity: page } }
      ticket_alert: { labels: { severity: ticket } }
```
- Every SLO needs a written **error-budget policy**: what happens when it burns (freeze
  risky deploys, page, run a review). That policy is the point of the SLO.

---

## PHASE E — ALERTING & ROUTING (Alertmanager, burn rate)

**Goal:** the right human paged, once, with context — and quiet otherwise.

### Multi-window multi-burn-rate (why, not just static thresholds)
A single threshold either pages too late (slow burn) or too often (noise). The Google
SRE pattern pairs a **fast** window (e.g. 1h *and* 5m at a high burn rate ≈14.4×) for
**page**-severity, with a **slow** window (e.g. 6h *and* 30m at ≈6×) for **ticket**
severity. The short window confirms the long one is still burning — killing flapping.
Sloth/OpenSLO emit exactly these; route them by `severity`.

### Alertmanager routing tree
```yaml
route:
  receiver: default
  group_by: ['alertname', 'namespace']      # collapse related alerts into one notification
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h
  routes:
    - matchers: ['severity="page"']
      receiver: pagerduty-oncall
    - matchers: ['severity="ticket"']
      receiver: jira
inhibit_rules:                              # a firing "cluster down" mutes the noise beneath it
  - source_matchers: ['severity="page"', 'alertname="ClusterDown"']
    target_matchers:  ['severity="ticket"']
    equal: ['namespace']
receivers:
  - name: default
  - name: pagerduty-oncall
  - name: jira
```
- **Grouping** (`group_by`) bundles related alerts into one notification; **`group_wait`
  / `group_interval` / `repeat_interval`** tune first-notify / batching / reminders.
- **Inhibition** suppresses downstream symptoms while a root-cause alert fires (mute the
  100 pod alerts under one "node down").
- **Silences** are time-boxed, matcher-based mutes for known maintenance — set via
  `amtool` or the UI, **not** by deleting the rule.
- Validate the whole thing in CI: `amtool check-config alertmanager.yml` and dry-run the
  tree with `amtool config routes test` (`tools/alert-routing-check.sh`).

---

## ANTI-PATTERNS (each one bites)

| Anti-pattern | Why it breaks | Do instead |
|---|---|---|
| Three signals, no correlation | can't pivot metric → trace → log | share OTel resource labels + `trace_id`; emit exemplars |
| App exports straight to a vendor SDK | locks you in; no central sampling/enrichment | emit **OTLP** to a **Collector**; it fans out |
| Alerting on CPU/memory thresholds | fires nightly; trains people to ignore the pager | alert on **symptoms** + **SLO burn rate** |
| Static single-threshold SLO alert | pages too late or too noisy | **multi-window multi-burn-rate** (Sloth/OpenSLO) |
| Click-ops dashboards / hand-edited alertmanager.yml | undiffable, un-reviewable, lost on redeploy | everything as code + `promtool`/`amtool`/`otelcol validate` in CI |
| Unbounded label (user_id, url, trace_id) on a metric/stream | cardinality explosion — Prometheus OOM / Loki cost | keep labels bounded; `metric_relabel_configs` drop; trace_id in the log line |
| `trace_id` as a **Loki stream label** | explodes stream count | put it in the line; extract with `\| json` at query time |
| Tail sampling without a load-balancer tier | spans of a trace hit different collectors → partial drops | route by `trace_id` to the sampling collectors first |
| Head-sampling then wishing you'd kept the errors | the interesting traces are already gone | **tail** sampling: keep errors + slow, sample the rest |
| SLO with no error-budget policy | a vanity number nobody acts on | define what burning the budget *does* (freeze/page/review) |
| 60-panel "god dashboard" | nobody reads it; hides the signal | RED/USE panels that answer one question + links |
| Pinning a Prometheus/Collector/Loki version in guidance | breaks as components ship fast | describe behavior; verify against the upstream docs |

---

## PRE-DONE VERIFICATION CHECKLIST

**Metrics & rules**
- [ ] Recording rules precompute SLO/RED aggregates; alerting rules are symptom-based with `for:` + `severity`.
- [ ] `ServiceMonitor`/`PodMonitor` discovered by the Prometheus instance; targets `UP`.
- [ ] Cardinality bounded; high-cardinality metrics/labels dropped; `promtool check rules` clean.

**Collection**
- [ ] Apps emit **OTLP** to a **Collector**; `service.name` + semantic conventions set; `k8sattributes` enriching.
- [ ] `memory_limiter` first / `batch` last; `otelcol validate` clean; tail sampling has a load-balancer tier.

**Logs & traces**
- [ ] Logs are **structured** with `trace_id`/`span_id`; exemplars emitted; trace↔log links configured in Grafana.
- [ ] `trace_id`/`user_id` live in the log line, not as Loki stream labels.

**Dashboards & SLOs**
- [ ] Dashboards are code (JSON/provisioning/operator/Terraform); RED for services, USE for resources.
- [ ] SLIs tied to user journeys; SLOs with **multi-window burn-rate** alerts (Sloth/OpenSLO) + a written error-budget policy.

**Alerting & routing**
- [ ] Alertmanager routes by `severity`; grouping + inhibition tuned; `amtool check-config` clean.
- [ ] Page vs ticket severities distinct; silences time-boxed (not rule deletions).

**Doctrine**
- [ ] No version pinned in prose; behavior verified against prometheus.io / grafana.com / opentelemetry.io.
- [ ] Every rule/config/dashboard/route change is a gated, reviewed Git change — reads are read-only.

---

## REFERENCE

### The signal → question → tool map (one line)
Metrics (Prometheus/PromQL) = *is it bad, trending?* · Traces (Tempo/TraceQL) = *where
in the request?* · Logs (Loki/LogQL) = *why did this one fail?* — glued by OTel resource
labels + `trace_id` + exemplars + semantic conventions.

### RED / USE (one line)
**RED** (services): Rate · Errors · Duration — the SLI candidates. **USE** (resources):
Utilization · Saturation · Errors — the cause behind a RED symptom.

### Burn-rate alert pairs (typical, verify against the SRE workbook)
Page: **1h + 5m** windows at ~**14.4×** budget burn. Ticket: **6h + 30m** at ~**6×**.
Generated by Sloth/OpenSLO from the SLO spec; routed by `severity`.

### Validate-in-CI toolchain (one line)
`promtool check config|rules` (Prometheus) · `otelcol validate --config` (Collector) ·
`amtool check-config` + `amtool config routes test` (Alertmanager) — all in `tools/`.

### Read-only triage scripts (`tools/`)
`promtool-check.sh` (validate Prometheus config + rule files; optional read-only
`promtool query instant` if `PROM_URL`+`PROM_QUERY` set) · `otel-config-validate.sh`
(`otelcol validate` the Collector config; list components) · `alert-routing-check.sh`
(`amtool check-config` + `config routes show`/`test` — read-only route simulation).

---

## MCP SURFACE (read-only)

There is **no single official observability MCP server — do not wire a fabricated one.**
Drive existing, guardrailed servers **read-only** to *read telemetry and reason about an
incident*, per the blast-radius doctrine in `agentic-k8s-ops`:

| Server | Use | Guardrail |
|---|---|---|
| **Prometheus MCP server** (**community**, e.g. `pab1it0/prometheus-mcp-server` — **verify availability**) | read-only PromQL **instant / range** queries + metadata (labels, series, targets) | read-only query token; no admin API |
| **Grafana MCP server** (`grafana/mcp-grafana`) | search dashboards, query datasources (Prometheus/Loki/Tempo), list alert rules — scope **read-only** | read-only service-account token; do not grant dashboard/alert write |
| **kubernetes-mcp-server** (`--read-only`) | inspect `ServiceMonitor`/`PodMonitor`/`PrometheusRule`, Collector config, pod health | `--read-only` |
| **GitHub MCP** (read toolsets) | open the **gated PR** that changes a rule/route/dashboard/pipeline | scoped token; PR is the approval gate |

> Label maturity honestly: the Prometheus and Grafana MCP servers are **community**
> projects — **verify availability and scope them read-only** before relying on them. If
> you're unsure a server exists, describe the read-only surface generically (PromQL
> query / dashboard search / config read) and mark it "verify availability."

Default-deny writes. **Reading telemetry — PromQL/LogQL/TraceQL queries, dashboard and
alert-rule listing, config inspection — is read-only; changing a recording/alerting
rule, a Collector pipeline, a dashboard, or an Alertmanager route is a gated, reviewed
Git change** (PR + `promtool`/`otelcol validate`/`amtool` in CI) — never an autonomous
mutation. A wrong routing edit can silence a real page; a wrong rule can hide an
outage. Keep the agent read-mostly and put a human on every config change.

---

## SUBAGENT ORCHESTRATION

This skill drives a **5-agent OSS observability team** in `.claude/agents/`:

| Agent | Owns |
|---|---|
| `prometheus-rules-author` | Phase A — PromQL, recording + alerting rules, `ServiceMonitor`/`PodMonitor`/`PrometheusRule`, relabeling, cardinality control, remote-write/Thanos/Mimir; owns `tools/promtool-check.sh` |
| `otel-collector-engineer` | Phase B — Collector pipelines (receivers/processors/exporters/connectors), OTLP, tail-sampling, `k8sattributes`, semantic conventions, auto vs manual instrumentation; owns `tools/otel-config-validate.sh` |
| `loki-tempo-correlation` | Phase C — Loki/LogQL + Tempo/TraceQL, exemplars, trace↔log correlation, structured logging |
| `grafana-dashboard-author` | Phase D (dashboards) — dashboards-as-code (JSON/provisioning/grafana-operator/Terraform), RED/USE panels, template variables, Grafana unified alerting |
| `slo-alerting-engineer` | Phase D/E (SLO + routing) — SLI/SLO/error-budget, Sloth/OpenSLO, multi-window burn-rate alerts, Alertmanager routing tree/inhibition/grouping; owns `tools/alert-routing-check.sh` |

**Orchestration flow (end-to-end):** `otel-collector-engineer` (get the signals in) →
`prometheus-rules-author` (rules + recording) → `loki-tempo-correlation` (correlate
logs/traces) → `grafana-dashboard-author` (RED/USE dashboards) → `slo-alerting-engineer`
(SLOs + burn-rate routing).

**Handoffs:** the commercial Dynatrace/DQL sibling → `dynatrace`; Azure-native KQL →
`kusto-kql-api`; generic Day-2 kubectl triage → `kubernetes-operations`; the agentic MCP
tool-belt + blast-radius doctrine → `agentic-k8s-ops`.
