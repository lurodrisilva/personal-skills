---
name: opencost
description: >-
  MUST USE when installing, configuring, querying, integrating, extending, or
  troubleshooting **OpenCost** — the CNCF vendor-neutral open-source project that
  measures and allocates Kubernetes and cloud infrastructure cost, and the
  reference implementation of the **OpenCost Specification**. Owns the OpenCost
  *product surface*: **deployment** (Helm chart `opencost-charts/opencost`, raw
  manifest, `ghcr.io/opencost/opencost` + `opencost-ui` containers, the
  Prometheus-exporter-only chart `prometheus-community/prometheus-opencost-exporter`,
  the KubeStellar Console **guided install**, the Tilt + kind **development** loop,
  the `--namespace opencost` convention, port **9003** = API + `/metrics` and port
  **9090** = UI), **Prometheus wiring** (the `job_name: opencost` scrape config,
  `extraScrapeConfigs.yaml`, the metrics OpenCost emits — `node_cpu_hourly_cost` /
  `node_ram_hourly_cost` / `node_gpu_hourly_cost` / `node_total_hourly_cost` /
  `container_cpu_allocation` / `container_memory_allocation_bytes` /
  `pod_pvc_allocation` / `pv_hourly_cost` / `kubecost_load_balancer_cost` /
  `kubecost_node_is_spot` / `kubecost_network_*_egress_cost` — and the
  kube-state-metrics + node-exporter series it consumes), **multi-cluster
  single-source-of-data** (one OpenCost per cluster against a shared
  Thanos/Cortex/Mimir, `CURRENT_CLUSTER_ID_FILTER_ENABLED` /
  `PROM_CLUSTER_ID_LABEL` / `CLUSTER_ID`), **cloud pricing configuration** (the
  `cloud-integration.json` contract and the `cloud-costs` secret — AWS Athena/CUR,
  Azure storage-export + RateCard, GCP BigQuery billing export, OCI; the
  `authorizerType` values `AWSAccessKey` / `AzureAccessKey` /
  `GCPServiceAccountKey` / `GCPWorkloadIdentity`; IRSA + GKE Workload Identity; and
  **custom / on-prem pricing** via `opencost.customPricing.costModel`), the **HTTP
  API** (`/allocation`, `/allocation/compute`, `/assets`, `/cloudCost`,
  `/customCost/total`, `/customCost/timeseries` and every query parameter —
  `window` / `aggregate` / `step` / `resolution` / `accumulate` / `includeIdle` /
  `shareIdle` / `idleByNode` / `filter`), **integrations & exports**
  (`kubectl cost` krew plugin, CSV export via `EXPORT_CSV_FILE`, the Parquet
  exporter CronJob, carbon costs in KG CO2e), the **plugin framework**
  (`PLUGIN_EXECUTABLE_DIR` / `PLUGIN_CONFIG_DIR` / `CUSTOM_COST_ENABLED`,
  `plugins.enabledPlugins`, and the Datadog / OpenAI / MongoDB-Atlas plugins), the
  **OpenCost MCP server** (HTTP on **8081**, tools `get_allocation_costs` /
  `get_asset_costs` / `get_cloud_costs`), the **developer APIs** (diagnostics /
  storage / export — Go interfaces, not REST), and **troubleshooting** (500 from
  the allocation API, negative idle, missing cloud-cost integrations, the
  `/logs/level` debug toggle). Use for — "opencost", "install opencost", "opencost
  helm chart", "opencost values.yaml", "opencost prometheus scrape config",
  "allocation api", "/allocation window aggregate", "opencost assets api",
  "cloudCost api", "customCost", "cloud-integration.json", "cloud-costs secret",
  "opencost aws athena", "opencost azure rate card", "opencost gcp bigquery
  billing export", "GCPWorkloadIdentity", "opencost custom pricing", "on-prem
  kubernetes cost", "kubectl cost", "kubectl krew install cost", "opencost csv
  export", "opencost parquet export", "opencost carbon costs", "opencost plugin",
  "datadog plugin opencost", "opencost mcp", "opencost exporter", "node_cpu_hourly_cost",
  "container_cpu_allocation", "opencost negative idle", "opencost 500 allocation",
  "opencost multi-cluster", "opencost vs kubecost", "opencost guided install",
  "kubestellar console opencost", "opencost tilt", "develop on opencost". Triggers on surfaces — the
  `opencost` namespace, `values.yaml` keys under `opencost.*`, `cloud-integration.json`,
  the `cloud-costs` secret, port `9003`/`9090`/`8081`, `ghcr.io/opencost/*` images.
  Scope boundary — the **FinOps practice on Kubernetes** (right-sizing requests,
  VPA/Goldilocks/KRR, HPA/KEDA, bin-packing, waste elimination, ResourceQuota /
  LimitRange governance, showback → chargeback maturity) →
  `../../operations/kubernetes-finops/`; **node-lifecycle autoscaling** →
  `../../operations/karpenter-operations/`; **the cloud invoice, reservations and
  savings plans** → `aws-finops` / `azure-finops`; **generic cluster ops** →
  `../../operations/kubernetes-operations/`. This skill owns the **measurement
  plane**: standing OpenCost up, pricing it correctly, and getting trustworthy
  numbers out of it. Authored as an OpenCost operator's playbook — no cost number
  is trustworthy until its pricing source is known, allocation reads
  `max(request, usage)`, and every OpenCost read is read-only. **OpenCost moves
  fast: state behavior, pin no version in guidance, and verify every flag, key,
  and endpoint against opencost.io and the opencost/opencost repository before
  relying on it.**
license: BSD-3-Clause
compatibility: opencode
metadata:
  domain: platform-engineering
  platform: kubernetes
  scope: cross-cloud
  discipline: finops
  project: opencost
  foundation: cncf
  spec: opencost-specification
  tooling: opencost, prometheus, helm, kubectl-cost, thanos, mimir, parquet, mcp
  clouds: aws, azure, gcp, oci, on-prem
  capabilities: deployment, prometheus-wiring, cloud-pricing, allocation-api, exports, plugins, mcp, troubleshooting
  use_cases: cost-allocation, cost-visibility, multi-cluster-cost, custom-pricing, cost-export, carbon-estimates
---

