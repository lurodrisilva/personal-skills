---
name: kafka-load-test
description: MUST USE when authoring, reviewing, sizing, running, or interpreting **load tests against Apache Kafka or any service whose ingress/egress is Kafka** — covers the **two complementary tools** of the trade (`kafka-producer-perf-test.sh` / `kafka-consumer-perf-test.sh` for raw broker baselines; `k6 + xk6-kafka` for application-pipeline tests that drive the consumer/producer adapters end-to-end), the v2 xk6-kafka API surface (`Producer`, `Consumer`, `AdminClient`, `SchemaRegistry`), the **CGO build paths** (local `xk6 build` with `librdkafka`, `grafana/xk6` Docker builder, `mostafamoradian/xk6-kafka` pre-built image), the **k6 test lifecycle** (`init` / `setup` / `default` / `teardown`) and the **topic-creation race** (NEVER `if (__VU == 0)` at module scope — always `setup()` with a fresh `AdminClient` then `sleep(2)` for metadata propagation, OR `autoCreateTopic: true`), `ramping-arrival-rate` scenario shapes, the v2-emitted-but-v1-named metrics (`kafka_writer_*`, `kafka_reader_*`) and how to bind k6 thresholds to them, the **sizing knobs that must be fixed before every run** (message size, target rate, ramp profile, partitions, producer `acks`/`linger.ms`/`batch.size`/`compression.type`, duration ≥10 min, 30–60 s warmup discard), the **four-quadrant watch list** (producer-side `record-send-rate` / `request-latency-p99` / `record-error-rate`; broker-side `BytesInPerSec` / `RequestHandlerAvgIdlePercent` / `UnderReplicatedPartitions`; consumer-side per-partition lag / `records-consumed-rate` / handler processing-time; app-side HTTP/handler p99, DB pool waits, GC), the **stop conditions** (any-of: error rate > SLO, p99 > SLO, monotonic lag growth >2 min, `RequestHandlerAvgIdlePercent` < 20%), the **in-cluster `Job` execution pattern** (run from a dedicated namespace such as `testing-system` to eliminate ingress/network skew), and **post-run cleanup** (delete the load topic or `kafka-delete-records.sh`-truncate, reset consumer-group offsets, drop synthetic rows the handler wrote). Also encodes the **tool-selection matrix** ("perf-test.sh answers *is the broker healthy*; xk6-kafka answers *is the service healthy under Kafka load*") and the canonical **two-pass methodology**: (1) one-time `perf-test.sh` baseline whenever brokers, partitions, `KafkaNodePool`, or replication factor change — to prove the broker isn't the bottleneck; (2) repeated `xk6-kafka` runs as the headline test against the application pipeline. Triggers on phrases — "load test kafka", "kafka perf test", "kafka throughput", "kafka p99 latency", "consumer lag under load", "producer backpressure", "size kafka brokers", "find broker ceiling", "drive inbound kafka adapter", "k6 kafka", "xk6-kafka", "kafka-producer-perf-test", "kafka-consumer-perf-test", "ramping arrival rate kafka", "ramp up kafka producer", "kafka_writer_message_count threshold", "kafka_reader_error_count threshold", "build xk6 with kafka", "lensesio fast-data-dev", "schema registry load test", "avro load test", "tier ladder kafka", "Hex.Scaffold kafka load", "Adapters.Inbound consumer load", "Adapters.Outbound producer load". Triggers on file patterns — `**/k6/**/*.js`, `**/loadtest/**/*kafka*`, `**/perf/**/*kafka*`, `**/xk6-kafka*`, `**/test_*_kafka.js`, `**/kafka-perf-test*.sh`, `**/Job*kafka*load*.yaml`, `**/values-loadtest-kafka*.yaml`. Authored from the perspective of a **platform-engineer-meets-perf-engineer** — emphasises **paired-tool methodology, in-cluster execution to eliminate network skew, fixed sizing knobs before every run, and the four-quadrant watch list so you can name *which* resource saturated first instead of just reporting "it broke"**. Sister skill to `kafka-strimzi-operator` (cluster sizing) and `addons-and-building-blocks` (deployment via App-of-Apps).
license: BSD-3-Clause
compatibility: opencode
metadata:
  domain: platform-engineering
  pattern: load-testing-kafka-and-kafka-driven-services
  platform: kubernetes
  stack: k6 + xk6-kafka + kafka-perf-test + strimzi
  cloud: any (aks/eks/gke/openshift/local)
  use_cases: load-testing, performance-engineering, capacity-planning, sla-verification
  sister_skills: kafka-strimzi-operator, addons-and-building-blocks
---

# Kafka Load Testing — Two Tools, One Methodology

