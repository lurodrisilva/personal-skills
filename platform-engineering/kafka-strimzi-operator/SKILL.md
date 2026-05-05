---
name: kafka-strimzi-operator
description: MUST USE when authoring, reviewing, deploying, sizing, tuning, or **performance-testing** anything involving **Apache Kafka on Kubernetes via the Strimzi operator** — including Strimzi Cluster Operator, Topic Operator, User Operator, Drain Cleaner, the `Kafka` / `KafkaNodePool` / `KafkaTopic` / `KafkaUser` / `KafkaConnect` / `KafkaConnector` / `KafkaMirrorMaker2` / `KafkaBridge` / `KafkaRebalance` / `StrimziPodSet` custom resources; KRaft-only deployments (controllers + brokers as separate node pools, ZooKeeper is removed in Kafka 4.0+); listener types (`internal`, `cluster-ip`, `nodeport`, `loadbalancer`, `ingress`, `route`); broker storage choices (`ephemeral`, `persistent-claim`, `jbod`) and `storageClass` selection (Premium SSD v2, gp3, hyperdisk); JVM tuning (`spec.jvmOptions.-Xms/-Xmx`, GC); resource requests/limits and how they MUST line up with `cruiseControl.brokerCapacity.cpu` / `inboundNetwork` / `outboundNetwork`; the **exact `BrokerCapacity` schema** (`cpu` matching `^[0-9]+([.][0-9]{0,3}|[m]?)$`, `inboundNetwork`/`outboundNetwork` matching `^[0-9]+([KMG]i?)?B/s$`, plus per-broker `overrides` carrying `brokers` as `List<Integer>`); Cruise Control optimisation goals, anomaly detectors, and `KafkaRebalance` modes (`full`, `add-brokers`, `remove-brokers`, `rebalance-disks`); FeatureGates including `KafkaNodePools` (default true 0.46+) and unidirectional Topic Operator; rack awareness via `spec.rack.topologyKey`; pod placement (`affinity`, `tolerations`, `topologySpreadConstraints`); the canonical `entityOperator` block carrying `topicOperator` and `userOperator`; PodDisruptionBudgets and `Drain Cleaner` for safe rolling updates; metrics via `kafka-metrics` ConfigMap, JMX exporter on port 9404, the Strimzi Metrics Reporter, and `KafkaUser` quotas (`producerByteRate`, `consumerByteRate`, `requestPercentage`, `controllerMutationRate`); install via `install/cluster-operator/*.yaml`, the `oci://quay.io/strimzi-helm/strimzi-kafka-operator` Helm chart, OperatorHub/OLM, or the Strimzi Kafka CLI; namespace scoping via `STRIMZI_NAMESPACE` (single, comma-list, or empty for all-namespaces); and **load testing** Kafka deployed by Strimzi from .NET / JVM / Go / Node clients including `Hex.Scaffold` Kafka inbound (`Adapters.Inbound` consumer `BackgroundService`) and outbound (`Adapters.Outbound` producer via `Confluent.Kafka`). Triggers on phrases — "deploy strimzi", "install strimzi", "kafka on kubernetes", "kraft mode", "kafka node pool", "broker capacity", "cruise control", "kafka rebalance", "kafka quotas", "strimzi listeners", "kafka load test", "kafka perf test", "kafka throughput", "kafka p99 latency", "size kafka brokers", "tune broker network", "kafka inbound outbound", "hex-scaffold kafka", "Confluent.Kafka producer", "background service consumer". Triggers on file patterns — `**/Kafka.yaml`, `**/KafkaNodePool.yaml`, `**/KafkaTopic.yaml`, `**/KafkaUser.yaml`, `**/KafkaConnect*.yaml`, `**/KafkaMirrorMaker2.yaml`, `**/KafkaBridge.yaml`, `**/KafkaRebalance.yaml`, `**/cruise-control*.yaml`, `**/strimzi-cluster-operator*.yaml`, `helm-charts/strimzi-*/`, `addon_charts/kafka/`, `tests/loadtest/**/kafka*`, `**/values-kafka-*.yaml`. Authored by a distinguished Kubernetes Platform Engineer — emphasises **explicit role separation, per-resource capacity contracts that match what Cruise Control sees, KRaft-only minds, in-cluster low-overhead listeners during perf tests, and the saturation-band sizing methodology applied to Kafka's four limiting resources (CPU, network-in, network-out, log disk)**. Used to rank perf-test bottlenecks against PostgreSQL Platinum+ baselines already established in `hex-scaffold` and to design Kafka tier ladders that scale predictably under k6.
license: BSD-3-Clause
compatibility: opencode
metadata:
  domain: platform-engineering
  pattern: managed-kafka-on-kubernetes
  platform: kubernetes
  stack: strimzi + kafka + cruise-control + kraft
  cloud: any (aks/eks/gke/openshift)
  use_cases: load-testing, performance-engineering, capacity-planning
---

# Kafka on Kubernetes via Strimzi — Distinguished Platform Engineer's Playbook

You are a Platform Engineer responsible for **running Apache Kafka on Kubernetes through the Strimzi operator** for product teams whose services consume Kafka as **inbound** (BackgroundService consumers) and **outbound** (producers) adapters. Your job is to turn the cluster into a paved road for messaging: declarative `Kafka` / `KafkaNodePool` resources, predictable rolling updates, capacity contracts that the operator and Cruise Control both honour, and a perf-test rig that surfaces the **first** limiting resource (CPU, network-in, network-out, or log disk) under realistic offered load — not just whatever happens to break first.

This skill encodes the opinions that make a Strimzi-on-Kubernetes deployment **perf-testable, sizing-defensible, and upgrade-boring**: KRaft-only (no ZooKeeper, ever), explicit controller/broker role separation via `KafkaNodePool`, broker resource limits that mirror `cruiseControl.brokerCapacity` 1:1, in-cluster listeners during synthetic load (no `loadbalancer` overhead), and the same **60–80% saturation-band methodology** already proven on this account's PostgreSQL ladder, applied to Kafka's four limiting resources.

**Non-negotiables encoded in this skill:**

1. **KRaft only — never ZooKeeper.** Kafka 4.0+ removed ZooKeeper; Strimzi 0.46+ defaults `KafkaNodePools` to true. Any new cluster declares two `KafkaNodePool` resources with disjoint roles: one `[controller]` pool, one `[broker]` pool. Combined `[controller, broker]` is allowed for tiny dev clusters but **forbidden** for any cluster that will be perf-tested or run in prod — the metadata-quorum I/O competes with broker fetch/produce I/O and corrupts CPU saturation readings.
2. **Three controllers, always.** Controller pool `replicas: 3` minimum. Five for very large clusters or when controller failover during perf is in scope. Never two (split-brain). Never one (no quorum).
3. **`brokerCapacity` mirrors `resources.limits` 1:1 — and `inboundNetwork`/`outboundNetwork` mirror the **node's** NIC, not a guess.** Cruise Control bases every rebalance, every goal violation, every anomaly detection on these three numbers (`cpu`, `inboundNetwork`, `outboundNetwork`). If `resources.limits.cpu = 4` but `brokerCapacity.cpu = 8`, Cruise Control thinks the broker has twice the headroom it actually does and produces unsafe rebalance proposals. **The `BrokerCapacity` schema does not include `disk` or `cpuUtilization` in the current API** — disk is read from the PVC and CPU from `resources` automatically.
4. **Listener choice is a perf-test variable.** During synthetic load, use `internal` (ClusterIP) listeners with TLS **disabled** and authentication **disabled** — that strips ~15–35% TLS+SASL overhead and isolates the broker code path. Re-test with `tls: true` + `authentication: scram-sha-512` separately to *measure* the security overhead, not bundle it into the headline number.
5. **Storage type is a tiered choice, not a default.** `ephemeral` is **dev/test only** (data is lost on pod restart, and replication-factor-3 hides the loss until two pods restart together). Production and perf both use `persistent-claim` (single-volume) or `jbod` (multiple volumes per broker). `storageClass:` MUST be the cloud's NVMe-class tier (Azure `managed-csi-premium` / Premium SSD v2, AWS `gp3` with provisioned IOPS, GCP `hyperdisk-balanced`) — anything slower bottlenecks the log-flush path before CPU.
6. **Rack awareness on multi-zone clusters.** `spec.kafka.rack.topologyKey: topology.kubernetes.io/zone` (and the same on every `KafkaNodePool` template) — without it, RF=3 partitions can land all three replicas in the same zone and a single AZ outage drops the topic. Rack labels also enable `client.rack`-aware fetch-from-follower for cross-zone read locality.
7. **Pod anti-affinity per node pool, hard.** `requiredDuringSchedulingIgnoredDuringExecution` so two brokers (or two controllers) never co-locate on the same node. A node failure during perf testing is a real event, and co-located brokers double the partition unavailability window.
8. **Quotas OFF during synthetic perf tests.** `KafkaUser.spec.quotas.{producerByteRate,consumerByteRate,requestPercentage,controllerMutationRate}` are **production safety belts**, not perf knobs. Setting them while measuring peak throughput silently caps the test. Re-enable per tenant *after* the headline numbers are established.
9. **Topic Operator runs in unidirectional mode (the 0.46+ default).** `KafkaTopic` is the source of truth; the operator never reflects manual `kafka-topics --create` calls back into CRs. If a perf test needs a topic created with broker-specific configs (`segment.bytes`, `compression.type`), declare it as a `KafkaTopic` — never `kubectl exec` into a broker.
10. **Metrics are mandatory before perf tests, not optional.** Wire the `kafka-metrics` / `cruise-control-metrics` ConfigMaps into `spec.kafka.metricsConfig` and `spec.cruiseControl.metricsConfig`, scrape JMX-exporter port 9404 (or the Strimzi Metrics Reporter equivalent) into Prometheus, and pre-build the four headline panels (CPU per broker, network in per broker, network out per broker, log-flush p99) **before** firing k6. Without those four, you can't tell which resource saturated first.
11. **`Drain Cleaner` + `PodDisruptionBudget` for any cluster larger than a single broker.** Without Drain Cleaner, a node-drain can evict a broker mid-replica-fetch; with it, the operator orchestrates the rolling update via partition-leader election. PDB `maxUnavailable: 1` per broker pool is the only safe value for RF=3.
12. **Cluster Operator runs HA (replicas ≥ 2) for any non-toy environment.** It uses leader election; the standby is cheap and removes the operator itself as a single point of failure during a perf test that exercises CRD reconciliation.