# OpenCost

You are operating **OpenCost** — the CNCF **vendor-neutral open source project for
measuring and allocating Kubernetes and cloud infrastructure costs**, and the
reference implementation of the **OpenCost Specification** for AWS, Azure, GCP, OCI,
and on-prem clusters.

OpenCost is a **measurement plane**, not an optimizer. It answers one question well:
*what did this workload cost, and where did that number come from?* Everything
downstream — right-sizing, chargeback, budgets — is only as trustworthy as the
pricing source and the allocation window behind that number.

**The mental model.** OpenCost joins three inputs and serves one answer:

```
   Kubernetes API  ──┐   (what ran, what it requested, for how long)
   Prometheus      ──┼──►  OpenCost  ──►  /allocation  ·  /assets  ·  /cloudCost
   Cloud billing   ──┘        │            (+ :9003/metrics back into Prometheus)
   (or custom pricing)        │
                              └── UI :9090 · MCP :8081 · CSV/Parquet export · kubectl cost
```

- **Kubernetes** supplies the workload inventory (pods, requests, PVCs, controllers).
- **Prometheus** supplies the time series — both the metrics OpenCost *emits* about
  price and allocation, and the **kube-state-metrics** / **node-exporter** series it
  *consumes*. OpenCost writes cost metrics into Prometheus and reads history back out.
- **Cloud billing** (or a custom pricing sheet) supplies the rates. Without it you get
  **public on-demand list pricing** — a real number, but not *your* number.

> **Scope boundary.**
> - **The FinOps practice on Kubernetes** — right-sizing requests, VPA / Goldilocks /
>   KRR, HPA / KEDA scale-to-zero, bin-packing, waste elimination, ResourceQuota /
>   LimitRange governance, showback → chargeback maturity →
>   `../../operations/kubernetes-finops/`. That skill *decides what to do* about the
>   cost; this one *produces the number* it decides on.
> - **Node-lifecycle autoscaling** (NodePool / NodeClass / consolidation / NAP) →
>   `../../operations/karpenter-operations/`.
> - **The cloud invoice** — reservations, savings plans, commitment coverage, FOCUS
>   rollup → `aws-finops` / `azure-finops`.
> - **Generic cluster ops** — scheduling, capacity, upgrades →
>   `../../operations/kubernetes-operations/`.
> - **Prometheus/Thanos operation itself** (retention, cardinality, recording rules)
>   → `../../operations/observability-stack/`.
> This skill owns **OpenCost the tool**: deploy it, price it, query it, extend it, fix it.

> **Version gate (read first).** OpenCost ships fast and its Helm values, env vars,
> and API parameters change between releases. **State behavior, pin no version in
> guidance, and verify every values key, environment variable, endpoint, and query
> parameter against `opencost.io/docs` and the `opencost/opencost` +
> `opencost/opencost-helm-chart` repositories before relying on it.** Where a value
> below is quoted from the docs, treat it as *the documented shape*, not a guarantee
> for the release you are running — confirm with `helm show values`.

---

## CORE PRINCIPLES (NON-NEGOTIABLE)

1. **A cost number without a known pricing source is a guess.** Before quoting any
   OpenCost figure, know which of the three it came from: **cloud billing
   integration** (your real rates), **public list pricing** (the default — on-demand,
   no discounts), or **custom pricing** (`opencost.customPricing`, for on-prem). Say
   which one. An unlabeled number gets treated as the invoice and it is not.
2. **Allocation is `max(request, usage)`.** The Specification is explicit: *"Workload
   Costs should be understood as `max(request, usage)`"*. A workload is charged for
   what it **reserved** or what it **used**, whichever is greater — per resource. This
   is why over-requesting shows up as cost, and why usage-only dashboards disagree
   with OpenCost.
3. **Idle is a cluster fact, not a workload's.** `Cluster Idle Cost = Cluster Asset
   Costs − Workload Costs`. It belongs to the cluster's bin-packing, not to a tenant —
   until you deliberately choose to redistribute it with `shareIdle=true`. Report
   allocated and idle **separately** before you ever share them.
4. **OpenCost is only as good as its Prometheus.** No scrape target → no history →
   **negative idle**, empty windows, and 500s from `/allocation`. The scrape config is
   not optional plumbing; it is the data path. Verify it before debugging anything else.
5. **Every OpenCost interaction is read-only.** Querying `/allocation`, `/assets`,
   `/cloudCost`, scraping `/metrics`, running `kubectl cost` — all reads. Installing,
   changing pricing, mounting a cloud credential, and enabling a plugin are **gated
   changes** delivered through Git/Helm, not ad-hoc `kubectl edit`. An agent may
   analyze freely; a human approves every mutation.
6. **Credentials are least-privilege and read-only by construction.** Every documented
   cloud integration needs **read** on billing data only — `s3:Get*`/`List*` for Athena,
   `Microsoft.Commerce/RateCard/read` for Azure, `roles/bigquery.dataViewer` for GCP.
   Prefer **IRSA** / **GKE Workload Identity** (`"authorizerType": "GCPWorkloadIdentity"`)
   over a static key in a secret. If you must use a key, it is a mounted secret, never
   a values-file literal in Git.
7. **Multi-cluster needs an explicit cluster identity.** Pointing several OpenCost
   instances at one Thanos/Mimir without `CURRENT_CLUSTER_ID_FILTER_ENABLED` +
   a matching `PROM_CLUSTER_ID_LABEL`/`CLUSTER_ID` silently blends clusters together.
   Attribution is configured, never automatic.
8. **OpenCost ≠ Kubecost.** OpenCost gives real-time monitoring at **on-demand list
   pricing**; Kubecost is the commercial superset that reconciles against the published
   bill with negotiated discounts. Do not promise invoice-accurate reconciliation from
   OpenCost alone — hand that to the cloud FinOps skill.

---

## CAPABILITY MAP — signal / goal → concern → phase → agent

| Signal / goal | Concern | Phase | Agent |
|---|---|---|---|
| "Install OpenCost on this cluster" | Deployment topology | A | `opencost-installer` |
| No Prometheus scrape target / empty data | Prometheus wiring | A | `opencost-installer` |
| Several clusters, one data store | Multi-cluster identity | A | `opencost-installer` |
| Numbers are list price, not our rates | Cloud billing integration | B | `opencost-cloud-integrator` |
| On-prem / bare-metal cluster | Custom pricing sheet | B | `opencost-cloud-integrator` |
| Static keys in the cluster | IRSA / Workload Identity | B | `opencost-cloud-integrator` |
| "Cost per namespace / label / controller" | Allocation API query | C | `opencost-api-analyst` |
| Idle vs allocated vs shared split | Query semantics | C | `opencost-api-analyst` |
| Node / disk / LB level cost | Assets + CloudCost API | C | `opencost-api-analyst` |
| Get the data into a warehouse / BI | CSV + Parquet export | D | `opencost-export-integrator` |
| Non-Kubernetes SaaS spend alongside | Plugin framework | D | `opencost-export-integrator` |
| Carbon / CO2e reporting | Carbon estimates | D | `opencost-export-integrator` |
| Let an agent read cost data | MCP surface | D | `opencost-export-integrator` |
| 500 from `/allocation`, negative idle | Failure triage | E | `opencost-troubleshooter` |
| Prices missing / zero cost nodes | Pricing verification | E | `opencost-troubleshooter` |
| Decide *what to do* about the cost | (hand off) FinOps practice | — | → `kubernetes-finops` |
| Buy the node commitment | (hand off) cloud rate | — | → `aws-finops` / `azure-finops` |

---

## PHASE A — DEPLOY: stand it up and wire Prometheus

**Goal:** an OpenCost that answers `/allocation` with non-empty, non-negative data.

### Prerequisites
- **Kubernetes 1.21+** (the install docs state v1.28 officially supported as of
  v1.105; the FAQ states support above 1.8 — trust the install page and verify for
  your release).
- **Prometheus** — *"OpenCost requires Prometheus for scraping metrics and data
  storage."* The Helm install *"assumes an existing Prometheus installation."*

### Helm (the default path)

```bash
helm repo add opencost-charts https://opencost.github.io/opencost-helm-chart
helm repo update
helm install opencost opencost-charts/opencost \
  --namespace opencost --create-namespace -f values.yaml