You are a **performance engineer** running load tests against **Apache Kafka** and **services whose ingress/egress is Kafka**. Your job is to produce defensible numbers — not "we hit X msg/s once" but **"X msg/s is the ceiling, and the limiting resource is Y, here is the evidence trail"** — and to do so without conflating broker bottlenecks with application bottlenecks.

This skill encodes the **paired-tool methodology** that makes Kafka load tests trustworthy: a one-time **broker baseline** with the bundled `kafka-producer-perf-test.sh` / `kafka-consumer-perf-test.sh` (proves the broker isn't the limit), then **headline tests** with `k6 + xk6-kafka` driving the application's actual inbound/outbound Kafka adapters under realistic, scripted load with thresholds and CI integration.

**Non-negotiables encoded in this skill:**

1. **Pick the right tool for the question.** `kafka-producer/consumer-perf-test.sh` measures **the broker**; `xk6-kafka` measures **your service driven through Kafka**. Using `perf-test.sh` to validate an application pipeline is a category error — it sends opaque bytes, has no schema, no scenario shape, no thresholds, and its only output is a stdout summary.
2. **Run the broker baseline first when broker shape changes.** Whenever you touch broker count, `KafkaNodePool` resources, partition count, replication factor, or `cruiseControl.brokerCapacity`, run `kafka-producer-perf-test.sh` once with `--throughput -1` to establish the new ceiling. If the headline xk6 test later saturates well below that ceiling, the bottleneck is in the app or DB — not Kafka. Without this baseline, every saturation conversation devolves into finger-pointing.
3. **Fix every sizing knob before the run, in writing.** Message size, target rate, ramp profile, partition count, producer `acks` / `linger.ms` / `batch.size` / `compression.type`, duration (≥10 min for steady state — long enough to cross at least one segment roll and one GC cycle), warmup window (30–60 s discarded). A run with floating knobs is a benchmark you can't reproduce.
4. **Run inside the cluster.** k6 / perf-test pods MUST run as a `Job` in a dedicated namespace (e.g. `testing-system`) talking to the in-cluster bootstrap `Service` (`<cluster>-kafka-bootstrap.<ns>.svc:9092`). Driving from a laptop, a CI runner, or across an ingress LB introduces network skew and TLS-termination overhead that the perf number then bakes in forever.
5. **Use the v2 xk6-kafka API.** `Producer`, `Consumer`, `AdminClient`, `SchemaRegistry`. The v1 names (`Writer`, `Reader`, `Connection`) and the module-level `writer()` / `reader()` / `createTopic()` functions still work as deprecated aliases — the older Grafana blog post uses them, **don't** copy that verbatim. v2 is roughly 3.3× faster on the bundled JSON benchmark (≈383k msg/s vs ≈115k msg/s with 50 VUs).
6. **Create topics in `setup()`, never with `if (__VU == 0)` at module scope.** The `if (__VU == 0)` pattern is a race: VU 1+ start producing before VU 0 finishes the topic. Always either (a) create a fresh `AdminClient` *inside* `setup()`, call `createTopic()`, verify with `listTopics()`, `close()`, then `sleep(2)` for metadata to propagate, or (b) set `autoCreateTopic: true` on the `Producer` config (and accept default partitioning).
7. **Bind k6 thresholds to the v2-emitted-v1-named metrics.** v2 keeps emitting `kafka_writer_*` / `kafka_reader_*` for dashboard and threshold compatibility. Thresholds turn the run into a pass/fail CI artifact (k6 exits non-zero on breach) — without them, you're collecting numbers, not running a test.
8. **Watch all four quadrants — producer, broker, consumer, app — in one Grafana view.** A perf test that only watches one quadrant cannot name the limiting resource. The four panels at minimum: producer `request-latency-p99`, broker `RequestHandlerAvgIdlePercent`, consumer-group lag per partition, app handler p99. Anything else is decoration.
9. **Stop on the first SLO breach, not on time.** End the run when **any** of: error rate > target SLO, p99 latency > SLO, consumer lag grows monotonically for >2 min, broker `RequestHandlerAvgIdlePercent` < 20%. The duration knob is a *cap*, not the trigger — the trigger is saturation. Record which condition fired first; that's the answer.
10. **Clean up every run.** Delete the load topic (or `kafka-delete-records.sh` to truncate), reset the consumer-group offsets if you reused them (`kafka-consumer-groups.sh --reset-offsets --to-earliest`), and drop any synthetic rows the handler wrote to the application database. Synthetic data left behind contaminates the next run's measurements (cache states, query plans, partition skew).
11. **Build xk6-kafka with CGO — there's no way around it.** v2 uses `confluent-kafka-go` / `librdkafka`. Three viable paths: local `CGO_ENABLED=1 xk6 build --with github.com/mostafa/xk6-kafka/v2@latest`, the `grafana/xk6` Docker builder (no local CGO toolchain needed), or the pre-built `mostafamoradian/xk6-kafka:latest` image (no build at all). On macOS the local path needs Xcode CLI tools and possibly `brew install pkg-config librdkafka`.
12. **Quotas OFF during synthetic perf tests.** `KafkaUser.spec.quotas` (`producerByteRate`, `consumerByteRate`, `requestPercentage`, `controllerMutationRate`) are production safety belts, not perf knobs. If the run is throttled by a quota, the headline number is the quota, not the system. Re-enable per tenant *after* the headline numbers are established.

If a load-test setup, k6 script, or perf-test invocation under review violates any of these, **flag them first** before any other comment.

---

## WHEN TO USE THIS SKILL

| Scenario | Use this skill? |
|----------|-----------------|
| Authoring a k6 script with `xk6-kafka` to drive an application's inbound Kafka adapter | **Yes** |
| Establishing a one-time broker ceiling with `kafka-producer-perf-test.sh` after a `KafkaNodePool` change | **Yes** |
| Choosing between perf-test.sh and xk6-kafka for a specific question | **Yes** |
| Sizing the message rate / partition count / VU count for a planned run | **Yes** |
| Picking producer `acks` / `linger.ms` / `batch.size` / `compression.type` for the test workload | **Yes** |
| Wiring k6 thresholds on `kafka_writer_*` / `kafka_reader_*` metrics into CI | **Yes** |
| Writing a `Job` manifest that runs k6 from `testing-system` against the in-cluster bootstrap `Service` | **Yes** |
| Designing a `ramping-arrival-rate` scenario with a defensible warmup and stop condition | **Yes** |
| Naming the limiting resource (CPU / network-in / network-out / log disk / DB pool / GC) from a run's metrics | **Yes** |
| Driving a hexagonal-architecture .NET / Go / JVM / Node service end-to-end through its Kafka inbound adapter | **Yes** |
| Producing Avro / JSON Schema / Protobuf payloads against a live Schema Registry | **Yes** |
| Investigating "the producer reported success but the consumer is behind" symptoms | **Yes** |
| Deciding whether a run's ceiling is broker-side or app-side | **Yes** |
| Cluster sizing decisions (broker count, JVM heap, NIC class, storage class) | **No** — that's `kafka-strimzi-operator` |
| Deploying Kafka itself via App-of-Apps / Helm addon | **No** — that's `addons-and-building-blocks` |
| Comparing Kafka vs Pulsar vs Redpanda vs RabbitMQ | **No** — strategy / architecture call, out of scope |
| Debugging a Kafka client library bug (Confluent.Kafka, kafka-go, kafkajs) | **No** — application concern, escalate to library docs |

---

## TOOL SELECTION — THE ONE-PAGE MATRIX

| Dimension | `kafka-producer-perf-test.sh` / `kafka-consumer-perf-test.sh` | `k6 + xk6-kafka` |
|---|---|---|
| **What it measures** | Raw broker throughput / latency at the wire | End-to-end behaviour of *your service* driven through Kafka |
| **Payload realism** | Random bytes, fixed size, no schema | Domain-shaped JSON / Avro / JSON Schema / Protobuf |
| **Workload shape** | Single rate, single message size, no ramp | `constant-arrival-rate`, `ramping-arrival-rate`, `ramping-vus`, multi-stage |
| **Assertions** | None — stdout summary only | `check()` per-iteration + thresholds → exit code |
| **Mixed protocols** | Kafka only | Kafka + HTTP + gRPC in the same run |
| **Schema Registry** | No | Yes — built-in `SchemaRegistry` (gzip-compressed payloads OK) |
| **Auth** | SASL/SSL via JAAS configs | SASL PLAIN/SCRAM, SSL, AWS IAM, Azure Entra (Event Hub), JKS |
| **Compression** | gzip / snappy / lz4 / zstd | gzip / snappy / lz4 / zstd |
| **Metrics output** | Stdout summary (msg/s, MB/s, p50/p95/p99) | Per-VU metrics → Prometheus / InfluxDB / CSV / JSON / stdout; Grafana dashboards |
| **Setup cost** | Zero — ships with every Kafka distribution | Build a custom k6 binary (CGO + librdkafka) **or** use the Docker image |
| **CI fit** | Awkward — parse stdout | Native — thresholds → non-zero exit |
| **Best for** | Smoke-testing the broker, validating a `KafkaNodePool` / partition / RF change, proving the broker isn't the bottleneck | Validating the **app pipeline** (inbound consumer → handlers → DB → outbound producer), tier-ladder runs, SLA verification |
| **Worst for** | Anything beyond raw broker numbers | Tiny one-off broker smoke tests (overkill) |

**Mental model:** *perf-test.sh answers "is my Kafka cluster healthy"; xk6-kafka answers "is my service healthy under Kafka load."*

---

## CANONICAL TWO-PASS METHODOLOGY

```
┌──────────────────────────────────────────────────────────────────┐
│  PASS 1 — BROKER BASELINE  (run once per broker-shape change)    │
│                                                                  │
│  Tool:    kafka-producer-perf-test.sh + kafka-consumer-perf-test │
│  Goal:    Establish the BROKER ceiling on the current cluster    │
│  Output:  msg/s, MB/s, p99 latency at saturation                 │
│  Trigger: Any change to broker count, KafkaNodePool resources,   │
│           partition count, RF, cruiseControl.brokerCapacity      │
│           — or before the FIRST tier-ladder run on a new env     │
└──────────────────────────────────────────────────────────────────┘
                              │
                              │  baseline number recorded
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│  PASS 2 — APPLICATION HEADLINE  (run every test cycle)           │
│                                                                  │
│  Tool:    k6 + xk6-kafka                                         │
│  Goal:    Drive the SERVICE pipeline end-to-end through Kafka    │
│  Output:  Per-VU metrics + 4-quadrant Grafana view +             │
│           pass/fail via k6 thresholds                            │
│  Trigger: Every release candidate, every tier-ladder rung,       │
│           every SLA verification, every regression hunt          │
└──────────────────────────────────────────────────────────────────┘
                              │
                              │  if PASS 2 saturates well below PASS 1's
                              │  ceiling → bottleneck is app/DB, not Kafka
                              ▼
                     NAME THE LIMITING RESOURCE
                     (CPU / net-in / net-out / log disk /
                      DB pool / GC / handler latency)
```

---

## PASS 1 — BROKER BASELINE  (`kafka-producer-perf-test.sh`)

### Producer baseline

```bash
kafka-producer-perf-test.sh \
  --topic perf-baseline \
  --num-records 10000000 \
  --record-size 1024 \
  --throughput -1 \
  --producer-props \
      bootstrap.servers=<cluster>-kafka-bootstrap.<ns>.svc:9092 \
      acks=1 \
      linger.ms=5 \
      batch.size=65536 \
      compression.type=lz4
```

| Knob | Why |
|---|---|
| `--throughput -1` | Unbounded — measures the **ceiling**, not a target. For SLA verification use a positive number matching production. |
| `--num-records` | Long enough to cross at least one segment roll (~1 GB by default) and warm caches. 10 M × 1 KiB ≈ 10 GiB. |
| `--record-size` | **Match production payload size.** Wrong size invalidates everything downstream. |
| `acks=1` | Match what production producers use. `acks=all` triples broker work; `acks=0` undermeasures latency. |
| `compression.type` | Match production. Compression hides on the wire and shows up as broker CPU. |

### Consumer baseline

```bash
kafka-consumer-perf-test.sh \
  --bootstrap-server <cluster>-kafka-bootstrap.<ns>.svc:9092 \
  --topic perf-baseline \
  --messages 10000000 \
  --threads 1 \
  --reporting-interval 5000 \
  --show-detailed-stats
```

### What to record

- `records/sec`, `MB/sec`, `p50/p95/p99` produce latency from the producer run.
- `MB.sec`, `nMsg.sec` from the consumer run.
- The four broker JMX panels (CPU per broker, BytesInPerSec per broker, BytesOutPerSec per broker, log-flush p99) from Prometheus during both runs.

This becomes the **broker ceiling** referenced by every subsequent xk6-kafka result.

---

## PASS 2 — APPLICATION HEADLINE  (`k6 + xk6-kafka`)

### Build the k6 binary

Three paths — pick one and stick with it for the lifetime of the test rig.

| Path | Command | When to use |
|---|---|---|
| **Local CGO** | `CGO_ENABLED=1 xk6 build --with github.com/mostafa/xk6-kafka/v2@latest` | Dev laptop, repeatable iteration, you want to add other extensions |
| **Docker builder** | `docker run --rm -e GOOS=linux -u "$(id -u):$(id -g)" -v "$PWD:/xk6" grafana/xk6 build --with github.com/mostafa/xk6-kafka/v2@latest` | CI / no local CGO toolchain; on macOS add `-e GOOS=darwin` |
| **Pre-built image** | `docker run --rm -i mostafamoradian/xk6-kafka:latest run - < script.js` | One-off run, no script bundling needed |

> **Note:** Go modules require the `/v2` import path for major version 2+. Use `github.com/mostafa/xk6-kafka/v2@…` for `v2.x.x` tags and `github.com/mostafa/xk6-kafka@…` only for `v1.x.x` and earlier.

### v2 API surface

```js
import { Producer, Consumer, AdminClient, SchemaRegistry, SCHEMA_TYPE_STRING } from "k6/x/kafka";
import { sleep, check } from "k6";

export const options = {
  scenarios: {
    ramp_to_target: {
      executor: "ramping-arrival-rate",
      startRate: 100,
      timeUnit: "1s",
      preAllocatedVUs: 50,
      maxVUs: 200,
      stages: [
        { duration: "1m",  target: 1000 },   // warmup
        { duration: "5m",  target: 5000 },   // ramp
        { duration: "10m", target: 5000 },   // steady state
        { duration: "1m",  target: 0    },   // cool down
      ],
    },
  },
  thresholds: {
    kafka_writer_error_count:   ["count==0"],
    kafka_writer_message_count: ["count>1000000"],
    "kafka_writer_request_latency_ms{quantile=\"p(99)\"}": ["value<50"],
  },
  discardResponseBodies: true,
};

const BROKERS = ["my-cluster-kafka-bootstrap.kafka.svc:9092"];
const TOPIC   = "perf-app-pipeline";

const producer = new Producer({
  brokers: BROKERS,
  topic:   TOPIC,
  // autoCreateTopic: true,   // alternative to setup()-based creation
});

const sr = new SchemaRegistry({ url: "http://schema-registry.kafka.svc:8081" });

export function setup() {
  // Create a fresh AdminClient INSIDE setup() — never share one from init.
  const admin = new AdminClient({ brokers: BROKERS });
  admin.createTopic({
    topic:             TOPIC,
    numPartitions:     12,
    replicationFactor: 3,
  });

  if (!admin.listTopics().some(t => t.topic === TOPIC)) {
    throw new Error(`topic ${TOPIC} was not created`);
  }
  admin.close();

  // Let metadata propagate to all brokers BEFORE VUs start producing.
  sleep(2);
}

export default function () {
  const id = `acct_${__VU}_${__ITER}`;
  producer.produce({
    messages: [{
      key:   sr.serialize({ data: id,                  schemaType: SCHEMA_TYPE_STRING }),
      value: sr.serialize({ data: JSON.stringify({
        id,
        type: "account.created",
        ts:   Date.now(),
        // ... domain-shaped payload matching the real producer ...
      }), schemaType: SCHEMA_TYPE_STRING }),
    }],
  });
}

export function teardown() {
  producer.close();
  // Optional: delete the topic via a fresh AdminClient
  const admin = new AdminClient({ brokers: BROKERS });
  admin.deleteTopic(TOPIC);
  admin.close();
}
```

### Lifecycle — the topic-creation race

```
┌─────────────────────────────────────────────────────────────────┐
│  init (module top-level)                                        │
│  • Instantiate Producer / Consumer / SchemaRegistry             │
│  • Define `export const options`                                │
│  • DO NOT instantiate AdminClient here for topic creation       │
│  • DO NOT use `if (__VU == 0) { admin.createTopic(...) }`       │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  setup()  (runs ONCE before any VU)                             │
│  • Instantiate a fresh AdminClient HERE                         │
│  • createTopic({ topic, numPartitions, replicationFactor })     │
│  • Verify with listTopics()                                     │
│  • admin.close()                                                │
│  • sleep(2)  ← let metadata propagate to all brokers            │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  default()  (runs per VU per iteration)                         │
│  • producer.produce({ messages: [...] })                        │
│  • OR consumer.consume({ maxMessages: N })  (debug only)        │
│  • check() / metrics                                            │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  teardown()  (runs ONCE after all VUs)                          │
│  • producer.close() / consumer.close()                          │
│  • Optional: deleteTopic via a fresh AdminClient                │
└─────────────────────────────────────────────────────────────────┘
```

> **Alternative (acceptable):** set `autoCreateTopic: true` on the `Producer` config. You give up control of partition count and replication factor in exchange for skipping `setup()`-based creation.

### Emitted metrics — bind thresholds to these

v2 keeps the v1 metric names for dashboard and threshold compatibility.

**Writer (`Producer`)**

| Metric | Type | Use in threshold |
|---|---|---|
| `kafka_writer_dial_count`              | Counter | Connection churn — should plateau quickly |
| `kafka_writer_error_count`             | Counter | `count==0` is the headline pass condition |
| `kafka_writer_message_bytes`           | Counter | Throughput in bytes/sec |
| `kafka_writer_message_count`           | Counter | Total produced — set a floor for "test actually ran" |
| `kafka_writer_write_count`             | Counter | Batched write operations |
| `kafka_writer_request_latency_ms`      | Trend   | Bind p99 to your SLO (`value<50`) |

**Reader (`Consumer`, debug-mode only)**

| Metric | Type | Use in threshold |
|---|---|---|
| `kafka_reader_dial_count`     | Counter | |
| `kafka_reader_error_count`    | Counter | `count==0` |
| `kafka_reader_message_bytes`  | Counter | |
| `kafka_reader_message_count`  | Counter | Floor for "consumer actually drained" |
| `kafka_reader_fetches_count`  | Counter | |
| `kafka_reader_timeouts_count` | Counter | `count==0` |

### Run from a `Job` in `testing-system`

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: kafka-loadtest-headline
  namespace: testing-system
spec:
  backoffLimit: 0
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: k6
          image: mostafamoradian/xk6-kafka:latest
          args:
            - run
            - --out=experimental-prometheus-rw=http://prometheus.monitoring.svc:9090/api/v1/write
            - --tag=test=headline-run
            - /scripts/headline.js
          volumeMounts:
            - { name: scripts, mountPath: /scripts }
          resources:
            requests: { cpu: "2",   memory: "2Gi" }
            limits:   { cpu: "4",   memory: "4Gi" }
      volumes:
        - name: scripts
          configMap:
            name: kafka-loadtest-scripts
```

**Why a `Job` in `testing-system`:** isolates the load generator from production workloads, eliminates ingress / LoadBalancer / TLS-termination skew that would otherwise contaminate the latency numbers, and keeps the synthetic traffic on the same pod network the real consumers use. **Never** drive headline runs from a laptop.

---

## SIZING KNOBS — FIX BEFORE EVERY RUN

| Knob | Question it answers | Default starting point |
|---|---|---|
| **Message size (bytes)** | Match production payload | Whatever your real producer emits — measure it |
| **Target rate (msg/s)** | Headline number you want to validate | Start at 1× current production peak; ramp from there |
| **Ramp profile** | Step / linear / spike / soak | `ramping-arrival-rate` linear unless investigating burst behaviour |
| **Partitions** | Bounds consumer concurrency | ≥ consumer-pod count × consumer threads per pod |
| **Producer `acks`** | Match production durability | `acks=1` typical; `acks=all` for "what if we tighten durability" |
| **Producer `linger.ms`** | Batch-fill window | `5–10` ms typical; `0` for latency-sensitive |
| **Producer `batch.size`** | Bytes per batch | `16384` default; `65536`+ for high throughput |
| **Producer `compression.type`** | Wire bytes vs broker CPU tradeoff | `lz4` typical; `zstd` for max ratio; `none` for max latency |
| **Duration** | Long enough to cross segment roll + GC | **≥10 min steady state** |
| **Warmup** | Discard the first N seconds | 30–60 s discarded |

---

## FOUR-QUADRANT WATCH LIST

```
┌────────────────────────────┬────────────────────────────────────┐
│  PRODUCER SIDE  (k6)       │  BROKER SIDE  (Strimzi JMX)        │
│  • record-send-rate        │  • BytesInPerSec per broker        │
│  • request-latency-p99     │  • RequestHandlerAvgIdlePercent    │
│  • record-error-rate       │  • UnderReplicatedPartitions       │
│                            │  • Log-flush p99                    │
├────────────────────────────┼────────────────────────────────────┤
│  CONSUMER SIDE             │  APP SIDE  (your service)          │
│  • lag per partition       │  • HTTP / handler p99              │
│  • records-consumed-rate   │  • DB connection-pool waits        │
│  • handler processing time │  • GC pauses, allocation rate      │
│  • rebalance count         │  • Outbound publish backpressure   │
└────────────────────────────┴────────────────────────────────────┘
```

A perf test that doesn't chart all four quadrants in **one** Grafana view cannot name the limiting resource. The four panels above are the **minimum** — anything else is decoration.

**Saturation thresholds (heuristics, not absolutes):**

| Resource | "Saturated" indicator |
|---|---|
| Broker CPU | `RequestHandlerAvgIdlePercent` < 30% (warn), < 20% (saturated) |
| Broker network | `BytesInPerSec` (or out) > 70% of NIC class limit |
| Broker log disk | log-flush p99 > 50 ms or `UnderReplicatedPartitions` > 0 |
| Consumer | per-partition lag grows monotonically for >2 min |
| App CPU | container CPU > 80% sustained |
| App DB pool | connection-pool wait time > 0 sustained |

---

## STOP CONDITIONS — END THE RUN ON FIRST BREACH

End the run when **any** of:

1. **Error rate > target SLO** (e.g. `kafka_writer_error_count > 0` for a zero-error SLO).
2. **p99 latency > SLO** (producer request-latency p99 OR app handler p99).
3. **Consumer lag grows monotonically for >2 min** (the consumer is permanently behind, not just bursty).
4. **Broker `RequestHandlerAvgIdlePercent` < 20%** (broker CPU starvation).

Record **which** condition fired first — that's the answer to "what's the limiting resource". The duration knob in `options.scenarios` is a **cap**, not the trigger.

---

## CLEANUP — EVERY RUN, NO EXCEPTIONS

1. **Delete the load topic** via `AdminClient.deleteTopic()` in `teardown()`, or `kafka-topics.sh --delete --topic <name>`. If you want to keep partition layout but drop data, use `kafka-delete-records.sh`.
2. **Reset consumer-group offsets** if the test reused a real group:
   ```bash
   kafka-consumer-groups.sh --bootstrap-server ... \
     --group <group> --reset-offsets --to-earliest --execute --all-topics
   ```
3. **Drop synthetic rows** the handler wrote to the application DB — typically a `DELETE FROM <table> WHERE id LIKE 'acct_%_%'` matching the synthetic ID pattern from `default()`.
4. **Tear down Schema Registry subjects** if the run registered new schema versions you don't want to keep:
   ```bash
   curl -X DELETE http://schema-registry.../subjects/<topic>-value
   ```

Synthetic data left behind contaminates the next run — cache states, query plans, partition skew, and JIT-warmed paths all carry over.

---

## LOCAL DEV ENVIRONMENT  (`lensesio/fast-data-dev`)

For iterating on the script before targeting a real cluster:

```bash
docker run -d --rm --name fast-data-dev \
  -p 2181:2181 -p 3030:3030 -p 8081-8083:8081-8083 \
  -p 9581-9585:9581-9585 -p 9092:9092 \
  -e ADV_HOST=127.0.0.1 -e RUN_TESTS=0 \
  lensesio/fast-data-dev:latest
```

Bundles Kafka + Zookeeper + Schema Registry + Kafka Connect + UI on `http://localhost:3030`. Point `BROKERS = ["localhost:9092"]` and `SchemaRegistry({ url: "http://localhost:8081" })`.

---

## COMMON TRIGGERS — PHRASES THAT SHOULD LOAD THIS SKILL

- "load test kafka"
- "kafka perf test" / "kafka perf testing"
- "kafka throughput" / "find the kafka ceiling"
- "kafka p99 latency under load"
- "consumer lag under load" / "producer backpressure"
- "drive the inbound kafka adapter"
- "k6 kafka" / "xk6-kafka" / "build xk6 with kafka"
- "kafka-producer-perf-test" / "kafka-consumer-perf-test"
- "ramping arrival rate kafka" / "ramp up kafka producer"
- "kafka_writer_message_count threshold" / "kafka_reader_error_count threshold"
- "lensesio fast-data-dev"
- "schema registry load test" / "avro load test"
- "tier ladder kafka"
- "Hex.Scaffold kafka load" / "Adapters.Inbound consumer load" / "Adapters.Outbound producer load"

---

## ANTI-PATTERNS

| Anti-pattern | Why it's wrong | Fix |
|---|---|---|
| Using `kafka-producer-perf-test.sh` to validate an application pipeline | It tests the broker, not your service. Sends opaque bytes. No assertions. | Use `xk6-kafka` for the app pipeline; keep perf-test.sh for broker baseline only |
| `if (__VU == 0) { admin.createTopic(...) }` at module scope | Race — VU 1+ produce before VU 0 finishes topic creation | Move to `setup()` with a fresh `AdminClient` + `sleep(2)`, or use `autoCreateTopic: true` |
| Sharing the `init`-scoped `AdminClient` inside `setup()` | Confluent client state isn't safe across the boundary | Instantiate a **fresh** `AdminClient` inside `setup()`, `close()` it before returning |
| Driving headline runs from a laptop or CI runner outside the cluster | Network skew, TLS-termination overhead, ingress LB hops contaminate latency numbers | `Job` in a dedicated namespace (`testing-system`) talking to in-cluster bootstrap `Service` |
| No warmup window | First 30–60 s of metrics are JIT-warmup / cache-cold / connection-establish noise | Discard via scenario stages or post-process to skip the warmup duration |
| Test duration < 10 min | Doesn't cross a segment roll or a GC cycle — measures transient state | ≥10 min steady state |
| Floating sizing knobs between runs | Result isn't reproducible; can't compare runs | Pin every knob in the script header as comments + commit the script |
| Running with quotas enabled | Headline number is the quota, not the system | Disable `KafkaUser.spec.quotas` for synthetic perf tests; re-enable post-run |
| No thresholds | k6 always exits 0 → CI can't fail → no regression detection | Bind thresholds to `kafka_writer_*` / `kafka_reader_*` metrics + app SLOs |
| Watching only one quadrant (e.g. "throughput hit X") | Can't name the limiting resource | Four-quadrant Grafana view: producer + broker + consumer + app |
| Reusing the load topic across runs without cleanup | Stale data + warm caches + partition skew contaminate next run | Delete topic + reset offsets + drop synthetic rows in `teardown()` |
| Using v1 API (`writer()` / `reader()` / module-level helpers) for new scripts | Deprecated; v2 is ~3.3× faster on the bundled JSON benchmark | v2 constructors: `Producer` / `Consumer` / `AdminClient` / `SchemaRegistry` |
| Importing `github.com/mostafa/xk6-kafka@latest` (no `/v2`) for a v2 build | Pulls v1 because Go-modules major-version path is missing | `github.com/mostafa/xk6-kafka/v2@latest` |
| `acks=0` because "we want max throughput" | Undermeasures latency and over-reports throughput vs production | Match production `acks` (typically `1`) |
| Producing identical message bodies every iteration | Broker compression and consumer caching get unrealistic free wins | Vary at least one field per iteration (timestamp, ID, payload nonce) |
| Treating `RequestHandlerAvgIdlePercent < 80%` as "fine" | The shape is non-linear; latency knees up well before 0% | Warn at < 30%, treat < 20% as saturated and stop |
| Saving load-generated synthetic IDs into the production schema | Pollutes prod data, breaks foreign keys, contaminates analytics | Use a clearly-namespaced ID pattern (e.g. `acct_LOADTEST_*`) and drop in cleanup |

---

## PRE-DONE VERIFICATION CHECKLIST

Before declaring a Kafka load test complete:

- [ ] **Tool selection is justified**: perf-test.sh for broker-shape changes, xk6-kafka for application headlines (or both, in that order).
- [ ] **Pass 1 broker baseline exists** for the current `KafkaNodePool` / partition count / RF. Number is recorded in the run doc.
- [ ] **Sizing knobs pinned** in the script header (message size, target rate, ramp profile, partitions, `acks`, `linger.ms`, `batch.size`, `compression.type`, duration, warmup).
- [ ] **k6 binary built with the v2 import path** (`github.com/mostafa/xk6-kafka/v2@latest`). Confirmed via `./k6 version`.
- [ ] **Topic created in `setup()`** with a fresh `AdminClient`, verified via `listTopics()`, followed by `sleep(2)`. **No** `if (__VU == 0)` at module scope.
- [ ] **Thresholds bound** to `kafka_writer_*` (and `kafka_reader_*` if consuming) plus app-side SLOs. k6 will exit non-zero on breach.
- [ ] **Run executed from a `Job` in `testing-system`** (or equivalent dedicated namespace) targeting the in-cluster bootstrap `Service`. **Not** from a laptop or CI runner.
- [ ] **Four-quadrant Grafana view** open during the run: producer p99, broker `RequestHandlerAvgIdlePercent`, per-partition consumer lag, app handler p99.
- [ ] **Stop condition recorded**: which of (error-rate / p99 / lag / handler-idle) fired first, at what offered load.
- [ ] **Cleanup completed**: topic deleted (or truncated), consumer-group offsets reset, synthetic rows dropped from app DB, Schema Registry subjects pruned if applicable.
- [ ] **Limiting resource named** in the run summary: CPU / network-in / network-out / log disk / DB pool / GC / handler latency. Not "it broke at X msg/s" — *which resource* was the first to saturate.
- [ ] **Run is reproducible**: script + values committed; `Job` manifest committed; baseline numbers committed in the same PR.

If any item is unchecked, the run is **not** complete — it's a data point in search of a methodology.

---

## REFERENCES

- xk6-kafka: https://github.com/mostafa/xk6-kafka  (v2 API, current)
- TypeScript defs: `api-docs/v2/index.d.ts` in the xk6-kafka repo
- Example v2 scripts: `scripts/v2/` in the xk6-kafka repo
- k6 scenarios: https://grafana.com/docs/k6/latest/using-k6/scenarios/
- k6 thresholds: https://grafana.com/docs/k6/latest/using-k6/thresholds/
- Grafana blog tutorial (v1-era, partly outdated): https://grafana.com/blog/load-testing-kafka-producers-and-consumers/
- Apache Kafka tools (`kafka-producer-perf-test.sh` etc.): bundled with every Kafka distribution under `bin/`
- Sister skills: `kafka-strimzi-operator` (cluster sizing), `addons-and-building-blocks` (deployment via App-of-Apps)