If a `Kafka` / `KafkaNodePool` / Helm chart / perf-test setup under review violates any of these, **flag them first** before any other comment.

---

## WHEN TO USE THIS SKILL

| Scenario | Use this skill? |
|----------|-----------------|
| Adding a new `Kafka` cluster to a baseline GitOps repo via Strimzi | **Yes** |
| Authoring a `KafkaNodePool` with role separation (controller / broker) | **Yes** |
| Sizing brokers ahead of a perf test (CPU, RAM, network, disk) | **Yes** |
| Wiring `cruiseControl.brokerCapacity` so rebalances reflect real headroom | **Yes** |
| Choosing between `internal`, `cluster-ip`, `nodeport`, `loadbalancer`, `ingress`, `route` listeners | **Yes** |
| Declaring `KafkaTopic` / `KafkaUser` / TLS / SCRAM-SHA-512 / mTLS | **Yes** |
| Deploying `KafkaConnect` + `KafkaConnector` for source/sink integration tests | **Yes** |
| Setting up Cruise Control + `KafkaRebalance` (`full`, `add-brokers`, `remove-brokers`, `rebalance-disks`) | **Yes** |
| Driving k6 / JMeter / kafka-producer-perf-test against a Strimzi cluster | **Yes** |
| Hardening a `hex-scaffold` Kafka inbound `BackgroundService` consumer / outbound producer for perf | **Yes** |
| Turning a perf result into a tier-ladder doc (Bronze/Silver/Gold/Platinum) | **Yes** |
| Investigating an under-replicated-partition or controller-quorum incident | **Yes** |
| Vanilla Kafka outside Kubernetes (Confluent Cloud, MSK, on-prem ZK clusters) | **No** — Strimzi is the operating layer; outside K8s the rules differ |
| ZooKeeper-mode Kafka clusters on Strimzi 0.45 or older | **No** — refuse and recommend KRaft migration first |
| Authoring a Kafka client library or codec-level optimisation | **No** — application concern, not platform |
| Picking between Kafka and Pulsar / Redpanda / RabbitMQ | **No** — strategy / architecture call, out of scope |

---

## ARCHITECTURE — THE STRIMZI MENTAL MODEL

```
┌─────────────────────────────────────────────────────────────────────┐
│  L4  CONSUMERS (apps)                                                │
│      hex-scaffold Adapters.Inbound  (Kafka BackgroundService)        │
│      hex-scaffold Adapters.Outbound (Confluent.Kafka producer)       │
│      Connect to: <cluster>-kafka-bootstrap.<ns>.svc:9092 (PLAINTEXT) │
│                  <cluster>-kafka-bootstrap.<ns>.svc:9093 (TLS)       │
└─────────────────────────────────────────────────────────────────────┘
                                ▲
                                │  produce / fetch
                                │
┌─────────────────────────────────────────────────────────────────────┐
│  L3  KAFKA DATA PLANE  (KafkaNodePool: roles=[broker])               │
│      StatefulSet of N brokers                                        │
│      PV per broker (persistent-claim or JBOD)                        │
│      Listeners: internal:9092 + tls:9093 (+ external if needed)      │
│      Owns: log segments, replication, ISR, partition leadership      │
└─────────────────────────────────────────────────────────────────────┘
                                ▲
                                │  metadata reads / writes
                                │
┌─────────────────────────────────────────────────────────────────────┐
│  L2  KAFKA CONTROL PLANE  (KafkaNodePool: roles=[controller])        │
│      StatefulSet of 3 controllers (KRaft quorum)                     │
│      Owns: cluster metadata, controller election, broker registry    │
│      No partition data — small-PV (10–20 GiB) is fine                │
└─────────────────────────────────────────────────────────────────────┘
                                ▲
                                │  reconcile (CRDs)
                                │
┌─────────────────────────────────────────────────────────────────────┐
│  L1  STRIMZI CLUSTER OPERATOR  +  ENTITY OPERATOR                    │
│      Deployment (HA: replicas ≥ 2, leader election)                  │
│      Watches: Kafka, KafkaNodePool, KafkaTopic, KafkaUser,           │
│               KafkaConnect, KafkaConnector, KafkaMirrorMaker2,       │
│               KafkaBridge, KafkaRebalance, StrimziPodSet             │
│      Renders: StatefulSets, Services, Secrets, ConfigMaps,           │
│               NetworkPolicies, PodDisruptionBudgets                  │
└─────────────────────────────────────────────────────────────────────┘
                                ▲
                                │  side-cars / co-deployments
                                │
┌─────────────────────────────────────────────────────────────────────┐
│  L0  CRUISE CONTROL  (one per Kafka cluster, optional)               │
│      Reads: brokerCapacity (cpu / inboundNetwork / outboundNetwork)  │
│      Reads: real-time JMX metrics from every broker                  │
│      Produces: optimisation proposals → KafkaRebalance reconciliation│
│                                                                      │
│  L0  DRAIN CLEANER  (one per K8s cluster, optional)                  │
│      Annotates pods being drained → Cluster Operator does rolling    │
│      restart with proper partition-leader election                   │
└─────────────────────────────────────────────────────────────────────┘
```

**One-way dependency flow.** Apps → brokers → controllers → operator → CRDs. Apps never talk to the operator. The operator never re-reads cluster state from `kubectl exec`. Cruise Control reads broker JMX, never bypasses the operator to mutate the cluster.

---

## STRIMZI COMPONENT MAP

### Operators

| Operator | What it watches | Where it runs | Required for perf? |
|----------|-----------------|---------------|--------------------|
| **Cluster Operator** | `Kafka`, `KafkaNodePool`, `KafkaConnect`, `KafkaConnector`, `KafkaMirrorMaker2`, `KafkaBridge`, `KafkaRebalance`, `StrimziPodSet` | one Deployment per Strimzi install (cluster-scoped or namespace-scoped via `STRIMZI_NAMESPACE`) | **Yes** |
| **Topic Operator** | `KafkaTopic` | inside `entityOperator` pod (Kafka resource) | **Yes** |
| **User Operator** | `KafkaUser` | inside `entityOperator` pod (Kafka resource) | **Yes** if auth used; **No** if perf is internal-plaintext |
| **Drain Cleaner** | annotated pods at eviction time | one Deployment per K8s cluster | **Yes** for any cluster ≥ 2 brokers |
| **Strimzi Access Operator** (optional) | service-binding requests | optional add-on | **No** for perf |

### Custom Resources

| CR | Purpose | Cardinality |
|----|---------|-------------|
| `Kafka` | Cluster-level config (listeners, auth, entityOperator, cruiseControl, metrics) | 1 per cluster |
| `KafkaNodePool` | Group of brokers or controllers with same shape (replicas, roles, storage, resources) | 1+ per cluster |
| `KafkaTopic` | Topic spec (partitions, replicas, config map) | 1 per topic |
| `KafkaUser` | User identity (TLS / SCRAM), ACLs, quotas | 1 per principal |
| `KafkaRebalance` | Cruise Control rebalance request (`full`, `add-brokers`, `remove-brokers`, `rebalance-disks`) | per rebalance |
| `KafkaConnect` | Connect runtime cluster | 1 per Connect cluster |
| `KafkaConnector` | Source/sink connector instance inside a Connect cluster | per connector |
| `KafkaMirrorMaker2` | Cross-cluster replication | per source→target pair |
| `KafkaBridge` | HTTP REST gateway to Kafka | usually 1 per cluster |
| `StrimziPodSet` | Internal — replaces native StatefulSet for the broker fleet | managed |

---

## INSTALLATION

### Method 1 — YAML manifests (the "knows what's happening" path)

```bash
# 1. Download the release bundle from https://strimzi.io/downloads/
#    Pin the version — never "latest"
STRIMZI_VERSION=0.46.0
curl -L https://github.com/strimzi/strimzi-kafka-operator/releases/download/${STRIMZI_VERSION}/strimzi-${STRIMZI_VERSION}.tar.gz | tar xz

# 2. Edit install/cluster-operator/060-Deployment-strimzi-cluster-operator.yaml:
#    - STRIMZI_NAMESPACE: "kafka,kafka-perf"   (comma list, or "" for all namespaces)
#    - STRIMZI_FULL_RECONCILIATION_INTERVAL_MS: 120000  (raise to 300000 in stable prod)
#    - STRIMZI_OPERATION_TIMEOUT_MS: 300000

# 3. Apply CRDs first, then the operator
kubectl create namespace kafka
kubectl apply -f strimzi-${STRIMZI_VERSION}/install/cluster-operator/ -n kafka
```

