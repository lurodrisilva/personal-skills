<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-07-07 | Updated: 2026-07-07 -->

# observability-stack

## Purpose
Skill for **vendor-neutral, open-source observability** — the Prometheus / Grafana /
OpenTelemetry / Loki / Tempo / Alertmanager stack (the Grafana **LGTM** framing) — plus
the **SLO** practice on top of it. It is the **OSS, self-hosted counterpart to the
commercial `dynatrace` skill** (`../../platform-engineering/dynatrace/`): same discipline
(three signals, one context; SLOs; everything as code), open tooling you assemble and own.
Owns the correlation model, PromQL rules, OTel collection, logs/traces correlation,
dashboards-as-code, SLOs + burn-rate alerting, and the read-only telemetry-reading tools.

## Key Files
| File | Description |
|------|-------------|
| `SKILL.md` | The skill — `name: observability-stack`, `domain: operations`, `stack: prometheus, grafana, loki, tempo, opentelemetry, alertmanager`, `signals: metrics, logs, traces`, `spec: opentelemetry, promql, openslo`, `pattern: observability-slo` |

## Subdirectories
| Directory | Purpose |
|-----------|---------|
| `tools/` | 3 read-only config validators (`promtool-check.sh`, `otel-config-validate.sh`, `alert-routing-check.sh`) — `promtool` / `otelcol` / `amtool`; read-only is a hard invariant, `amtool silence add` / `alert add` banned (see `tools/AGENTS.md`) |

## For AI Agents

### Working In This Directory
- Edit `SKILL.md` (and the read-only `tools/` scripts). Almost every change is authoring.
- **The doctrine is the spine, keep it intact on edits:** *three signals, one context*
  (metrics ↔ logs ↔ traces correlated by exemplars / `trace_id` / consistent OTel
  resource labels + semantic conventions) → *instrument with OpenTelemetry; the Collector
  decouples apps from the backend* → *alert on symptoms + SLO burn rate, not causes*
  (multi-window multi-burn-rate; RED for services / USE for resources) → *everything as
  code* (Prometheus rules, Grafana dashboards, Alertmanager routes, SLOs in Git,
  CI-validated with `promtool`/`otelcol validate`/`amtool`) → *cardinality is a budget*
  (a runaway label melts Prometheus / blows up Loki). The tools are **read-only to
  observe**; changing rules/routes/pipelines/dashboards is a **gated Git change**.
- **Version discipline is load-bearing:** Prometheus, Grafana, the OpenTelemetry
  Collector, Loki, Tempo, Sloth, and Alertmanager move fast and their component sets
  drift. **State behavior, pin NO version, and frame PromQL functions / Collector
  components / LogQL-TraceQL syntax / SLO fields / Alertmanager config as "verify against
  prometheus.io, grafana.com, opentelemetry.io".** Same no-version-pin doctrine the
  `dynatrace` / `kubernetes-finops` skills follow.
- Keep the **scope boundary** sharp:
  - **The commercial APM sibling — Dynatrace** (DQL / Grail / OneAgent / the two-plane
    Dynatrace API) → `../../platform-engineering/dynatrace/`. Cross-link it; do **not**
    duplicate it here. This skill is the OSS side.
  - **Azure-native telemetry** — Azure Monitor / Log Analytics / App Insights **KQL** →
    `../../platform-engineering/kusto-kql-api/` (+ `../../platform-engineering/azure-pg-flex/`).
    KQL ≠ PromQL/LogQL/TraceQL.
  - **Generic Day-2 kubectl triage** (Pod failures, rollouts, scheduling) →
    `../kubernetes-operations/`. This skill *observes*; that one *operates*.
  - **The agentic MCP tool-belt + blast-radius doctrine** → `../agentic-k8s-ops/`.
