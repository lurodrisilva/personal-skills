<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-08-08 | Updated: 2026-08-08 -->

# tools

## Purpose
Read-only **OpenCost triage scripts** shipped with the `opencost` skill. Each is a
small `bash` + `kubectl` + `curl` wrapper that answers one question about an OpenCost
deployment — is it up, is its pricing path actually working, and what does it say
things cost — using only Kubernetes read verbs and OpenCost/Prometheus **query**
endpoints. They are **starting points to review before running**, not an approval to
change anything. They never install, upgrade, patch, scale, restart, or delete;
installing or reconfiguring OpenCost is always a separate, human-approved change
delivered through Helm values in Git.

## Key Files
| File | Surfaces |
|------|----------|
| `opencost-health.sh` | Deployment / pod / service / endpoints state in the OpenCost namespace, presence (not contents) of the `cloud-costs` secret, the startup log head, and a `GET /allocation/compute?window=60m` probe through a temporary port-forward. Flags empty responses and non-200s. Env: `OC_NS` (default `opencost`), `OC_SVC`, `OC_API_PORT` (9003), `PROBE_API=0` to skip the probe, `LOCAL_PORT` |
| `opencost-pricing-check.sh` | Prometheus **instant queries** confirming the metrics OpenCost emits (`node_cpu_hourly_cost`, `node_ram_hourly_cost`, `node_total_hourly_cost`, `pv_hourly_cost`, `kubecost_load_balancer_cost`, `container_cpu_allocation`, `container_memory_allocation_bytes`, `pod_pvc_allocation`) and consumes (`kube_node_status_capacity`, `kube_pod_container_resource_requests`, `node_memory_MemTotal_bytes`) have samples, plus whether `up{job="opencost"}` is 1. Env: `PROM_NS`, `PROM_SVC`, `PROM_PORT`, `LOCAL_PORT` |
| `opencost-allocation-summary.sh` | One `GET /allocation` through a port-forward, summarized per aggregation key with `totalCost` / `cpuCost` / `ramCost` / `gpuCost` / `pvCost`, plus the `__idle__` row and a negative-idle warning. Always prints the window / aggregate / resolution / idle treatment alongside the numbers. Env: `WINDOW` (7d), `AGGREGATE` (namespace), `RESOLUTION` (1m), `INCLUDE_IDLE`, `SHARE_IDLE`, `OC_NS`, `OC_SVC` |

## For AI Agents

### Working In This Directory
- **Read-only is a hard invariant.** Every `kubectl` call must be a read — `get`,
  `describe`, `logs`, `port-forward`. Every HTTP call must be a query — OpenCost's
  `/allocation`, `/allocation/compute`, `/assets`, `/cloudCost`, or Prometheus'
  `/api/v1/query`. **Never** add a mutating verb: no `apply`, `create`, `patch`,
  `edit`, `delete`, `scale`, `rollout restart`, `helm install/upgrade/uninstall`, and
  no `POST` to `/logs/level` from inside a script (that is a deliberate human
  debugging step, not automation). A "triage" script that reconfigures the thing
  everyone trusts for cost numbers is worse than none.
- **Never print secret contents.** `opencost-health.sh` checks only that
  `secret/cloud-costs` *exists*. Cloud billing credentials must never reach stdout,
  a log, or a transcript. Do not add `-o yaml` / `-o jsonpath` reads of secret data.
- Each script starts with `set -euo pipefail`, verifies its binaries are on `PATH`,
  and carries a header comment stating it is read-only, the access it needs, and that
  installing/reconfiguring OpenCost is a separate human-approved change.
- Port-forwards are backgrounded and cleaned up with a `trap` on `EXIT`. Keep that —
  a leaked forward holds a local port and confuses the next run.
- **Every cost number must travel with its qualifiers.** `opencost-allocation-summary.sh`
  prints `window`, `aggregate`, `resolution`, `includeIdle`, and `shareIdle` above the
  table on purpose. A cost figure without them is not interpretable. If you extend the
  output, keep the qualifiers attached.
- **State the pricing source.** With no cloud integration, OpenCost reports **public
  on-demand list pricing**, not the negotiated bill. Both the health and allocation
  scripts say so. Don't remove that warning to make output tidier.
- `jq` is optional but strongly preferred — the scripts degrade to raw JSON without it
  rather than failing. Keep that fallback if you edit the parsing.
- Defaults assume the documented conventions: namespace `opencost`, service
  `opencost`, API port `9003`, Prometheus at `prometheus-system/prometheus-server:80`.
  Override via env; don't hardcode a site-specific value into the script.

### Testing Requirements
- `bash -n <script>` must pass for every script (syntax check); the repo has no test
  runner for shell.
- Scripts must remain executable (`chmod +x`).
- These files live outside the validator's `DOMAIN_DIRS` SKILL.md walk — the parent
  `../SKILL.md` is what `scripts/validate-skills.sh` checks. Re-run
  `./scripts/validate-skills.sh` after touching the skill regardless.

### Common Patterns
- Header comment → binary checks → env defaults → banner line naming the target and
  "read-only" → sectioned `== … ==` output → a closing "Goal:" paragraph restating the
  read-only boundary and where the *decision* belongs.
- Findings point outward, not inward: what to **do** about a cost number (right-size,
  quota, chargeback) belongs to `../../../operations/kubernetes-finops/`, and every
  resulting change is a gated, reversible PR.

## Dependencies

### External
- `kubectl` — read verbs + `port-forward` against the target cluster.
- `curl` — OpenCost API and Prometheus query reads.
- `jq` (optional) — JSON summarization; scripts fall back to raw output.
- A running OpenCost deployment and a Prometheus that scrapes it.

<!-- MANUAL: -->
