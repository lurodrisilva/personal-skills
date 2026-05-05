<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-05-04 | Updated: 2026-05-04 -->

# kafka-strimzi-operator

## Purpose
Skill that guides authoring, reviewing, deploying, sizing, tuning, and **performance-testing** Apache Kafka on Kubernetes via the **Strimzi operator**. Encodes the KRaft-only mental model (no ZooKeeper, controller + broker `KafkaNodePool` role split), the exact `BrokerCapacity` API contract (`cpu` / `inboundNetwork` / `outboundNetwork` regex patterns and `overrides` schema), the `cruiseControl.brokerCapacity` ⇔ `KafkaNodePool.spec.resources.limits` 1:1 mirroring rule, listener selection during synthetic load (in-cluster `internal` + plaintext for the headline run; TLS/SCRAM measured separately), perf-grade storage choices (`persistent-claim` / `jbod` on Premium SSD v2 / gp3 / hyperdisk), Cruise Control optimisation goals + `KafkaRebalance` modes, `KafkaTopic` / `KafkaUser` / quotas, and the **60–80% saturation-band tier ladder** (Bronze → Platinum+) applied to Kafka's four limiting resources (CPU, network-in, network-out, log disk). Also covers `hex-scaffold` Kafka inbound (`Adapters.Inbound` `BackgroundService` consumer) and outbound (`Adapters.Outbound` `Confluent.Kafka` producer) integration for perf hardening.

## Key Files
| File | Description |
|------|-------------|
| `SKILL.md` | The skill definition — `name: kafka-strimzi-operator`, `domain: platform-engineering`, `pattern: managed-kafka-on-kubernetes`, `stack: strimzi + kafka + cruise-control + kraft`, `use_cases: load-testing, performance-engineering, capacity-planning` |

## Subdirectories
None.

## For AI Agents

### Working In This Directory
- Edit `SKILL.md` only.
- The 12 non-negotiables at the top of the body are flag-first rules in PR review. Particular load-bearers: KRaft-only with disjoint `[controller]` / `[broker]` `KafkaNodePool`s (#1), three controllers always (#2), `cruiseControl.brokerCapacity.cpu` == `KafkaNodePool.spec.resources.limits.cpu` (#3), `internal` + `tls: false` for headline perf runs (#4), perf-grade NVMe `storageClass` (#5), `spec.kafka.rack.topologyKey` on multi-zone clusters (#6), per-pool hard pod anti-affinity (#7), **quotas off during synthetic perf** (#8), unidirectional Topic Operator as the source of truth (#9), four headline Grafana panels live before firing k6 (#10), Drain Cleaner + PDB `maxUnavailable: 1` (#11), Cluster Operator HA replicas ≥ 2 (#12).
- The `BrokerCapacity` schema section is **API-verbatim** — `cpu` matches `^[0-9]+([.][0-9]{0,3}|[m]?)$`, `inboundNetwork` / `outboundNetwork` match `^[0-9]+([KMG]i?)?B/s$`, `overrides[].brokers` is `List<Integer>`, and the current API does **not** carry `disk` or `cpuUtilization` (gone — disk reads from PVC, CPU from `resources`). Earlier docs that claim otherwise are stale; do not "fix" the skill back to them.
- The naming-asymmetry trap is intentional: `cruiseControl.config.{hard.goals,goals,default.goals}` expects **fully-qualified class names**, while `KafkaRebalance.spec.goals` accepts **short names**. The body calls this out — keep the warning when editing examples.
- The Bronze / Silver / Gold / Platinum / Platinum+ ladder mirrors this account's PostgreSQL ladder doctrine. If the PG ladder shifts (`azure-pg-flex` skill), keep step ratios consistent here so cross-engine ranking remains comparable.
- The `description:` field is intentionally exhaustive (auto-detection trigger surface — phrases, file patterns, k6 / `hex-scaffold` cues). When extending coverage, extend the description's trigger list to match.

### Testing Requirements
- **`scripts/validate-skills.sh` does NOT walk this directory** — the validator is hardcoded to `coding/`. After editing, manually verify per the parent skill's three checks:
  1. YAML frontmatter parses and contains `name`, `description`, `license`, `compatibility`, non-empty `metadata` map.
  2. Markdown body after the closing `---` is non-empty.
  3. Fenced code-block markers are even in count (this file is large; an unclosed fence inside the perf playbook is the most likely regression).
- The skill's own examples must satisfy its own non-negotiables — every YAML snippet should keep KRaft annotations, role-split node pools, `requests == limits`, `-Xms == -Xmx ≤ 50% memory`, hard pod anti-affinity, rack awareness, and `cruiseControl.brokerCapacity` mirroring `resources.limits`.

### Common Patterns
- "Non-negotiables encoded in this skill" numbered list — same authoring style as `addons-and-building-blocks`, `wiremock-api-mocks`, `github-actions`.
- "WHEN TO USE THIS SKILL" matrix opens the body and explicitly excludes vanilla Kafka outside Kubernetes (Confluent Cloud / MSK / on-prem ZK), ZooKeeper-mode Strimzi 0.45 or older, client-library / codec optimisation, and Kafka-vs-Pulsar/Redpanda strategy calls.
- Anti-patterns table near the end maps each violation to a one-line "why it breaks the perf result or the cluster" — keep this format when extending.
- Pre-done verification checklist is partitioned by surface (operator surface / `Kafka` CR / controllers / brokers / topics & users / observability / pre-test / result) — one box per surface, every box must check before declaring a tier-ladder data point reportable.

## Dependencies

### Internal
- `../../README.md` — references this skill in the "Platform Engineering" table when listed; rename → README update required.
- `../../scripts/validate-skills.sh` — *currently does not validate this file*; expanding the validator is a tracked follow-up (`CLAUDE.md`).
- `../addons-and-building-blocks/SKILL.md` — parent platform-blueprint skill. The Strimzi Cluster Operator is delivered as a baseline addon under that blueprint (Helm OCI chart, sync wave 2 — after CRDs, before `Kafka` CRs); rules in this skill must not contradict the parent's layer-cake / OCI / four-tier-gate doctrine.
- `../azure-pg-flex/SKILL.md` — sibling skill that established the 60–80% saturation-band + double-per-step tier-ladder methodology. This skill applies the same doctrine to Kafka's four limiting resources so cross-engine bottleneck rankings stay comparable.

### External
None at runtime — this is documentation, not code. The skill *describes* Strimzi 0.46+ / Kafka 4.0+ / Cruise Control / Drain Cleaner / `xk6-kafka` / `Confluent.Kafka` but does not depend on them being installed.

<!-- MANUAL: -->