**Namespace scoping rules.** `STRIMZI_NAMESPACE` controls the watch list:
- single value `kafka` → only watches `kafka` namespace
- `"kafka,kafka-perf,kafka-prod"` → comma-separated list (RBAC needs RoleBindings in each)
- `""` (empty string) → all namespaces (requires cluster-scoped RBAC)

For perf testing, **always isolate** the perf cluster in its own namespace — the operator-level rate limits and reconciliation interval interact with prod clusters otherwise.

### Method 2 — Helm chart (the "GitOps-native" path)

```bash
helm install strimzi-cluster-operator \
  oci://quay.io/strimzi-helm/strimzi-kafka-operator \
  --version 0.46.0 \
  --namespace kafka --create-namespace \
  --set watchAnyNamespace=false \
  --set watchNamespaces='{kafka,kafka-perf}' \
  --set replicas=2 \
  --set logLevel=INFO
```

For ArgoCD App-of-Apps installs, point the Application at the OCI chart with the same values block — see the parent skill `addons-and-building-blocks` for sync-wave conventions (Strimzi Cluster Operator at wave 2 — after CRDs but before Kafka clusters).

### Method 3 — OperatorHub / OLM

Subscription via the Strimzi PackageManifest. Pin `installPlanApproval: Manual` for prod. **Avoid for perf clusters** — OLM auto-upgrades during a multi-day perf test invalidate baselines.

### Method 4 — Strimzi Kafka CLI

`kfk`-style command. Convenient for ad-hoc dev, **not** for repeatable perf.

### Verify

```bash
kubectl -n kafka get deploy strimzi-cluster-operator
kubectl -n kafka logs -l name=strimzi-cluster-operator -c strimzi-cluster-operator | grep -i "leader election"
kubectl get crd | grep strimzi
```

---

## CLUSTER TOPOLOGY — KRaft WITH SPLIT NODE POOLS

The minimal perf-grade `Kafka` cluster requires **three CRs**: one `Kafka`, one controller `KafkaNodePool`, one broker `KafkaNodePool`.

```yaml
# 1. Controllers — small footprint, metadata only
apiVersion: kafka.strimzi.io/v1
kind: KafkaNodePool
metadata:
  name: controller
  namespace: kafka-perf
  labels:
    strimzi.io/cluster: hex-perf
spec:
  replicas: 3
  roles:
    - controller
  storage:
    type: jbod
    volumes:
      - id: 0
        type: persistent-claim
        size: 20Gi
        class: managed-csi-premium  # Azure Premium SSD v2 (perf-grade)
        deleteClaim: false
        kraftMetadata: shared       # tag the controller's volume as the KRaft metadata carrier
  resources:
    requests:
      cpu: 500m
      memory: 1Gi
    limits:
      cpu: "1"
      memory: 2Gi
  jvmOptions:
    -Xms: 512m
    -Xmx: 1g
  template:
    pod:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            - labelSelector:
                matchLabels:
                  strimzi.io/pool-name: controller
              topologyKey: kubernetes.io/hostname
      tolerations:
        - key: kafka-control-plane
          operator: Equal
          value: "true"
          effect: NoSchedule
---
# 2. Brokers — fat data plane
apiVersion: kafka.strimzi.io/v1
kind: KafkaNodePool
metadata:
  name: broker
  namespace: kafka-perf
  labels:
    strimzi.io/cluster: hex-perf
spec:
  replicas: 6
  roles:
    - broker
  storage:
    type: jbod
    volumes:
      - id: 0
        type: persistent-claim
        size: 500Gi
        class: managed-csi-premium
        deleteClaim: false
        kraftMetadata: shared    # tag ONE volume per node as the KRaft metadata carrier (1.0.0+)
  resources:
    requests:
      cpu: "4"
      memory: 16Gi
    limits:
      cpu: "4"
      memory: 16Gi               # request == limit pins the broker (no CPU throttle surprises)
  jvmOptions:
    -Xms: 8g
    -Xmx: 8g                     # heap == half the limit (rest for page cache + off-heap buffers)
    "-XX":
      UseG1GC: "true"
      MaxGCPauseMillis: "20"
  template:
    pod:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            - labelSelector:
                matchLabels:
                  strimzi.io/pool-name: broker
              topologyKey: kubernetes.io/hostname
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: agentpool
                    operator: In
                    values: [kafka-broker]
---
# 3. Cluster — listeners, auth, cruiseControl, entityOperator
apiVersion: kafka.strimzi.io/v1
kind: Kafka
metadata:
  name: hex-perf
  namespace: kafka-perf
  annotations:
    strimzi.io/node-pools: enabled
    strimzi.io/kraft: enabled
spec:
  kafka:
    version: "4.2.0"                  # current Kafka version shipped with Strimzi 1.0.0
    metadataVersion: "4.2-IV1"        # the metadata version paired with 4.2.0 in the 1.0.0 examples
    listeners:
      - name: plain
        port: 9092
        type: internal
        tls: false
      - name: tls
        port: 9093
        type: internal
        tls: true
        authentication:
          type: tls
    config:
      # Replication and durability
      default.replication.factor: 3
      min.insync.replicas: 2
      offsets.topic.replication.factor: 3
      transaction.state.log.replication.factor: 3
      transaction.state.log.min.isr: 2
      # Throughput-friendly defaults — re-read after every perf run
      num.network.threads: 8
      num.io.threads: 16
      num.replica.fetchers: 4
      message.max.bytes: 1048576       # 1 MiB — raise consciously, breaks producer-side too
      replica.fetch.max.bytes: 1048576
      compression.type: producer       # let producers choose; broker doesn't recompress
      log.segment.bytes: 1073741824    # 1 GiB
      log.retention.hours: 24          # short for perf clusters; 168h+ for prod
      log.roll.hours: 24
      auto.create.topics.enable: false # KafkaTopic CR is the source of truth
      unclean.leader.election.enable: false  # never silently lose data; matches min.insync.replicas: 2
      replica.lag.time.max.ms: 30000   # raise to 60000 if cross-zone replica lag is acceptable
      leader.imbalance.check.interval.seconds: 300
    rack:
      topologyKey: topology.kubernetes.io/zone
    metricsConfig:
      type: jmxPrometheusExporter
      valueFrom:
        configMapKeyRef:
          name: kafka-metrics
          key: kafka-metrics-config.yml
  entityOperator:
    topicOperator:
      reconciliationIntervalSeconds: 60
      resources:
        requests: { cpu: 100m, memory: 256Mi }
        limits:   { cpu: 500m, memory: 512Mi }
    userOperator:
      reconciliationIntervalSeconds: 60
      resources:
        requests: { cpu: 100m, memory: 256Mi }
        limits:   { cpu: 500m, memory: 512Mi }
  cruiseControl:
    brokerCapacity:
      cpu: "4"                          # MUST equal KafkaNodePool resources.limits.cpu
      inboundNetwork:  "100MiB/s"       # node NIC realistic ceiling, NOT a guess
      outboundNetwork: "100MiB/s"
      # overrides:                      # optional — see BrokerCapacity reference below
      #   - brokers: [3, 4, 5]
      #     cpu: "8"
      #     inboundNetwork: "200MiB/s"
      #     outboundNetwork: "200MiB/s"
    config:
      hard.goals: >-
        com.linkedin.kafka.cruisecontrol.analyzer.goals.RackAwareGoal,
        com.linkedin.kafka.cruisecontrol.analyzer.goals.MinTopicLeadersPerBrokerGoal,
        com.linkedin.kafka.cruisecontrol.analyzer.goals.ReplicaCapacityGoal,
        com.linkedin.kafka.cruisecontrol.analyzer.goals.NetworkInboundCapacityGoal,
        com.linkedin.kafka.cruisecontrol.analyzer.goals.NetworkOutboundCapacityGoal,
        com.linkedin.kafka.cruisecontrol.analyzer.goals.CpuCapacityGoal,
        com.linkedin.kafka.cruisecontrol.analyzer.goals.DiskCapacityGoal
    metricsConfig:
      type: jmxPrometheusExporter
      valueFrom:
        configMapKeyRef:
          name: cruise-control-metrics
          key: cruise-control-metrics-config.yml
```

**Why request == limit on brokers.** Burstable QoS lets the kubelet throttle CPU under noisy-neighbour pressure — perf measurements then become unreliable. Guaranteed QoS (`requests == limits`) gives the broker a fixed slice and matches what `cruiseControl.brokerCapacity.cpu` advertises.

**Why heap = limit / 2.** Kafka's hot path is the OS page cache, not the JVM heap. Reserving half the container's memory for off-heap (page cache + direct buffers + metaspace) is the rule of thumb that holds across versions; raising `-Xmx` past that point starves the cache without helping throughput.

---

## STORAGE

| Type | When | Pitfall |
|------|------|---------|
| `ephemeral` | dev only | data lost on pod restart; replication-factor-3 hides it until two pods restart together |
| `persistent-claim` (single volume) | default for prod & perf | one PV becomes the IOPS/throughput ceiling — fine on Premium SSD v2 / gp3 / hyperdisk where IOPS is provisioned independently of size, but a real ceiling on basic managed disks |
| `jbod` (multiple volumes per broker) | high-throughput perf, MSK-style sharding | requires `cruiseControl.config.disk.balancer` and `KafkaRebalance.spec.mode: rebalance-disks` for cross-volume balancing |