# upgrade / uninstall
helm upgrade opencost opencost-charts/opencost --namespace opencost -f values.yaml
helm uninstall opencost
```

The values surface you will actually touch (confirm against
`helm show values opencost-charts/opencost` — this is the documented shape, not a
version guarantee):

```yaml
opencost:
  prometheus:
    internal:
      namespaceName: prometheus-system   # where Prometheus lives
      serviceName: prometheus-server
      port: 9090
  exporter:
    defaultClusterId: my-cluster
    replicas: 1
    resources:
      requests: { cpu: 10m, memory: 55Mi }
      limits:   { memory: 1Gi }
    persistence:
      enabled: false
    image:
      registry: ghcr.io
      repository: opencost/opencost
  dataRetention:
    dailyResolutionDays: 15
  metrics:
    serviceMonitor:
      enabled: false                     # true if you run the Prometheus Operator
  ui:
    enabled: true
```

### Ports — memorize these

| Port | Serves |
|---|---|
| **9003** | OpenCost **API** (`/allocation`, `/assets`, `/cloudCost`, …) **and** `/metrics` |
| **9090** | OpenCost **UI** |
| **8081** | OpenCost **MCP server** (HTTP) |

```bash
kubectl port-forward --namespace opencost service/opencost 9003 9090
# API smoke test — this is the "is it alive" check:
curl -s 'http://localhost:9003/allocation/compute?window=60m' | head
# UI: http://localhost:9090
```

### The Prometheus scrape config (non-optional)

Add this to your Prometheus by whatever means it is managed. **Without it, history
never lands and idle goes negative.**

```yaml
- job_name: opencost
  honor_labels: true
  scrape_interval: 1m
  scrape_timeout: 10s
  metrics_path: /metrics
  scheme: http
  static_configs:
  - targets:
    - < address of opencost service> # example: <service-name>.<namespace>:<port>
```

The project publishes the full set at
`https://raw.githubusercontent.com/opencost/opencost/develop/kubernetes/prometheus/extraScrapeConfigs.yaml`.
Note the docs' own caveat about **overlapping metrics with an existing
kube-state-metrics deployment** — check for duplicate KSM series before adding it.

### The UI

```yaml
opencost:
  ui:
    enabled: true
    ingress:
      enabled: true
      hosts:
        - host: HOSTNAME
          paths: [ / ]
```

```bash
kubectl port-forward --namespace opencost service/opencost 9090 9090
```

### Exporter-only (metrics, no UI, no extras)

When you only want cost metrics in Prometheus and nothing else — *"provides the
Prometheus metric exporter capabilities without the OpenCost UI or any other
additional capabilities."*

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install [RELEASE_NAME] prometheus-community/prometheus-opencost-exporter
# or raw manifest:
kubectl apply --namespace opencost-exporter \
  -f https://raw.githubusercontent.com/opencost/opencost/develop/kubernetes/exporter/opencost-exporter.yaml
```

Scrape it at `opencost.opencost-exporter:9003` with `metrics_path: /metrics`.

### Docker (cloud costs only — no Kubernetes allocation)

```bash
docker run -e CLOUD_COST_ENABLED=true -e CLOUD_COST_CONFIG_PATH=/tmp/cloud-integration.json \
  -p 9003:9003 -d -v /tmp:/tmp ghcr.io/opencost/opencost:<version>
docker run -p 9090:9090 -e API_SERVER=host.docker.internal -d ghcr.io/opencost/opencost-ui:<version>
```

> **Caveat, verbatim:** *"Running OpenCost outside of Kubernetes will give you access
> to your Cloud Costs via the API and UI, but you will not have Kubernetes Cost
> Allocation data available."*

### Guided install (interactive, third-party console)

The docs point at a browser-based guided path: *"KubeStellar Console offers a
browser-based guided installation experience for OpenCost. The guided install mission
walks through each step interactively, running commands against your cluster via your
kubeconfig context."* It adds pre-flight checks, step-by-step commands, post-install
pod validation, troubleshooting hints, and rollback commands, at
`https://console.kubestellar.io/missions/install-opencost`.

