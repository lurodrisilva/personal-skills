---
name: mongo-vcore-srv-not-a-record
description: Cosmos DB for MongoDB vCore public hostnames carry SRV records (mongodb+srv://), not A records — TCP probes against the cluster name fail with "bad address"
triggers:
  - mongo vcore connectivity
  - mongocluster.cosmos.azure.com
  - nc bad address mongo
  - mongodb+srv private endpoint
  - probe Cosmos DB for MongoDB
  - mongo cluster fqdn nc fail
  - private endpoint dns mongo
  - mongo vcore TCP probe
  - HA mongo cluster global ro.global
  - mongo vcore primary replica DNS
---

# Cosmos DB for MongoDB vCore: SRV records, not A — TCP probes need the PE FQDN

## The Insight

The `connectionString` returned by `az cosmosdb mongocluster show` looks like a single host (`mongodb+srv://<cluster>.mongocluster.cosmos.azure.com/?...`), but **`<cluster>.mongocluster.cosmos.azure.com` carries no A record**. It's a `mongodb+srv://` URL — the driver resolves SRV records under `_mongodb._tcp.<cluster>.mongocluster.cosmos.azure.com` to discover actual host targets, which themselves are A-record-resolvable via the linked private DNS zone. A naïve `nc -zv <cluster>.mongocluster.cosmos.azure.com 10260` fails with `bad address` even when the PE is healthy and the cluster is reachable.

## Why This Matters

When you build a TCP-reachability test (e.g., `kubectl exec pod/alpine -- nc -zv $fqdn 10260`) by extracting the host from `connectionString` via `sed 's|.*@||;s|/.*||'`, the probe will always fail with DNS NXDOMAIN, even though the cluster IS reachable from the same pod via the Mongo client. Connectivity verification scripts that don't account for the SRV layer give false-negative results.

## Recognition Pattern

- TCP probe (`nc`, `telnet`, raw socket) of `<cluster>.mongocluster.cosmos.azure.com` fails with `bad address`
- DNS lookup for `_mongodb._tcp.<cluster>.mongocluster.cosmos.azure.com` returns valid SRV pointing at `fc-XXXX-000.mongocluster.cosmos.azure.com`
- The PE's private DNS zone group has A records for the `fc-XXXX-000.privatelink.mongocluster…` names
- Mongo client connects fine; only TCP-level probes fail
- HA-enabled clusters (M30+) publish two records: `fc-XXXX-000.global.privatelink…` (primary) and `fc-XXXX-000.ro.global.privatelink…` (replica). Single-node clusters publish only `fc-XXXX-000.privatelink…`.

## The Approach

For TCP-reachability tests, **probe the PE-published FQDN, not the cluster name**:

```bash
pe_fqdn=$(az network private-endpoint dns-zone-group show \
            -g "$RG" --endpoint-name "${cluster}-pe" -n "${cluster}-dnsgrp" \
            --query 'privateDnsZoneConfigs[0].recordSets[0].fqdn' -o tsv)
kubectl exec pod/$probe_pod -n $ns -- nc -zv -w5 "$pe_fqdn" 10260
```

The `recordSets[0].fqdn` returns the first published A record. For HA clusters, this is the `.global.` (primary) record. To probe replicas, iterate `recordSets[]` instead of indexing `[0]`.

For end-to-end Mongo connectivity (auth + protocol handshake), use `mongosh` from a pod that has it installed (not stock alpine — needs `apk add mongodb-tools` or a sidecar). The driver handles SRV resolution itself, so `mongosh "$connection_string" --eval 'db.adminCommand({ping:1})'` works against the cluster name directly.

## Example

```bash
# WRONG — uses the SRV-only cluster name
fqdn=$(az cosmosdb mongocluster show -g $rg -c $cluster \
       --query 'properties.connectionString' -o tsv | sed 's|.*@||;s|/.*||')
nc -zv "$fqdn" 10260   # → bad address, no A record

# RIGHT — uses the PE-published A-record FQDN
pe_fqdn=$(az network private-endpoint dns-zone-group show \
          -g $rg --endpoint-name "${cluster}-pe" -n "${cluster}-dnsgrp" \
          --query 'privateDnsZoneConfigs[0].recordSets[0].fqdn' -o tsv)
nc -zv "$pe_fqdn" 10260   # → open
```

## Bonus: HA tier minimum

Mongo vCore HA support starts at M30. M10 and M20 reject `--shard-node-ha true` with `bad_request: High Availability not available for '<tier>' cluster tier`. If you need HA on the entry-tier rung of a metal-tier ladder (Bronze=M10, Silver=M20), you cannot. Either skip HA on those rungs or shift the ladder to M30+.