`storageClass:` cheat sheet:

| Cloud | Class | Why |
|-------|-------|-----|
| Azure | `managed-csi-premium` (Premium SSD v2 with provisioned IOPS+throughput) | flat IOPS regardless of volume size |
| AWS | `gp3` | dial IOPS and throughput independently of capacity |
| GCP | `hyperdisk-balanced` or `hyperdisk-throughput` | provisioned throughput |
| On-prem | local-path on NVMe nodes (`StorageClass volumeBindingMode: WaitForFirstConsumer`) | avoid network-attached storage on the log path if avoidable |

**Sizing rule of thumb.** PV size = `log.retention.hours × peak inbound bytes/s × replication-factor / brokers × 1.3` (the 1.3 buffers segment-roll lag and any in-flight rebalance).

---

## LISTENERS

| Type | Bootstrap | Use case | Perf-test default? |
|------|-----------|----------|--------------------|
| `internal` | `<cluster>-kafka-bootstrap.<ns>.svc:<port>` | in-cluster clients | **Yes** |
| `cluster-ip` | explicit ClusterIP service | per-broker addressability inside cluster | sometimes |
| `nodeport` | `<node-IP>:30000–32767` | dev access from outside the cluster | no |
| `loadbalancer` | cloud LB (one per broker + bootstrap) | external clients in cloud | **No** during perf — adds 1–3 ms LB overhead |
| `ingress` | NGINX with TLS-passthrough | external clients via existing ingress | no |
| `route` | OpenShift route | OpenShift external | no |

For perf testing from k6 / kafka-producer-perf-test pods inside the same cluster, **always** use `internal` + `tls: false` to isolate the broker code path. Run a separate test with `tls: true` to *measure* TLS overhead.

---

## RESOURCES & JVM TUNING

| Knob | Where | Default-ish | Perf rule |
|------|-------|-------------|-----------|
| `resources.requests.cpu` | `KafkaNodePool.spec.resources` | none | match limits |
| `resources.limits.cpu` | same | none | == `cruiseControl.brokerCapacity.cpu` |
| `resources.requests.memory` | same | none | match limits (Guaranteed QoS) |
| `resources.limits.memory` | same | none | broker container total |
| `jvmOptions.-Xms` | `KafkaNodePool.spec.jvmOptions` | none | == `-Xmx` (no heap growth pauses) |
| `jvmOptions.-Xmx` | same | none | ≤ 50% of `resources.limits.memory` |
| `jvmOptions."-XX": UseG1GC: "true"` | same | depends | G1 with `MaxGCPauseMillis: 20` is the safe baseline |
| `jvmOptions.javaSystemProperties` | same | empty | only for `kafka.network.SocketServer.bufferSize` and similar surgical knobs |

**Networking knobs** (`spec.kafka.config`):
- `num.network.threads` — start at 1 per CPU core, raise if `RequestQueueTimeMs` p99 > 5 ms
- `num.io.threads` — 2× `num.network.threads` is the conservative starting point
- `num.replica.fetchers` — number of fetcher threads per source broker; raise if replica lag grows under load
- `socket.send.buffer.bytes` / `socket.receive.buffer.bytes` — leave default (102400) unless cross-zone WAN

---

## BROKERCAPACITY — VERBATIM API CONTRACT

This is the **current API** from the Strimzi `BrokerCapacity` Java class (main branch). **Note that earlier docs referenced `disk` and `cpuUtilization` fields — these are gone from the current API.** Disk is read from the PVC; CPU goal evaluation reads from `resources` automatically.

### `BrokerCapacity` (cluster-wide defaults)

| Property | Type | Default | Pattern / Constraints | Description |
|----------|------|---------|-----------------------|-------------|
| `cpu` | String | `null` | `^[0-9]+([.][0-9]{0,3}|[m]?)$` | Broker capacity for CPU resource in cores or millicores. For example, `1`, `1.500`, `1500m`. See https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/#meaning-of-cpu |
| `inboundNetwork` | String | `null` | `^[0-9]+([KMG]i?)?B/s$` | Broker capacity for inbound network throughput in bytes per second. Use an integer value with standard Kubernetes byte units (K, M, G) or their bibyte (power of two) equivalents (Ki, Mi, Gi) per second. For example, `10000KiB/s`. |
| `outboundNetwork` | String | `null` | `^[0-9]+([KMG]i?)?B/s$` | Broker capacity for outbound network throughput in bytes per second. Same units. For example, `10000KiB/s`. |
| `overrides` | List<BrokerCapacityOverride> | `null` | — | Overrides for individual brokers. Lets you specify a different capacity configuration for different brokers. |

### `BrokerCapacityOverride` (per-broker)

| Property | Type | JSON order | Description |
|----------|------|------------|-------------|
| `brokers` | List<Integer> | 1 | List of Kafka brokers (broker identifiers, e.g. `[0, 1, 2]`). |
| `cpu` | String | 2 | Broker capacity for CPU resource in cores or millicores. For example, `1`, `1.500`, `1500m`. |
| `inboundNetwork` | String | 3 | Broker capacity for inbound network throughput in bytes per second. |
| `outboundNetwork` | String | 4 | Broker capacity for outbound network throughput in bytes per second. |

### Example — heterogeneous broker pool (some bigger nodes carry 2× the network)

```yaml
spec:
  cruiseControl:
    brokerCapacity:
      cpu: "4"
      inboundNetwork:  "100MiB/s"
      outboundNetwork: "100MiB/s"
      overrides:
        - brokers: [3, 4, 5]            # broker IDs (NOT pod names)
          cpu: "8"
          inboundNetwork:  "200MiB/s"
          outboundNetwork: "200MiB/s"
```

**Two traps:**
1. **Unit mismatch.** `100MB/s` ≠ `100MiB/s` — Cruise Control will accept either string but its goal arithmetic uses what you wrote. Pick **MiB/s** (binary) for consistency with everything else in K8s.
2. **`brokerCapacity.cpu > resources.limits.cpu` is a config bug.** It tells Cruise Control the broker can absorb partition moves it physically cannot. Cluster Operator does not cross-validate these two; you must.

---

## CRUISE CONTROL & KAFKARBALANCE

Cruise Control reads JMX metrics from every broker, builds a workload model, and produces optimisation proposals. You request a proposal by creating a `KafkaRebalance` CR; the operator drives the proposal-then-execute lifecycle.

### Modes

| `spec.mode` | When |
|-------------|------|
| `full` (default) | rebalance the whole cluster against goals |
| `add-brokers` (with `spec.brokers: [N, N+1, ...]`) | after scaling up `KafkaNodePool.spec.replicas` |
| `remove-brokers` (with `spec.brokers: [...]`) | before scaling down |
| `remove-disks` (with `moveReplicasOffVolumes: [{ brokerId, volumeIds }]`) | drain replicas off specific JBOD volumes prior to volume removal — replaces the older `rebalance-disks` mode in 1.0.0 |

### Lifecycle

```bash
# 1. Create the request
cat <<EOF | kubectl apply -f -
apiVersion: kafka.strimzi.io/v1
kind: KafkaRebalance
metadata:
  name: pre-perf-rebalance
  namespace: kafka-perf
  labels:
    strimzi.io/cluster: hex-perf
spec:
  mode: full
  goals:
    - RackAwareGoal
    - NetworkInboundCapacityGoal
    - NetworkOutboundCapacityGoal
    - CpuCapacityGoal
    - DiskCapacityGoal
EOF

# 2. Wait for the proposal to be ProposalReady
kubectl -n kafka-perf get kafkarebalance pre-perf-rebalance -w

# 3. Approve to execute
kubectl -n kafka-perf annotate kafkarebalance pre-perf-rebalance \
  strimzi.io/rebalance=approve

# 4. Watch progress
kubectl -n kafka-perf get kafkarebalance pre-perf-rebalance -o yaml | yq '.status'
```

**Always rebalance before a perf test that follows broker scale-out** — otherwise hot brokers carry disproportionate partition leadership and you measure load-balancer skew, not Kafka.

### Goals — quick mental map

| Goal class | What it pushes | Cost when wrong |
|------------|----------------|-----------------|
| `RackAwareGoal` | replicas across zones | losing a zone drops a topic |
| `MinTopicLeadersPerBrokerGoal` | leader spread | hot-broker syndrome |
| `NetworkInboundCapacityGoal` | per-broker inbound bytes/s ≤ `brokerCapacity.inboundNetwork` | ingress cliff under burst |
| `NetworkOutboundCapacityGoal` | symmetric | egress cliff |
| `CpuCapacityGoal` | per-broker CPU ≤ `brokerCapacity.cpu` | broker CPU saturation |
| `ReplicaCapacityGoal` | partitions per broker | metadata pressure on big clusters |
| `DiskCapacityGoal` | log disk usage | running out of disk |

The default `hard.goals` list ships these in priority order; rearranging is rarely worth it.

**Naming asymmetry — read carefully.** `cruiseControl.config.hard.goals` / `goals` / `default.goals` expect **fully-qualified class names** (`com.linkedin.kafka.cruisecontrol.analyzer.goals.RackAwareGoal`). `KafkaRebalance.spec.goals`, in contrast, accepts the **short names** (`RackAwareGoal`). Don't copy-paste between the two — the operator will accept the wrong form and silently fall back to defaults.