- Highest-value facts to keep correct: correlation glue = OTel resource labels +
  `trace_id` + **exemplars** + semantic conventions; **`relabel_configs`** run pre-scrape
  vs **`metric_relabel_configs`** pre-ingest (where you drop high-cardinality labels);
  Collector processor order = **`memory_limiter` first, `batch` last**; **tail sampling
  needs a load-balancer tier** (spans of a trace on one collector); **`trace_id` belongs
  in the Loki log line, not a stream label**; **RED** (services) / **USE** (resources);
  SLO needs a **written error-budget policy**; burn-rate pairs (page ≈14.4× on 1h+5m,
  ticket ≈6× on 6h+30m) come from **Sloth/OpenSLO**, routed by `severity`.
- The `description:` uses a `>-` block scalar (colon/backtick-dense) — keep it and
  re-verify `yq --front-matter=extract '.description | type'` is `!!str` after edits.

### Testing Requirements
- **`scripts/validate-skills.sh` validates this directory** (`operations/` is in
  `DOMAIN_DIRS`): frontmatter (`name`/`description`/`license`/`compatibility`, non-empty
  `metadata` map), non-empty body, even fence count. Run it after edits.
- `tools/` is **not** validator-covered — verify by hand (`bash -n tools/*.sh`, the
  `amtool` mutating-verb grep returns nothing, executable bit) per `tools/AGENTS.md`.

### Companion Subagents
- Ships a **5-agent OSS observability team** in `../../.claude/agents/`:
  `prometheus-rules-author` (Phase A — PromQL, recording + alerting rules,
  `ServiceMonitor`/`PodMonitor`/`PrometheusRule`, relabeling, cardinality, remote-write/
  Thanos/Mimir — owns `tools/promtool-check.sh`), `otel-collector-engineer` (Phase B —
  Collector pipelines, OTLP, tail-sampling, `k8sattributes`, semantic conventions,
  instrumentation — owns `tools/otel-config-validate.sh`), `loki-tempo-correlation`
  (Phase C — Loki/LogQL + Tempo/TraceQL, exemplars, trace↔log correlation, structured
  logging), `grafana-dashboard-author` (Phase D dashboards — dashboards-as-code, RED/USE,
  variables, unified alerting), `slo-alerting-engineer` (Phase D/E — SLI/SLO/error-budget,
  Sloth/OpenSLO, multi-window burn-rate, Alertmanager routing — owns
  `tools/alert-routing-check.sh`). The SKILL's "Subagent Orchestration" table maps
  phase → agent; update both on rename. Orchestration flow: `otel-collector-engineer` →
  `prometheus-rules-author` → `loki-tempo-correlation` → `grafana-dashboard-author` →
  `slo-alerting-engineer`.

### Common Patterns
- Intro + mental model (three-signals-one-context diagram) → scope boundary → version
  gate → CORE PRINCIPLES → TRIAGE MAP → phases A–E (Metrics & rules / Collection /
  Logs & traces / Dashboards & SLOs / Alerting & routing) → anti-patterns → checklist →
  reference → MCP surface → subagent orchestration. Same authoring shape as the sibling
  `kubernetes-finops` and `dynatrace` skills.

## Dependencies

### Internal
- `../../scripts/validate-skills.sh` — enforces the SKILL.md contract.
- `../../README.md` — references this skill in the "Operations" table; rename → README update.
- `../../.claude/agents/{prometheus-rules-author,otel-collector-engineer,loki-tempo-correlation,grafana-dashboard-author,slo-alerting-engineer}.md`
  — the 5 companion subagents.
- `../../platform-engineering/dynatrace/SKILL.md` (commercial APM sibling),
  `../../platform-engineering/kusto-kql-api/SKILL.md` (Azure KQL),
  `../kubernetes-operations/SKILL.md` (generic Day-2 triage),
  `../agentic-k8s-ops/SKILL.md` (agentic blast-radius) — cross-referenced to keep
  boundaries sharp.

### External
None at runtime — documentation. Describes the OSS observability stack; cites the
Prometheus (`prometheus.io`), Grafana (`grafana.com`), and OpenTelemetry
(`opentelemetry.io`) docs, plus Sloth / OpenSLO. `tools/` scripts need only `promtool`
(Prometheus), `otelcol`/`otelcol-contrib` (OpenTelemetry Collector), and `amtool`
(Alertmanager) — each optional, read-only — plus POSIX `bash`. No `jq`. No version pinned.

<!-- MANUAL: -->