**Treat it as an onboarding aid, not the production path.** It is a **third party**
that you connect to your kubeconfig context — review what it runs before approving it,
and prefer it for a first look rather than a cluster you care about. The docs
themselves defer: *"For full control over configuration options, see the Helm
installation guide."* Anything reproducible belongs in Helm values in Git.

### Local development (contributor loop)

The upstream dev loop is **Tilt**-based against a local **kind** cluster — not a
deployment topology, and not something to run against a real cluster. Prerequisites:
Delve (+ IDE plugin), Docker, Go, Helm, kind, kubectl, Node.js, Tilt. The flow is:
add the `prometheus-community` Helm repo, edit `tilt-values.yaml` / `Tiltfile` /
`tilt_config.json`, then `tilt up` at the repo root; tear down with `tilt down` and
`kind delete cluster`. Flags pass through after `--`:

```bash
tilt up -- --arch arm64 --docker-repo dockerhub-username \
  --cloud-integration ../cloud-integration.json --service-key ../service-key.json
```

The debugger attaches at `http://localhost:40000` (default `port-debug`). Use this
only when changing OpenCost itself; for every operational task, use Helm.

### Multi-cluster, single source of data

Architecture, verbatim: *"Deploy one OpenCost instance per Kubernetes cluster. Send
cluster metrics to a shared backend. Configure each OpenCost instance to query the
shared backend."* The shared backend is a Prometheus-compatible query layer —
**Thanos, Cortex, or Mimir**.

Each instance must declare **which cluster it is**:

```yaml
opencost:
  exporter:
    extraEnv:
      CURRENT_CLUSTER_ID_FILTER_ENABLED: "true"
      PROM_CLUSTER_ID_LABEL: "cluster"          # the label KEY your backend uses
      CLUSTER_ID: "<this-cluster-label-value>"  # the label VALUE for this cluster
```

For Prometheus with `externalLabels: { cluster: qa }` → `PROM_CLUSTER_ID_LABEL=cluster`,
`CLUSTER_ID=qa`, `CURRENT_CLUSTER_ID_FILTER_ENABLED=true`.

**The three documented pitfalls:** leaving `PROM_CLUSTER_ID_LABEL` at its default when
the backend uses a different label key; a `CLUSTER_ID` that doesn't match the label
value in the metrics; and assuming multi-cluster attribution happens automatically
without the filter. All three silently blend clusters.

---

## PHASE B — PRICE IT: cloud billing integration and custom pricing

**Goal:** the numbers reflect *your* rates, and you can say which source produced them.

**Default with no integration:** public **on-demand list pricing**. Correct-ish for a
sanity check, wrong for chargeback (no reservations, no savings plans, no negotiated
discount, no spot reconciliation).

### The `cloud-integration.json` contract

One file, one secret, four provider keys:

```json
{ "aws": {}, "azure": {}, "gcp": {}, "oci": {} }
```

Mount it the same way for every provider:

```bash
kubectl create secret generic cloud-costs \
  --from-file=./cloud-integration.json --namespace opencost
```

```yaml
opencost:
  cloudIntegrationSecret: cloud-costs
  cloudCost:
    enabled: true
```

### AWS — Athena over the Cost and Usage Report

```json
{
  "aws": {
    "athena": [
      {
        "bucket": "<ATHENA_BUCKET_NAME>",
        "region": "<ATHENA_REGION>",
        "database": "<ATHENA_DATABASE>",
        "table": "<ATHENA_TABLE>",
        "workgroup": "<ATHENA_WORKGROUP>",
        "account": "<ACCOUNT_NUMBER>",
        "authorizer": {
          "authorizerType": "AWSAccessKey",
          "id": "<ACCESS_KEY_ID>",
          "secret": "<ACCESS_KEY_SECRET>"
        }
      }
    ]
  }
}
```

Least-privilege policy actions, verbatim:
`s3:ListAllMyBuckets`, `s3:ListBucket`, `s3:HeadBucket`, `s3:HeadObject`,
`s3:List*`, `s3:Get*` — reads only.

**Prefer IRSA to the static key.** Annotate the ServiceAccount and drop the
`id`/`secret` pair:

```yaml
serviceAccount:
  create: true
  name: name-of-service-account
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/S3Access
```

### Azure — storage export + RateCard

```json
{
  "azure": {
    "storage": [
      {
        "subscriptionID": "<SUBSCRIPTON_ID>",
        "account": "<STORAGE_ACCOUNT>",
        "container": "<STORAGE_CONTAINER>",
        "path": "<CONTAINER_PATH>",
        "cloud": "<CLOUD>",
        "authorizer": {
          "accessKey": "<STORAGE_ACCESS_KEY>",
          "account": "<STORAGE_ACCOUNT>",
          "authorizerType": "AzureAccessKey"
        }
      }
    ]
  }
}
```

The custom role needs exactly these **read** actions:
`Microsoft.Compute/virtualMachines/vmSizes/read`,
`Microsoft.Resources/subscriptions/locations/read`,
`Microsoft.Resources/providers/read`,
`Microsoft.ContainerService/containerServices/read`,
`Microsoft.Commerce/RateCard/read`.

```bash
az role definition create --verbose --role-definition @myrole.json
az ad sp create-for-rbac --name "OpenCostAccess" --role "OpenCostRole" \
  --scope "/subscriptions/YOUR_SUBSCRIPTION_ID" --output json
az billing account list --query "[].{name:name, displayName:displayName}"
```

### GCP — BigQuery billing export

**Preferred — Workload Identity, no key material at all:**

```json
{
  "gcp": {
    "bigQuery": [
      {
        "projectID": "<GCP_PROJECT_ID>",
        "dataset": "detailedbilling",
        "table": "gcp_billing_export_resource_v1_XXXXXX_XXXXXX_XXXXXX",
        "location": "<BIGQUERY_LOCATION>",
        "authorizer": { "authorizerType": "GCPWorkloadIdentity" }
      }
    ]
  }
}
```

The service-account-key form uses `"authorizerType": "GCPServiceAccountKey"` with the
full JSON key inline under `"key"` — avoid it unless Workload Identity is unavailable.

Required roles — all read:

```bash
export PROJECT_ID=$(gcloud config get-value project)
gcloud iam service-accounts create compute-viewer-opencost \
  --display-name "Compute Read Only Account Created For OpenCost" --format json
for ROLE in roles/compute.viewer roles/bigquery.user roles/bigquery.dataViewer roles/bigquery.jobUser; do
  gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member "serviceAccount:compute-viewer-opencost@$PROJECT_ID.iam.gserviceaccount.com" --role "$ROLE"
done
```

### Custom pricing (on-prem, bare metal, or negotiated flat rates)

```yaml
opencost:
  customPricing:
    enabled: true
    provider: gcp        # alibaba | aws | azure | gcp | oracle | ovh | default (on-prem)
    costModel:
      description: Modified prices based on your internal pricing
      CPU: 12.00
      RAM: 10.50
      storage: 40.25
```

Use `provider: default` for on-prem. Inside the container these land at
`/tmp/custom-config/{provider}.json`. Document the basis for every number you put
here — a custom rate with no provenance is the same problem as an unlabeled cost.

---

## PHASE C — QUERY: the API and what the parameters actually mean

**Goal:** get a number out, and know exactly what window, resolution, and idle
treatment produced it.

### Endpoints

| Endpoint | Answers |
|---|---|
| `GET /allocation` | Kubernetes workload cost — the primary endpoint |
| `GET /allocation/compute` | Compute-only allocation |
| `GET /assets` | Cluster **assets** — nodes, disks, load balancers |
| `GET /cloudCost` | Cloud **billing** line items (needs a cloud integration) |
| `GET /customCost/total` | Plugin-sourced non-K8s cost, totals |
| `GET /customCost/timeseries` | Plugin-sourced non-K8s cost, over time |

### Parameters

**`window`** (required) — accepts named windows `today`, `week`, `month`, `yesterday`,
`lastweek`, `lastmonth`; durations `30m`, `12h`, `7d`; an RFC3339 pair
`2021-01-02T15:04:05Z,2021-02-02T15:04:05Z`; or a Unix-timestamp pair
`1578002645,1580681045`.

**`aggregate`** — comma-separated for multi-key aggregation.

- `/allocation`: `cluster`, `node`, `namespace`, `controllerKind`, `controller`,
  `service`, `pod`, `container`, `label:LABEL_NAME`, `annotation:name`
- `/cloudCost` and `/customCost/*`: `invoiceEntityID`, `accountID`, `provider`,
  `providerID`, `category`, `service`

**`/allocation`-specific:**

| Param | Default | Values |
|---|---|---|
| `step` | `window` | `30m`, `2h`, `1d` — splits the window into sub-results |
| `resolution` | `1m` | `1m`, `30m` — sampling granularity; coarser = cheaper, less exact for short-lived pods |
| `includeIdle` | `false` | boolean — surface idle as its own row |
| `shareIdle` | `false` | boolean — redistribute idle onto workloads |
| `idleByNode` | `false` | boolean — compute idle per node instead of per cluster |

**`/cloudCost` and `/customCost/*`:** `accumulate` — `all`, `hour`, `day`, `week`,
`month`, `quarter` (default `day`). `filter` accepts V2 filter expressions, e.g.
`domain:"datadog"`, `resourceType:"infra_hosts"`, `zone:"us"`.

> **Conflict to resolve in your release — `accumulate` on `/allocation`.** The API
> reference groups `accumulate` under `/cloudCost` and `/customCost/*` only, but the
> MCP server exposes `accumulate` as a parameter of `get_allocation_costs`, which
> fronts `/allocation`. The two docs disagree. **Treat `accumulate` on `/allocation`
> as unverified**: test it against your deployment before relying on it, and if you
> need accumulation on allocation data today, use `step` (which is documented for
> `/allocation`) or aggregate client-side.

### Worked queries

```bash
# What the OpenCost UI itself asks for:
curl -G http://localhost:9003/allocation \
  -d window=7d -d aggregate=namespace -d resolution=1m

# Last 60m in 10m steps, by namespace:
curl -G http://localhost:9003/allocation \
  -d window=60m -d step=10m -d resolution=1m -d aggregate=namespace

# 9 days in 3-day steps, coarse resolution (cheaper on Prometheus):
curl -G http://localhost:9003/allocation/compute \
  -d window=9d -d step=3d -d resolution=10m -d aggregate=namespace

# Idle redistributed onto workloads — and the per-node variant:
curl -G http://localhost:9003/allocation -d window=1d -d shareIdle=true
curl -G http://localhost:9003/allocation -d window=1d -d shareIdle=true -d idleByNode=true

# Assets (nodes, disks, LBs) and cloud billing:
curl -G http://localhost:9003/assets    -d window=7d
curl -G http://localhost:9003/cloudCost -d window=14d -d aggregate=provider,service
```

**Read the response shape, not just `totalCost`.** `/assets` node entries carry
`cpuCoreHours`, `ramByteHours`, `GPUHours`, `cpuCost`, `ramCost`, `gpuCost`,
`cpuBreakdown`/`ramBreakdown` (`idle`/`user`/`system`/`other`), `preemptible`,
`discount`, `adjustment`, `overhead`, and `totalCost`. Disk entries carry `byteHours`,
`bytes`, `byteHoursUsed`, `byteUsageMax`, `storageClass`, `claimName`,
`claimNamespace`. `/cloudCost` entries carry the five cost variants — `listCost`,
`netCost`, `amortizedNetCost`, `invoicedCost`, `amortizedCost` — each with a
`kubernetesPercent`. **Pick the variant deliberately**: `listCost` and `netCost` are
not the same story.

### `kubectl cost` — the CLI front end

```bash
kubectl krew install cost
kubectl cost namespace --historical --window 5d \
  --show-cpu --show-memory --show-pv --show-efficiency=false
kubectl cost namespace --window 2h --show-efficiency=true
kubectl cost label --historical -l app --window 5d
```

Point it at a non-default install with `--kubecost-namespace`, `--service-name`,
`--service-port`, `--allocation-path`.

---

## PHASE D — INTEGRATE: exports, plugins, carbon, MCP

**Goal:** the data leaves OpenCost in a form the rest of the business can consume.

### CSV export (built in)

Driven entirely by environment variables:

| Env var | Purpose |
|---|---|
| `EXPORT_CSV_FILE` | Destination path (local, Azure Blob, S3, or GCS) |
| `EXPORT_CSV_LABELS_LIST` | Comma-separated labels to emit as their own columns |
| `EXPORT_CSV_LABELS_ALL` | Boolean — emit all labels as JSON in a `Labels` column |

Destination formats: `/path/to/file.csv` ·
`https://azblobaccount.blob.core.windows.net/containername/path/to/file.csv` ·
`s3://bucketname/path/to/file.csv` · `gs://bucket-name/path/to/file.csv`.
Cloud auth uses the standard vars (`AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY`/`AWS_REGION`,
`AZURE_CLIENT_ID`/`AZURE_CLIENT_SECRET`/`AZURE_TENANT_ID`, `GOOGLE_APPLICATION_CREDENTIALS`)
— prefer the workload-identity equivalents where the platform offers them.

**Schedule, verbatim:** *"Every day at 00:10 UTC, the data for the previous day is
exported to the specified location."* The first export includes all available data;
later ones append only new dates. For a PV destination, mount at `/mnt/export` with
`fsGroup: 1001` so a non-root container can write.

### Parquet export (external tool)

*"The OpenCost Parquet Exporter is an external tool that connects to OpenCost and
exports data for a defined window of time in the Apache Parquet data format."* It is a
Python app in GHCR, *"Most users schedule a daily export using Kubernetes CronJobs"*,
and it targets *"a filesystem or S3 object storage."* The schema and config keys live
in the tool's own README — **read it there rather than assuming the CSV columns carry
over.**

### Carbon costs

```yaml
kubecostProductConfigs:
  carbonEstimates:
    enabled: true
```

> **Verify this key before using it.** It is the *only* documented key in this skill
> that sits outside the `opencost.*` root, and the `kubecostProductConfigs` prefix is
> Kubecost-flavored — the signature of a doc page that lagged a rename. Confirm
> against `helm show values opencost-charts/opencost` for your release before
> committing it; a well-formed YAML key that the chart ignores fails silently.

*"Carbon Costs is a cost metric added to both Allocation and Assets dashboards. Carbon
Costs are measured in KG CO2e"*, distributed *"to allocations based on resource
usage"*, using *"carbon coefficient data generated by the Cloud Carbon Footprint"*.
Responses gain a `carbonCost` field alongside `cpuCost` / `ramCost` / `totalCost`.
These are **estimates from coefficients**, not measurements — label them as such in
any report.

### The plugin framework — non-Kubernetes spend

Plugins put SaaS spend next to cluster spend via `/customCost/*`. The layout is a
`plugins` directory with `bin/` (binaries) and `config/` (JSON configs):

| Env var | Value |
|---|---|
| `PLUGIN_EXECUTABLE_DIR` | full path to `bin` |
| `PLUGIN_CONFIG_DIR` | full path to `config` |
| `CUSTOM_COST_ENABLED` | `"true"` |
| `LOG_LEVEL` | `debug` while bringing it up |

```yaml
loglevel: debug
plugins:
  enabled: true
  install:
    enabled: true
  enabledPlugins:
    - datadog          # also: openai, mongodb-atlas
  configs:
    datadog: |
      { "datadog_site": "us5.datadoghq.com",
        "datadog_api_key": "<datadog_api_key>",
        "datadog_app_key": "<datadog_app_key>" }
```

| Plugin | Config file | Keys | Freshness caveat (verbatim) |
|---|---|---|---|
| Datadog | `datadog_config.json` | `datadog_site`, `datadog_api_key`, `datadog_app_key` | *"DataDog costs can take up to 72 hours to appear in OpenCost."* |
| OpenAI | `openai_config.json` | `openai_api_key` | *"OpenAI costs are not currently available per snapshot"* |
| MongoDB Atlas | `mongodb_atlas_config.json` | `atlas_public_key`, `atlas_private_key`, `atlas_org_id` | *"detailed costs are currently only retrievable for the current month"* |

Every plugin credential is a **secret**, never a values literal in Git.

### Developer APIs — know what they are before you reach for them

The **diagnostics**, **storage**, and **export** developer APIs are **Go interfaces
inside OpenCost, not REST endpoints.** Diagnostics registers and runs internal checks
(`DiagnosticResult` carries `id`, `name`, `description`, `category`, `timestamp`,
`error`, `details`); Export defines `Exporter[T]` with
`Export(time TimeUnit, data *T) error`; **Storage** is *"a basic file-system like
interface to store and retrieve binary data"* (`Read` / `Write` / `Stat` / `List` /
`Remove` / `Exists` / `ListDirectories`, a `StorageInfo` of `Name`/`Size`/`ModTime`)
backed by S3-or-minio, Azure Blob, GCS, local FS, or memory — cloud backends use
**Thanos' storage configuration format**. **Do not write a runbook that curls any of
them.** For operational health use the HTTP API and the log-level toggle in Phase E.

---

## PHASE E — TROUBLESHOOT: the failure trees

Two diagnostics you will use constantly:

```bash
# Version + startup errors:
kubectl logs -n opencost deployment/opencost | head
# Turn on debug logging at runtime (read-only toggle, no restart):
curl -X POST 'http://localhost:9003/logs/level' -d '{"level": "debug"}'
```

| Symptom | Check | Cause | Fix |
|---|---|---|---|
| `failed to query allocation API … non-200 status code 500` | Prometheus target config on the OpenCost deployment | Wrong/missing Prometheus target; **no OpenCost scrape target** | Correct the Prometheus target; add the `job_name: opencost` scrape config |
| **Negative idle values** | Prometheus scrape config | OpenCost scrape target missing → no emitted-cost history to subtract from | *"ensure you added the scrape target (above) for OpenCost"* |
| *"There are no Cloud Cost integrations currently configured"* | `kubectl logs -n opencost …` for the `opencost` container | Cloud Costs not configured | Complete the Phase B cloud integration |
| GCP Cloud Costs fail on GKE with Workload Identity | `cloud-integration.json` | Missing `authorizerType`, absent IAM binding, insufficient roles | Set `"authorizerType": "GCPWorkloadIdentity"`; bind the KSA→GSA; grant `compute.viewer`, `bigquery.user`, `bigquery.dataViewer`, `bigquery.jobUser` |
| `Address family not supported by protocol` | NGINX config in the UI container | Default NGINX config | Copy the repo default; replace the listen line with `listen ${UI_PORT};`; mount it; re-check firewall/NetworkPolicy |
| Prometheus PVC stuck **Pending** on EKS | `kubectl get pvc -n prometheus-system` | `gp2` provider not configured; no IAM OIDC provider; no EBS CSI driver | `eksctl utils associate-iam-oidc-provider --approve`; create the EBS-CSI IRSA service account; `eksctl create addon` for the AWS EBS CSI driver; re-`helm upgrade` Prometheus with `storageClass: gp2` |

