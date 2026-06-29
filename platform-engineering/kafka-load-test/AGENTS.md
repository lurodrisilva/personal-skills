<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-05-24 | Updated: 2026-05-24 | DEEPINIT: 2026-05-24 -->

# kafka-load-test

## Purpose
Skill that guides authoring + reviewing **load tests against Apache Kafka and Kafka-driven services**. Codifies the **paired-tool methodology**: bundled `kafka-producer-perf-test.sh` / `kafka-consumer-perf-test.sh` for one-time broker baselines whenever broker shape changes; `k6 + xk6-kafka` (v2 API — `Producer`, `Consumer`, `AdminClient`, `SchemaRegistry`) for repeated application-pipeline headline tests. Covers the CGO build paths (`xk6 build` with `librdkafka`, `grafana/xk6` Docker builder, `mostafamoradian/xk6-kafka` image), the k6 lifecycle (`init` / `setup` / `default` / `teardown`), the **topic-creation race** (always `setup()` + `sleep(2)`, never `if (__VU == 0)` at module scope), `ramping-arrival-rate` scenarios, v2-emitted-but-v1-named `kafka_writer_*` / `kafka_reader_*` threshold binding, the fixed sizing knobs, the **four-quadrant watch list** (producer / broker / consumer / app), the **first-breach stop conditions**, in-cluster `Job` execution in `testing-system`, and post-run cleanup.

## Key Files
| File | Description |
|------|-------------|
| `SKILL.md` | Skill definition — `name: kafka-load-test`, `domain: platform-engineering`, `pattern: load-testing-kafka-and-kafka-driven-services`, `platform: kubernetes`, `stack: k6 + xk6-kafka + kafka-perf-test + strimzi` |

## Subdirectories
None.

## For AI Agents

### Working In This Directory
- Edit `SKILL.md` only.
- The 12 non-negotiables at the top of the body are flag-first rules in any load-test PR. Load-bearers: pick the right tool (perf-test.sh = broker, xk6-kafka = service) (#1), broker baseline first when broker shape changes (#2), fix every sizing knob in writing before the run (#3), in-cluster execution to eliminate network skew (#4), **v2 xk6-kafka API only** — v1 `Writer`/`Reader`/`Connection` are deprecated aliases (#5), topic creation in `setup()` never `if (__VU == 0)` (#6), thresholds on `kafka_writer_*` / `kafka_reader_*` turn the run into pass/fail CI (#7), four-quadrant watch (#8), stop on first SLO breach not on time (#9), full post-run cleanup (#10), CGO build via xk6 builder / Docker / prebuilt image (#11), quotas OFF during synthetic perf tests (#12).
- Sister skills (`kafka-strimzi-operator`, `addons-and-building-blocks`) — the cluster-sizing decisions belong upstream; this skill answers "what is the ceiling and what saturated first".
- The `description:` field is intentionally exhaustive (trigger surface). When extending coverage to new scenario shapes or in-cluster execution patterns, extend the description's trigger list to match.

### Testing Requirements
- **`scripts/validate-skills.sh` validates this directory** (its `DOMAIN_DIRS` includes `platform-engineering/`) — CI runs it on every push and PR. Run it locally before pushing; it checks:
  1. YAML frontmatter parses and contains `name`, `description`, `license`, `compatibility`, non-empty `metadata` map.
  2. Markdown body after the closing `---` is non-empty.
  3. Fenced code-block markers are even in count.
- Every example k6 snippet must use the v2 API, create topics in `setup()`, bind k6 thresholds on `kafka_writer_*` / `kafka_reader_*` metrics, and run as a `Job` in `testing-system` against the in-cluster bootstrap `Service`.

### Common Patterns
- "Non-negotiables encoded in this skill" numbered list — same authoring style as other platform-engineering skills.
- "WHEN TO USE THIS SKILL" matrix opens the body; explicitly excludes cluster sizing (deferred to `kafka-strimzi-operator`), Kafka deployment itself (deferred to `addons-and-building-blocks`), and broker-vs-alternative-broker comparisons (out of scope).
- Anti-patterns table maps each violation to "what breaks in interpretation" (laptop runs bake network skew, `if (__VU == 0)` races, `--throughput -1` without a baseline, perf-test.sh on app pipelines mislabels app saturation as broker saturation).

## Dependencies

### Internal
- `../../README.md` — references this skill in the "Platform Engineering" table.
- `../../scripts/validate-skills.sh` — validates this file (its `DOMAIN_DIRS` includes `platform-engineering/`); CI runs it on every push and PR.
- `../kafka-strimzi-operator/SKILL.md` — sibling whose `BrokerCapacity` + `KafkaNodePool` decisions govern the ceiling this skill measures.
- `../addons-and-building-blocks/SKILL.md` — sibling that ships Kafka itself + the `testing-system` namespace where this skill's `Job` runs.

### External
None at runtime — this is documentation, not code.

<!-- MANUAL: -->