---

## TOPICS, USERS, AUTH, QUOTAS

### `KafkaTopic`

```yaml
apiVersion: kafka.strimzi.io/v1
kind: KafkaTopic
metadata:
  name: hex-perf-events
  namespace: kafka-perf
  labels:
    strimzi.io/cluster: hex-perf
spec:
  partitions: 24                    # parallelism ceiling per consumer group
  replicas: 3
  config:
    retention.ms: 86400000          # 24 h — perf clusters short-retain
    segment.bytes: 1073741824       # 1 GiB
    min.insync.replicas: 2
    compression.type: lz4           # producer-side hint; broker accepts and stores as-is
    cleanup.policy: delete
```

**Partitions sizing.** A consumer group's parallelism is bounded by partition count. Sweet spot: `partitions ≈ peak_target_throughput / per-partition-throughput-of-one-consumer`. For perf testing, start at `2 × CPU cores in the consumer fleet` and tune.

### `KafkaUser` — TLS auth + ACLs (no quotas during perf)

```yaml
apiVersion: kafka.strimzi.io/v1
kind: KafkaUser
metadata:
  name: hex-scaffold
  namespace: kafka-perf
  labels:
    strimzi.io/cluster: hex-perf
spec:
  authentication:
    type: tls                       # or scram-sha-512
  authorization:
    type: simple
    acls:
      - resource: { type: topic, name: "hex-perf-", patternType: prefix }
        operations: [Read, Write, Describe, Create]
        host: "*"
      - resource: { type: group, name: "hex-perf-", patternType: prefix }
        operations: [Read, Describe]
        host: "*"
  # quotas: <-- INTENTIONALLY OMITTED during perf tests
```

### `KafkaUser` — quotas for production

```yaml
spec:
  quotas:
    producerByteRate: 10485760      # 10 MiB/s
    consumerByteRate: 10485760
    requestPercentage: 50           # max 50% of broker request-handler thread time
    controllerMutationRate: 10      # KRaft-era controller call budget per second
```

**Quota interaction with perf.** Setting any of these caps measured throughput silently. Always run the headline perf with quotas off, then re-enable per-tenant *before* prod cutover.

---

## OBSERVABILITY

### Metrics ConfigMaps

The Strimzi examples repo ships ready-made `kafka-metrics-config.yml` and `cruise-control-metrics-config.yml` for the JMX Exporter — copy them as-is into a ConfigMap and reference them from `Kafka.spec.kafka.metricsConfig` and `Kafka.spec.cruiseControl.metricsConfig`. Roll your own only if you need to suppress noisy metrics.

### Prometheus / Grafana

Strimzi-shipped Grafana dashboards (`strimzi-kafka.json`, `strimzi-cruise-control.json`, `strimzi-operators.json`) are the perf-test starting point. For a perf run, confirm these four panels load with data **before** firing k6:

1. **Per-broker CPU** — `process_cpu_usage` from JMX exporter
2. **Per-broker network in** — `kafka_server_brokertopicmetrics_bytesinpersec`
3. **Per-broker network out** — `kafka_server_brokertopicmetrics_bytesoutpersec`
4. **Log-flush p99** — `kafka_log_logflush_logflushtimemsacrosspartitions{quantile="0.99"}`

If any panel is empty, fix observability first; perf without those four numbers is unreviewable.

### Logging

`spec.kafka.logging.type: inline` overrides Log4j2 properties at the CR level — useful for short-lived perf clusters. For long-lived clusters, `type: external` with a ConfigMap is the GitOps-native path.

---

## PERFORMANCE TESTING — THE PLAYBOOK

This is where this skill earns its keep. The methodology is the same **60–80% saturation-band + double-per-step** approach already used on this account's PostgreSQL ladder, applied to Kafka's four limiting resources.

### The four limiting resources

| # | Resource | Ceiling | Symptom when hit |
|---|----------|---------|------------------|
| 1 | **Broker CPU** | `resources.limits.cpu` per broker | request-handler queue grows; p99 produce/fetch latency cliff |
| 2 | **Network in** | NIC bandwidth × `brokerCapacity.inboundNetwork` accuracy | bytes-in plateau; producer batch backlogs; `RequestQueueTimeMs` rises |
| 3 | **Network out** | symmetric | bytes-out plateau; lagging consumers |
| 4 | **Log disk write throughput** | PV provisioned IOPS / throughput | log-flush p99 cliff; under-replicated partitions appear |

The right tier for a workload is the one where the **first** resource to saturate lands in the **60–80%** band at the **target offered load**.

### Pre-test checklist

- [ ] KRaft cluster with `[controller]`/`[broker]` role split
- [ ] `cruiseControl.brokerCapacity.cpu` == `KafkaNodePool.spec.resources.limits.cpu`
- [ ] `cruiseControl.brokerCapacity.inboundNetwork` matches the **node NIC realistic** ceiling
- [ ] `cruiseControl.brokerCapacity.outboundNetwork` matches symmetrically
- [ ] `KafkaTopic.spec.partitions ≥ 2 × consumer-fleet CPU cores`
- [ ] `KafkaTopic.spec.replicas: 3`, `min.insync.replicas: 2`
- [ ] Listener: `internal` + `tls: false` for headline run; separate `tls: true` run for security-overhead measurement
- [ ] **Quotas off** on the test `KafkaUser`
- [ ] All four headline Grafana panels rendering with data
- [ ] Pre-test `KafkaRebalance mode: full` completed (status `Ready`)
- [ ] Drain Cleaner running; PDB `maxUnavailable: 1`
- [ ] Perf-client pods on a **separate** node pool from brokers (no co-location)

### Producer config knobs that move the headline

| Knob | Range to sweep | What it changes |
|------|----------------|-----------------|
| `acks` | `0`, `1`, `all` | durability vs throughput; `all` is the safe default for headline |
| `linger.ms` | 5, 20, 50 | batch dwell; raises throughput at the cost of producer p99 |
| `batch.size` | 16384, 65536, 1048576 | bytes per partition batch; pair with `linger.ms` |
| `compression.type` | `none`, `lz4`, `zstd` | `lz4` is the throughput sweet spot; `zstd` for storage-bound |
| `max.in.flight.requests.per.connection` | 1, 5 | with `enable.idempotence=true` (default in modern clients) the cap is **5**; setting it to 1 trades pipeline depth for stricter ordering |
| `enable.idempotence` | `true` | enabled-by-default in modern clients; **forces** `acks=all` and caps in-flight at 5 — keep on |

### Consumer config knobs

| Knob | Range to sweep | What it changes |
|------|----------------|-----------------|
| `fetch.min.bytes` | 1, 65536, 1048576 | small = lower latency; large = higher throughput |
| `fetch.max.wait.ms` | 100, 500 | dwell on the broker side |
| `max.poll.records` | 500, 5000 | per-poll batch (back-pressure tuning) |
| `max.partition.fetch.bytes` | 1 MiB, 4 MiB | per-partition fetch cap |
| `session.timeout.ms` / `heartbeat.interval.ms` | leave defaults | rebalance behaviour during k6 ramp |

### k6 against Strimzi — the canonical pattern

k6's official `k6/x/kafka` extension (`xk6-kafka`) talks to the Strimzi `internal` listener directly. Run the k6 pod on a **non-broker** node pool. Use the **`shared-iterations`** or **`ramping-arrival-rate`** executor for headline measurement.

```js
import { Writer, Reader, SchemaRegistry, SCHEMA_TYPE_STRING } from "k6/x/kafka";

const writer = new Writer({
  brokers: ["hex-perf-kafka-bootstrap.kafka-perf.svc:9092"],
  topic: "hex-perf-events",
  autoCreateTopic: false,
  compression: "lz4",
  batchSize: 1000,
  batchTimeout: "20ms",
  requiredAcks: -1,                 // acks=all
  maxAttempts: 3,
});

export const options = {
  scenarios: {
    rampToPeak: {
      executor: "ramping-arrival-rate",
      startRate: 100,
      timeUnit: "1s",
      preAllocatedVUs: 50,
      maxVUs: 500,
      stages: [
        { target: 1000, duration: "1m" },
        { target: 5000, duration: "2m" },
        { target: 5000, duration: "5m" },   // sustain at peak — read CPU here
      ],
    },
  },
};

export default function () {
  writer.produce({
    messages: [{ key: "k", value: JSON.stringify({ ts: Date.now(), payload: "x".repeat(512) }) }],
  });
}
```

**Read saturation at minute 6**, not minute 1. The first three minutes are warm-up.

### The Kafka ladder template (mirror of the PG ladder doctrine)

| Tier | Brokers | Per-broker shape | `brokerCapacity` | Expected target |
|------|---------|------------------|------------------|-----------------|
| Bronze | 3 | 2 vCPU / 8 GiB / 250Gi gp3 | cpu=2, in=50MiB/s, out=50MiB/s | dev / smoke |
| Silver | 3 | 4 vCPU / 16 GiB / 500Gi premium | cpu=4, in=100MiB/s, out=100MiB/s | early staging |
| Gold | 6 | 4 vCPU / 16 GiB / 500Gi premium | cpu=4, in=100MiB/s, out=100MiB/s | typical prod |
| Platinum | 6 | 8 vCPU / 32 GiB / 1Ti premium | cpu=8, in=200MiB/s, out=200MiB/s | high-throughput prod |
| Platinum+ | 9 | 8 vCPU / 32 GiB / 1Ti premium | cpu=8, in=200MiB/s, out=200MiB/s | peak / multi-tenant |