**Verify pricing is actually flowing** — if this returns nothing, every cost is zero:

```bash
kubectl port-forward -n prometheus-system service/prometheus-server 9003:80
curl -s 'http://localhost:9003/api/v1/query?query=node_cpu_hourly_cost' | jq '.data.result[0]'
```

---

## ANTI-PATTERNS (each one bites)

| Anti-pattern | Why it bites | Do instead |
|---|---|---|
| Quoting OpenCost cost as "the bill" | Default is **public on-demand list price** — no discounts, no RIs/SPs | Label the pricing source; integrate cloud billing, or hand invoice reconciliation to `aws-finops`/`azure-finops` |
| Installing without the `job_name: opencost` scrape config | No history → 500s, empty windows, **negative idle** | Add the scrape config as part of the install, not after |
| Comparing OpenCost to a usage-only dashboard and "fixing" the gap | Allocation is `max(request, usage)` — the gap **is** the over-request | Read the gap as the right-sizing signal; hand it to `kubernetes-finops` |
| `shareIdle=true` by default | Hides the cluster's bin-packing problem inside tenant bills | Report allocated + idle separately first; share only under an agreed, documented rule |
| Multiple clusters on one Thanos without `CLUSTER_ID` filtering | Clusters blend silently; every number is wrong and looks fine | Set `CURRENT_CLUSTER_ID_FILTER_ENABLED` + matching `PROM_CLUSTER_ID_LABEL`/`CLUSTER_ID` per instance |
| Static cloud access keys in `values.yaml` | Long-lived credentials in Git; broad blast radius | IRSA / `GCPWorkloadIdentity`; otherwise a mounted secret, read-only scopes only |
| `resolution=1m` over a 90-day window | Hammers Prometheus; slow or failed queries | Coarsen `resolution` and use `step` for long windows |
| Treating `listCost` and `netCost` as interchangeable | Different numbers, different meaning | Choose the cost variant deliberately and state which |
| Curling the diagnostics / storage / export "APIs" | They are **Go interfaces**, not REST endpoints | Use the HTTP API + `/logs/level` for operations |
| Reporting `carbonCost` as measured emissions | Estimated from Cloud Carbon Footprint coefficients | Label it an estimate |
| Pinning an OpenCost version in guidance | The project ships fast; keys and flags move | Describe behavior; verify against opencost.io + `helm show values` |
| Editing OpenCost config with `kubectl edit` in prod | Untracked drift in the thing everyone trusts for cost | Change through Helm values in Git; gated, reviewable |

---

## PRE-DONE VERIFICATION CHECKLIST

- [ ] OpenCost pod **Running** in its namespace; `kubectl logs -n opencost deployment/opencost | head` shows no startup errors.
- [ ] `curl 'http://localhost:9003/allocation/compute?window=60m'` returns **non-empty** data.
- [ ] The `job_name: opencost` scrape target exists and Prometheus shows it **UP**.
- [ ] `node_cpu_hourly_cost` returns a **non-zero** sample in Prometheus.
- [ ] **Idle is not negative** over a 24h window.
- [ ] The **pricing source is known and stated** — cloud integration, list price, or custom pricing.
- [ ] If cloud costs are used: the `cloud-costs` secret exists, `opencost.cloudCost.enabled: true`, and the UI does **not** say "no Cloud Cost integrations currently configured".
- [ ] Credentials are **IRSA / Workload Identity**, or a mounted secret with read-only scopes — **no static keys in Git**.
- [ ] Multi-cluster: every instance sets `CURRENT_CLUSTER_ID_FILTER_ENABLED`, `PROM_CLUSTER_ID_LABEL`, `CLUSTER_ID`, and per-cluster totals do not double count.
- [ ] Any reported figure names its **window, aggregation, resolution, and idle treatment**.
- [ ] Exports (CSV/Parquet) land in the expected location and the destination credential is scoped write-only to that path.
- [ ] Plugin credentials are secrets; plugin freshness caveats (72h Datadog, current-month Mongo) are stated wherever the numbers are shown.
- [ ] No version pinned in prose; every key/flag verified against `opencost.io` and `helm show values`.
- [ ] All analysis was **read-only**; every install/config change went through a gated Helm/Git change.

---

## REFERENCE

### The cost model, one page (from the OpenCost Specification)

```
Total Cluster Costs = Cluster Asset Costs + Cluster Overhead Costs
Total Cluster Costs = Workload Costs + Cluster Idle Costs + Cluster Overhead Costs

Resource Allocation Cost = Amount × Duration × HourlyRate
Resource Usage Cost      = Amount × UnitRate

Workload Cost            = max(request, usage)      # per resource
Cluster Idle Cost        = Cluster Asset Costs − Workload Costs
Cluster Idle %           = Idle Cost / Resource Allocation Costs
```

Per asset: **Node CPU** = `cores × duration × price [$/core-hr]` · **Node RAM** =
`ram_GBs × duration × price [$/GB-hr]` · **PV / attached disk** =
`Disk_Size × Price [$/GB-hr]` · **Load balancer** = usage
`bytes_ingressed × price_per_byte`, allocation `forwarding_rules × price_per_rule`.

Per resource, "the greater of requested and used": **CPU** (cores/millicores),
**Memory** (bytes/GB), **GPU** (cores). **Storage** is PVC *request* capacity.
**Network** is ingress/egress bytes across zone / region / internet.

Pod state: running pods charge `max(usage, request)`; `ImagePullBackOff` charges
`Request`; some states carry no charge.

### Ports

`9003` API + `/metrics` · `9090` UI · `8081` MCP.

### Metrics OpenCost **emits**