Each step is **2× the offered load at in-band saturation** if the workload is broker-bound. If a step yields only +20–30%, the bottleneck is elsewhere (perf-client CPU, network path, ClusterIP saturation, single-partition hot-key) — see companion skill `db-tier-saturation-band-methodology` for the cross-engine mental model.

### Common bottleneck ladder

| Symptom | First hypothesis | Next probe |
|---------|------------------|------------|
| Throughput plateau, broker CPU < 50% | network in/out, or perf-client CPU | `kubectl top` perf pods; raise k6 VU pool |
| Throughput plateau, broker CPU 80%+ | broker CPU is the cap | step up tier OR raise `num.io.threads` |
| Producer p99 latency cliff but throughput still rising | log-flush disk | step up `storageClass` provisioned IOPS |
| Under-replicated partitions appear under load | replica fetcher starvation | raise `num.replica.fetchers` |
| Consumer lag grows linearly | partitions << consumer fleet | raise `KafkaTopic.spec.partitions` (offline preparation) |
| Throughput cliff at exactly the same RPS across cluster sizes | upstream of cluster (k6 pool, ClusterIP, conntrack) | step k6 fleet onto a bigger node pool |

### `hex-scaffold` integration notes

The user's `Hex.Scaffold` solution wires Kafka in two adapters:

- **`Hex.Scaffold.Adapters.Inbound`** — Kafka consumer as a `BackgroundService`. For perf testing it as a consumer:
  - Scale via Helm `replicaCount`; HPA target on `process_cpu_usage` (NOT request-rate — consumers don't take HTTP requests).
  - `KafkaTopic.spec.partitions` ≥ 2 × max replicas — otherwise extra replicas idle.
  - Consumer `max.poll.records` is the back-pressure knob; pair with `fetch.min.bytes` for batch coalescing.
- **`Hex.Scaffold.Adapters.Outbound`** — `Confluent.Kafka` producer wrapped behind the outbound port:
  - Set `acks=all` for the headline; idempotence stays on by default in modern Confluent.Kafka.
  - `linger.ms=20`, `batch.size=65536`, `compression.type=lz4` is the throughput-friendly default to start from.
  - Reuse a single `IProducer<TKey,TValue>` per process (singleton-scoped DI registration) — re-creating per-call destroys the broker-side connection pool.

The `cruiseControl.brokerCapacity` numbers in the perf tier overlay (`tests/loadtest/k6/values-kafka-*.yaml`) MUST mirror the `KafkaNodePool` resource limits selected for that tier — don't copy a Bronze overlay's capacity into a Platinum cluster.

---

## REFERENCE EXAMPLES FROM STRIMZI 1.0.0

The patterns below are transcribed from the **upstream `examples/` directory at the [`1.0.0` tag](https://github.com/strimzi/strimzi-kafka-operator/tree/1.0.0/examples)**. They are the minimum-viable shapes the Cluster Operator accepts; production deployments still need the resource limits, JVM tuning, rack awareness, and `brokerCapacity` covered earlier in this skill. **Use these as the canonical schema reference and bolt the perf-grade overlays from this skill on top.**

### Canonical KRaft cluster — split node pools, persistent JBOD

Source: `examples/kafka/kafka-persistent.yaml`. Shows the **two-CR-plus-cluster** pattern that is mandatory in 1.0.0+. Note `kraftMetadata: shared` on the volume that carries the KRaft metadata log — required when storage is `jbod`.

```yaml
apiVersion: kafka.strimzi.io/v1
kind: KafkaNodePool
metadata:
  name: controller
  labels:
    strimzi.io/cluster: my-cluster
spec:
  replicas: 3
  roles: [controller]
  storage:
    type: jbod
    volumes:
      - id: 0
        type: persistent-claim
        size: 100Gi
        kraftMetadata: shared
---
apiVersion: kafka.strimzi.io/v1
kind: KafkaNodePool
metadata:
  name: broker
  labels:
    strimzi.io/cluster: my-cluster
spec:
  replicas: 3
  roles: [broker]
  storage:
    type: jbod
    volumes:
      - id: 0
        type: persistent-claim
        size: 100Gi
        kraftMetadata: shared
---
apiVersion: kafka.strimzi.io/v1
kind: Kafka
metadata:
  name: my-cluster
spec:
  kafka:
    version: 4.2.0
    metadataVersion: 4.2-IV1
    listeners:
      - { name: plain, port: 9092, type: internal, tls: false }
      - { name: tls,   port: 9093, type: internal, tls: true  }
    config:
      offsets.topic.replication.factor: 3
      transaction.state.log.replication.factor: 3
      transaction.state.log.min.isr: 2
      default.replication.factor: 3
      min.insync.replicas: 2
  entityOperator:
    topicOperator: {}
    userOperator: {}
```

### Multi-volume JBOD broker

Source: `examples/kafka/kafka-jbod.yaml`. Two volumes per broker — `kraftMetadata: shared` MUST stay on exactly one. Pair with `KafkaRebalance.mode: remove-disks` for safe volume drain.

```yaml
spec:
  replicas: 3
  roles: [broker]
  storage:
    type: jbod
    volumes:
      - id: 0
        type: persistent-claim
        size: 100Gi
        kraftMetadata: shared    # KRaft metadata lives here
      - id: 1
        type: persistent-claim
        size: 100Gi              # additional log capacity
```

### Combined-role nodes — DEV ONLY

Source: `examples/kafka/kafka-with-dual-role-nodes.yaml`. Single pool, `roles: [controller, broker]`, three replicas. **Forbidden for any cluster that will be perf-tested or run in prod** — controller I/O contaminates broker CPU saturation readings.

### Cruise Control — minimal vs goals-tuned

Source: `examples/cruise-control/kafka-cruise-control.yaml` shows the absolute minimum: **`cruiseControl: {}`**. The operator deploys CC with defaults. Add `brokerCapacity` (per the API contract earlier in this skill) before using CC for serious capacity planning — the empty form lets CC operate with internal defaults that may not reflect your real broker capacity.

Source: `examples/cruise-control/kafka-cruise-control-with-goals.yaml` — explicit goal lists. Keys go under `spec.cruiseControl.config`:

```yaml
cruiseControl:
  config:
    # `goals` MUST be a superset of `default.goals`, which MUST be a superset of `hard.goals`.
    goals: >
      com.linkedin.kafka.cruisecontrol.analyzer.goals.RackAwareGoal,
      com.linkedin.kafka.cruisecontrol.analyzer.goals.MinTopicLeadersPerBrokerGoal,
      com.linkedin.kafka.cruisecontrol.analyzer.goals.ReplicaCapacityGoal,
      com.linkedin.kafka.cruisecontrol.analyzer.goals.DiskCapacityGoal,
      com.linkedin.kafka.cruisecontrol.analyzer.goals.NetworkInboundCapacityGoal,
      com.linkedin.kafka.cruisecontrol.analyzer.goals.NetworkOutboundCapacityGoal,
      com.linkedin.kafka.cruisecontrol.analyzer.goals.CpuCapacityGoal,
      com.linkedin.kafka.cruisecontrol.analyzer.goals.ReplicaDistributionGoal,
      com.linkedin.kafka.cruisecontrol.analyzer.goals.PotentialNwOutGoal,
      com.linkedin.kafka.cruisecontrol.analyzer.goals.DiskUsageDistributionGoal,
      com.linkedin.kafka.cruisecontrol.analyzer.goals.NetworkInboundUsageDistributionGoal,
      com.linkedin.kafka.cruisecontrol.analyzer.goals.NetworkOutboundUsageDistributionGoal,
      com.linkedin.kafka.cruisecontrol.analyzer.goals.CpuUsageDistributionGoal,
      com.linkedin.kafka.cruisecontrol.analyzer.goals.TopicReplicaDistributionGoal,
      com.linkedin.kafka.cruisecontrol.analyzer.goals.LeaderReplicaDistributionGoal,
      com.linkedin.kafka.cruisecontrol.analyzer.goals.LeaderBytesInDistributionGoal,
    default.goals: >
      com.linkedin.kafka.cruisecontrol.analyzer.goals.RackAwareGoal,
      com.linkedin.kafka.cruisecontrol.analyzer.goals.ReplicaCapacityGoal,
      com.linkedin.kafka.cruisecontrol.analyzer.goals.DiskCapacityGoal
    hard.goals: >
      com.linkedin.kafka.cruisecontrol.analyzer.goals.RackAwareGoal,
      com.linkedin.kafka.cruisecontrol.analyzer.goals.ReplicaCapacityGoal,
      com.linkedin.kafka.cruisecontrol.analyzer.goals.DiskCapacityGoal
```

The **superset rule** is invariant: `goals ⊇ default.goals ⊇ hard.goals`. Cruise Control rejects an inconsistent config silently in some versions — assert it in CI.

### Auto-rebalance via `KafkaRebalance` templates (1.0.0+)

Source: `examples/cruise-control/kafka-cruise-control-auto-rebalancing.yaml`. New in recent Strimzi: link broker scale-up/down events to pre-declared `KafkaRebalance` template resources (annotated `strimzi.io/rebalance-template: "true"`). The operator clones the template into a real `KafkaRebalance` whenever brokers are added or removed.

```yaml
spec:
  cruiseControl:
    autoRebalance:
      - mode: add-brokers
        template:
          name: my-add-brokers-rebalancing-template
      - mode: remove-brokers
        template:
          name: my-remove-brokers-rebalancing-template
---
apiVersion: kafka.strimzi.io/v1
kind: KafkaRebalance
metadata:
  name: my-add-brokers-rebalancing-template
  labels:
    strimzi.io/cluster: my-cluster
  annotations:
    strimzi.io/rebalance-template: "true"
spec: {}    # empty body → uses default goals
---
apiVersion: kafka.strimzi.io/v1
kind: KafkaRebalance
metadata:
  name: my-remove-brokers-rebalancing-template
  labels:
    strimzi.io/cluster: my-cluster
  annotations:
    strimzi.io/rebalance-template: "true"
spec: {}
```

**Why this matters for perf testing.** When you scale brokers up or down between tier-ladder runs, auto-rebalance removes the manual "approve KafkaRebalance, wait for ProposalReady, annotate to execute" dance. The cluster heals itself between runs.

### `KafkaRebalance` modes — verbatim from 1.0.0 examples

```yaml
# examples/cruise-control/kafka-rebalance-full.yaml
apiVersion: kafka.strimzi.io/v1
kind: KafkaRebalance
metadata:
  name: my-rebalance
  labels: { strimzi.io/cluster: my-cluster }
spec:
  mode: full
```

```yaml
# examples/cruise-control/kafka-rebalance-add-brokers.yaml
apiVersion: kafka.strimzi.io/v1
kind: KafkaRebalance
metadata:
  name: my-rebalance
  labels: { strimzi.io/cluster: my-cluster }
spec:
  mode: add-brokers
  brokers: [3, 4]
```

```yaml
# examples/cruise-control/kafka-rebalance-remove-disks.yaml
apiVersion: kafka.strimzi.io/v1
kind: KafkaRebalance
metadata:
  name: my-rebalance
  labels: { strimzi.io/cluster: my-cluster }
spec:
  mode: remove-disks
  moveReplicasOffVolumes:
    - brokerId: 0
      volumeIds: [1]
```

```yaml
# examples/cruise-control/kafka-rebalance-with-goals.yaml
apiVersion: kafka.strimzi.io/v1
kind: KafkaRebalance
metadata:
  name: my-rebalance
  labels: { strimzi.io/cluster: my-cluster }
spec:
  goals:
    - CpuCapacityGoal
    - NetworkInboundCapacityGoal
    - DiskCapacityGoal
    - RackAwareGoal
    - MinTopicLeadersPerBrokerGoal
    - NetworkOutboundCapacityGoal
    - ReplicaCapacityGoal
```

**Naming asymmetry — confirmed by the 1.0.0 examples.** `cruiseControl.config.{goals, default.goals, hard.goals}` use **fully-qualified class names** (`com.linkedin.kafka.cruisecontrol.analyzer.goals.RackAwareGoal`). `KafkaRebalance.spec.goals` accepts the **short names** (`RackAwareGoal`). These two surfaces are not interchangeable — never copy-paste between them.

### Metrics — JMX exporter ConfigMap pattern + `kafkaExporter`

Source: `examples/metrics/kafka-metrics.yaml` shows the canonical wiring. Two new things vs the simpler example earlier in this skill:

1. **`kafkaExporter`** — a sidecar that emits topic / consumer-group lag metrics on its own. Cheap to add, invaluable during perf testing for spotting consumer-lag explosion.
2. The JMX exporter rules block — copy verbatim, don't roll your own.

```yaml
spec:
  kafka:
    metricsConfig:
      type: jmxPrometheusExporter
      valueFrom:
        configMapKeyRef:
          name: kafka-metrics
          key: kafka-metrics-config.yml
  kafkaExporter:
    topicRegex: ".*"
    groupRegex: ".*"
---
kind: ConfigMap
apiVersion: v1
metadata:
  name: kafka-metrics
  labels: { app: strimzi }
data:
  kafka-metrics-config.yml: |
    lowercaseOutputName: true
    rules:
      - pattern: kafka.server<type=(.+), name=(.+), clientId=(.+), topic=(.+), partition=(.*)><>Value
        name: kafka_server_$1_$2
        type: GAUGE
        labels:
          clientId: "$3"
          topic: "$4"
          partition: "$5"
      - pattern: kafka.server<type=(.+), name=(.+), clientId=(.+), brokerHost=(.+), brokerPort=(.+)><>Value
        name: kafka_server_$1_$2
        type: GAUGE
        labels:
          clientId: "$3"
          broker: "$4:$5"
      - pattern: "kafka.server<type=raft-metrics><>(.+-total|.+-max):"
        name: kafka_server_raftmetrics_$1
        type: COUNTER
      - pattern: "kafka.server<type=raft-metrics><>(current-state): (.+)"
        name: kafka_server_raftmetrics_$1
        value: 1
        type: UNTYPED
        labels:
          $1: "$2"
```

Cruise Control gets its own minimal ConfigMap — source `examples/metrics/kafka-cruise-control-metrics.yaml`:

```yaml
kind: ConfigMap
apiVersion: v1
metadata:
  name: cruise-control-metrics
  labels: { app: strimzi }
data:
  metrics-config.yml: |
    lowercaseOutputName: true
    rules:
      - pattern: kafka.cruisecontrol<name=(.+)><>(\w+)
        name: kafka_cruisecontrol_$1_$2
        type: GAUGE
```

### KafkaUser — TLS auth + ACLs (verbatim 1.0.0 shape)

Source: `examples/user/kafka-user.yaml`. Note the tripartite ACL split: consumer needs `topic` + `group` rules; producer needs `topic` + `Create`/`Write`. **Quotas are intentionally absent in the upstream example** — same rule applies in this skill: quotas off during synthetic perf measurement.

```yaml
apiVersion: kafka.strimzi.io/v1
kind: KafkaUser
metadata:
  name: my-user
  labels: { strimzi.io/cluster: my-cluster }
spec:
  authentication: { type: tls }
  authorization:
    type: simple
    acls:
      # Consumer: topic Describe+Read, group Read
      - resource: { type: topic, name: my-topic, patternType: literal }
        operations: [Describe, Read]
        host: "*"
      - resource: { type: group, name: my-group, patternType: literal }
        operations: [Read]
        host: "*"
      # Producer: topic Create+Describe+Write
      - resource: { type: topic, name: my-topic, patternType: literal }
        operations: [Create, Describe, Write]
        host: "*"
```

### KafkaTopic — minimum form (verbatim)

Source: `examples/topic/kafka-topic.yaml`. The 1.0.0 example is **deliberately minimal** — single partition, single replica, two-hour retention, 1 GiB segments. **Do not copy the partition/replica numbers for prod or perf** — they're a starting placeholder, not a recommendation. Use the perf-test sizing rule from this skill (`partitions ≥ 2 × consumer-fleet CPU cores`, `replicas: 3`, `min.insync.replicas: 2`).

```yaml
apiVersion: kafka.strimzi.io/v1
kind: KafkaTopic
metadata:
  name: my-topic
  labels: { strimzi.io/cluster: my-cluster }
spec:
  partitions: 1
  replicas: 1
  config:
    retention.ms: 7200000        # 2 hours
    segment.bytes: 1073741824    # 1 GiB
```

### KafkaConnect — bootstrap + image-build

Source: `examples/connect/kafka-connect.yaml` and `kafka-connect-build.yaml`. The base `KafkaConnect` always references the broker's TLS bootstrap and the cluster CA secret; `replication.factor: -1` lets each Connect storage topic inherit the broker default rather than hardcoding.

```yaml
apiVersion: kafka.strimzi.io/v1
kind: KafkaConnect
metadata:
  name: my-connect-cluster
  # Uncomment to drive connectors via KafkaConnector CRs (no REST API)
  # annotations:
  #   strimzi.io/use-connector-resources: "true"
spec:
  version: 4.2.0
  replicas: 1
  bootstrapServers: my-cluster-kafka-bootstrap:9093
  groupId: my-connect-group
  configStorageTopic: my-connect-configs
  statusStorageTopic: my-connect-status
  offsetStorageTopic: my-connect-offsets
  tls:
    trustedCertificates:
      - secretName: my-cluster-cluster-ca-cert
        pattern: "*.crt"
  config:
    config.storage.replication.factor: -1     # inherit broker default
    offset.storage.replication.factor: -1
    status.storage.replication.factor: -1
```

To bake plugins into a derived image, add a `build` block — Strimzi materialises a Dockerfile and pushes the result to your registry:

```yaml
spec:
  # ... base spec as above ...
  build:
    output:
      type: docker
      image: ttl.sh/strimzi-connect-example-4.2.0:24h
    plugins:
      - name: kafka-connect-file
        artifacts:
          - type: maven
            group: org.apache.kafka
            artifact: connect-file
            version: 4.2.0
```

### KafkaMirrorMaker2 — 1.0.0 shape (top-level `target` + per-mirror `source`)

Source: `examples/mirror-maker/kafka-mirror-maker-2.yaml`. The 1.0.0 layout is **`target` at the top level** and each `mirrors[]` entry carrying its own `source` block — clearer than the older `clusters[]` pattern.

```yaml
apiVersion: kafka.strimzi.io/v1
kind: KafkaMirrorMaker2
metadata:
  name: my-mirror-maker-2
spec:
  version: 4.2.0
  replicas: 1
  target:
    alias: cluster-b
    bootstrapServers: cluster-b-kafka-bootstrap:9092
    groupId: my-mirror-maker-2-group
    configStorageTopic: my-mirror-maker-2-config
    offsetStorageTopic: my-mirror-maker-2-offset
    statusStorageTopic: my-mirror-maker-2-status
    config:
      config.storage.replication.factor: -1
      offset.storage.replication.factor: -1
      status.storage.replication.factor: -1
  mirrors:
    - source:
        bootstrapServers: cluster-a-kafka-bootstrap:9092
        alias: cluster-a
      sourceConnector:
        tasksMax: 1
        config:
          replication.factor: -1
          offset-syncs.topic.replication.factor: -1
          sync.topic.acls.enabled: "false"
          refresh.topics.interval.seconds: 600
      checkpointConnector:
        tasksMax: 1
        config:
          checkpoints.topic.replication.factor: -1
          sync.group.offsets.enabled: "false"
          refresh.groups.interval.seconds: 600
      topicsPattern: ".*"
      groupsPattern: ".*"
```

### KafkaBridge — minimum form

Source: `examples/bridge/kafka-bridge.yaml`. The upstream example is **deliberately tiny** — replicas, bootstrapServers, http.port. No CORS, no consumer/producer config block. Add those only when a specific consumer or test fixture demands it.

```yaml
apiVersion: kafka.strimzi.io/v1
kind: KafkaBridge
metadata:
  name: my-bridge
spec:
  replicas: 1
  bootstrapServers: my-cluster-kafka-bootstrap:9092
  http:
    port: 8080
```

### What's NOT in the 1.0.0 examples (and why it matters)

- **No `brokerCapacity` populated** — even the CC examples use `cruiseControl: {}` or only `cruiseControl.config.*`. The schema absolutely supports `brokerCapacity` (verified against the `BrokerCapacity` Java class on `main`); the upstream just doesn't bother for didactic minimality. **Always populate `brokerCapacity` for any cluster that will be perf-tested.**
- **No `resources` blocks on the `KafkaNodePool`s** — so the upstream pods are `BestEffort` QoS, throttleable, unsuited for measurement. **Always set `requests == limits` for perf clusters.**
- **No `rack` block** — examples are single-zone. **Add `spec.kafka.rack.topologyKey: topology.kubernetes.io/zone` for any multi-zone cluster.**
- **No `metricsConfig` on the controller pool** — only on the broker tier and on Cruise Control. Controllers in KRaft mode are quiet relative to brokers; if you want metadata-quorum metrics, add JMX scraping to the controller pool too.
- **`replicas: 1` on Connect / MirrorMaker2 / Bridge** — fine for a smoke example, **never for prod**. Production: ≥ 2 replicas with anti-affinity.

The 1.0.0 examples are **schema reference**, not **deployment reference**. This skill is the deployment reference.

---

## ANTI-PATTERNS

| Anti-pattern | Why it breaks |
|--------------|---------------|
| Single `KafkaNodePool` with combined `[controller, broker]` roles in a perf cluster | controller I/O competes with broker I/O; CPU saturation reading is contaminated |
| ZooKeeper-mode cluster on a fresh install | KRaft is the only supported mode for Kafka 4.0+ — migrate immediately |
| `cruiseControl.brokerCapacity.cpu` not equal to `resources.limits.cpu` | Cruise Control plans rebalances against headroom that doesn't exist |
| `inboundNetwork: 100MB/s` written when meaning `100MiB/s` | unit drift; goal evaluation off by ~5% silently |
| `loadbalancer` listener used for in-cluster perf tests | adds 1–3 ms / 5–15% throughput overhead vs `internal` |
| `tls: true` + `authentication: scram-sha-512` on the headline run | bundles security overhead into the topline number; can't separate later |
| `KafkaUser.spec.quotas` set during perf | silently caps measured throughput |
| `ephemeral` storage on a "production-ish" cluster | data loss on co-restart, hidden by RF=3 until the second pod restarts |
| `KafkaTopic.spec.partitions = 1` for a perf topic | parallelism ceiling = 1 consumer; no fan-out |
| `min.insync.replicas: 1` with `acks=all` | undermines `acks=all`; you measure async-write throughput unintentionally |
| Heap (`-Xmx`) set to 90% of `resources.limits.memory` | starves page cache; throughput collapses despite huge heap |
| Skipping `KafkaRebalance` after broker scale-out | hot brokers carry skewed leadership; perf measures imbalance, not capacity |
| `PodDisruptionBudget` missing or `maxUnavailable: 0` | drain stalls forever or evicts brokers unsafely (depending on Drain Cleaner) |
| Auto-create topics on (`auto.create.topics.enable: true`) on a `KafkaTopic`-managed cluster | drift between Kafka state and CR state — operator constantly fights you |
| `jbod` storage with no volume tagged `kraftMetadata: shared` | KRaft metadata log has no home — operator rejects the spec or behaviour is undefined on upgrade |
| `KafkaRebalance.spec.mode: rebalance-disks` (legacy form) | renamed in 1.0.0 — use `mode: remove-disks` with `moveReplicasOffVolumes: [{ brokerId, volumeIds }]` |
| Manual `kafka-topics --alter` on a Topic-Operator-managed cluster | unidirectional Topic Operator overwrites the change on next reconcile |
| Cluster Operator `replicas: 1` for non-toy environments | operator-down window causes reconciliation outages during rolling updates |
| Cruise Control disabled on multi-broker clusters | manual rebalance is the only way to recover from skew → high MTTR |

---

## PRE-DONE VERIFICATION CHECKLIST

Before declaring "Strimzi cluster ready" / "Kafka perf run reproducible" / "tier-ladder updated", every box below MUST be ticked:

### Operator surface
- [ ] Cluster Operator `replicas ≥ 2` with leader-election logs visible
- [ ] `STRIMZI_NAMESPACE` scoped (no accidental global watch)
- [ ] CRDs at the same version as the operator image
- [ ] Drain Cleaner deployed (cluster ≥ 2 brokers)

### `Kafka` CR
- [ ] `strimzi.io/kraft: enabled` annotation present
- [ ] `version` and `metadataVersion` aligned
- [ ] Two listeners: `internal` (plaintext) + `tls` (TLS)
- [ ] `entityOperator.topicOperator` and `userOperator` configured
- [ ] `metricsConfig` references the `kafka-metrics` ConfigMap
- [ ] `cruiseControl.metricsConfig` references the `cruise-control-metrics` ConfigMap
- [ ] `cruiseControl.brokerCapacity.cpu` == `KafkaNodePool.spec.resources.limits.cpu`
- [ ] `cruiseControl.brokerCapacity.{inboundNetwork,outboundNetwork}` match node NIC realistic ceiling
- [ ] `spec.kafka.rack.topologyKey` set on multi-zone clusters

### `KafkaNodePool` (controllers)
- [ ] `replicas: 3` (or 5 for very large clusters)
- [ ] `roles: [controller]` (NEVER combined with broker for perf)
- [ ] `storage.type: persistent-claim`, `class: <perf-grade>`, size ≥ 20Gi
- [ ] `podAntiAffinity` requiredDuringScheduling on `kubernetes.io/hostname`
- [ ] `resources.requests` == `resources.limits` (Guaranteed QoS)

### `KafkaNodePool` (brokers)
- [ ] `roles: [broker]` only
- [ ] `storage` is `persistent-claim` or `jbod`, **never** `ephemeral`
- [ ] `storageClass` is the perf-grade NVMe class
- [ ] `resources.requests` == `resources.limits`
- [ ] `jvmOptions.-Xms` == `-Xmx` ≤ 50% of `resources.limits.memory`
- [ ] G1GC with `MaxGCPauseMillis: 20` (or rationale documented)
- [ ] `podAntiAffinity` required on `kubernetes.io/hostname`
- [ ] Optional `nodeAffinity` to a dedicated broker nodepool

### Topics & Users
- [ ] `KafkaTopic` per perf topic with `replicas: 3`, `min.insync.replicas: 2`
- [ ] `partitions ≥ 2 × peak consumer-fleet CPU cores`
- [ ] `KafkaUser` with TLS or SCRAM-SHA-512, ACLs scoped to `hex-perf-` prefix
- [ ] **Quotas OFF** on the perf user

### Observability
- [ ] JMX exporter scraped at port 9404 in Prometheus
- [ ] Strimzi Grafana dashboards loaded
- [ ] Four headline panels (CPU per broker, in/out per broker, log-flush p99) showing live data **before** firing k6

### Pre-test
- [ ] `KafkaRebalance mode: full` completed (`status.conditions[?(@.type=="Ready")].status == True`)
- [ ] PodDisruptionBudget present, `maxUnavailable: 1`
- [ ] Perf-client pods on a separate node pool from brokers
- [ ] k6 / kafka-producer-perf-test config sweeps `acks` / `linger.ms` / `batch.size` / `compression.type`
- [ ] Listener selected: `internal` + `tls: false` for headline; separate run for TLS overhead

### Result
- [ ] First-saturating resource identified (CPU / network in / network out / log disk)
- [ ] Saturation reading inside 60–80% band at target offered load
- [ ] Tier-ladder doc updated with peak RPS, p99, saturation level, step ratio vs previous tier
- [ ] No under-replicated partitions during the steady-state window
- [ ] Cruise Control reported no anomalies during the run

If any box is unticked, the run is **not** reportable as a tier-ladder data point — re-run after closing the gap.

<!-- MANUAL: -->