`node_cpu_hourly_cost` · `node_ram_hourly_cost` · `node_gpu_hourly_cost` ·
`node_total_hourly_cost` · `node_gpu_count` · `kubecost_node_is_spot`
(labels: `node`, `instance`, `provider_id`) — `container_cpu_allocation` ·
`container_gpu_allocation` · `container_memory_allocation_bytes`
(labels: `container`, `node`, `namespace`, `pod`) — `pod_pvc_allocation` ·
`pv_hourly_cost` · `kubecost_load_balancer_cost` ·
`kubecost_network_zone_egress_cost` · `kubecost_network_region_egress_cost` ·
`kubecost_network_internet_egress_cost` · `kubecost_cluster_management_cost` ·
`kubecost_cluster_info` · `service_selector_labels` · `deployment_match_labels` ·
`statefulSet_match_labels` · `kubecost_http_requests_total` ·
`kubecost_http_response_time_seconds` · `kubecost_http_response_size_bytes` ·
`kubecost_cluster_memory_working_set_bytes` (recording rule).

### Metrics OpenCost **consumes**

node-exporter: `node_memory_MemTotal_bytes`, `node_cpu_seconds_total`,
`node_filesystem_size_bytes`, `node_filesystem_free_bytes`.
kube-state-metrics: `kube_node_status_capacity`, `kube_node_status_allocatable`,
`kube_pod_container_resource_requests`, `kube_pod_container_resource_limits`,
`kube_persistentvolumeclaim_info`,
`kube_persistentvolumeclaim_resource_requests_storage_bytes`.

### `authorizerType` values

`AWSAccessKey` · `AzureAccessKey` · `GCPServiceAccountKey` · `GCPWorkloadIdentity`.

### OpenCost vs Kubecost (one line)

OpenCost = real-time monitoring at **on-demand list pricing**; Kubecost =
*"more accurate cost numbers … after reconciling the differences between your
published bill with any negotiated discounts."*

### Read-only triage scripts (`tools/`)

`opencost-health.sh` (deployment/pod/service/endpoint state, version line from logs,
API reachability — reads only) · `opencost-allocation-summary.sh` (a single
`GET /allocation` aggregated by namespace via port-forward — read-only query) ·
`opencost-pricing-check.sh` (confirms the pricing + allocation metrics exist and are
non-zero in Prometheus, and that the `opencost` scrape target is up — reads only).

---

## MCP SURFACE (read-only)

OpenCost ships an **MCP server built into the Helm chart**, served over **HTTP on port
8081**, exposing the cost APIs as agent-callable tools:

| Tool | Parameters |
|---|---|
| `get_allocation_costs` | `window` (required), `aggregate`, `step`, `accumulate`†, `share_idle`, `include_idle` |
| `get_asset_costs` | `window` (required) |
| `get_cloud_costs` | `window` (required), `aggregate`, `accumulate`, `provider`, `service`, `category`, `region`, `accountID` |

```json
{
  "mcpServers": {
    "opencost": { "type": "http", "url": "http://localhost:8081" }
  }
}
```

Server-side env: `CLOUD_COST_ENABLED`, `CLOUD_COST_CONFIG_PATH`, `MCP_LOG_LEVEL`.

† `accumulate` on the allocation path is the documented conflict flagged in Phase C —
the API reference lists it only for `/cloudCost` and `/customCost/*`. Verify against
your release before depending on it.

**Guardrails.** All three tools are **cost reads** — there is no mutating tool in the
set. The docs do not label the server read-only explicitly, so **treat network reach
as the control**: expose it in-cluster or over a port-forward, not publicly, and give
it no credentials beyond the cost data it already serves. Pair it with
`kubernetes-mcp-server --read-only` for cluster context. Analysis is free; **every
resulting change — a right-size, a scale-down, a quota — is a gated, reversible PR**,
per the blast-radius doctrine in `../../operations/agentic-k8s-ops/`.

---

## SUBAGENT ORCHESTRATION

This skill drives a **5-agent OpenCost team** in `.claude/agents/`:

| Agent | Owns |
|---|---|
| `opencost-installer` | Phase A — Helm / manifest / Docker / exporter-only deployment, the `job_name: opencost` scrape config, ports 9003/9090, the UI, and multi-cluster single-source-of-data (`CURRENT_CLUSTER_ID_FILTER_ENABLED` / `PROM_CLUSTER_ID_LABEL` / `CLUSTER_ID`); owns `opencost-health.sh` |
| `opencost-cloud-integrator` | Phase B — `cloud-integration.json` for AWS Athena / Azure storage+RateCard / GCP BigQuery / OCI, the `cloud-costs` secret, `authorizerType` selection, IRSA + GKE Workload Identity, least-privilege read scopes, and `opencost.customPricing` for on-prem; owns `opencost-pricing-check.sh` |
| `opencost-api-analyst` | Phase C — `/allocation`, `/allocation/compute`, `/assets`, `/cloudCost`, `/customCost/*`; `window` / `aggregate` / `step` / `resolution` / `accumulate` / `includeIdle` / `shareIdle` / `idleByNode`; the cost-variant choice (`listCost` vs `netCost` vs amortized); `kubectl cost`; owns `opencost-allocation-summary.sh` |
| `opencost-export-integrator` | Phase D — CSV export (`EXPORT_CSV_*`), the Parquet exporter CronJob, carbon estimates, the plugin framework (Datadog / OpenAI / MongoDB Atlas) and their freshness caveats, and the MCP surface |
| `opencost-troubleshooter` | Phase E — the failure trees (500 from `/allocation`, negative idle, missing cloud integrations, GCP Workload Identity, NGINX address-family, EKS PVC Pending), `/logs/level` debug toggle, and pricing verification in Prometheus |

**Handoffs:** what to *do* about the cost — right-sizing, waste, quotas, chargeback →
`../../operations/kubernetes-finops/`; node lifecycle → `../../operations/karpenter-operations/`;
the cloud invoice, reservations, savings plans → `aws-finops` / `azure-finops`;
Prometheus/Thanos operation → `../../operations/observability-stack/`; cluster triage →
`../../operations/kubernetes-operations/`; agentic gated-write doctrine →
`../../operations/agentic-k8s-ops/`.
