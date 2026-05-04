---
name: az-dns-zone-group-show-false-positive
description: az network private-endpoint dns-zone-group show returns {} with exit 0 for non-existent resources, breaking idempotency-by-exit-code patterns
triggers:
  - dns-zone-group show
  - private-endpoint dns-zone-group
  - az network private-endpoint dns-zone-group
  - idempotent az script
  - private endpoint dns idempotency
  - exit 0 missing resource
  - false positive idempotency check
  - mongo vcore PE DNS
  - azure CLI bug exit code
  - private-endpoint dns-zone-group create
---

# az network private-endpoint dns-zone-group show — exit 0 for missing resources

## The Insight

Most `az ... show` commands return non-zero (typically 3) when the target resource doesn't exist, which makes `if az ... show >/dev/null 2>&1; then skip; else create; fi` a clean idempotency idiom. **`az network private-endpoint dns-zone-group show` is broken** — it prints `{}` and returns exit code 0 even when the dns-zone-group does not exist on the named PE. Naïve idempotency checks treat "missing" as "exists" and silently skip the create step.

## Why This Matters

If you build a "create PE then bind to private DNS zone" pipeline using the standard exit-code idiom, the `dns-zone-group create` will be skipped on every run (because show says exit 0), the PE will sit without DNS bindings, and the cluster's private FQDN will be unresolvable from inside the VNet. Symptom: `nc -zv <fqdn> <port>` from a VNet-attached pod fails with `bad address`, even though the PE is provisioned and approved. Discovered with Cosmos DB for MongoDB vCore PEs, but the bug lives in `az network private-endpoint dns-zone-group show` itself, so it affects every PE-DNS-binding workflow.

## Recognition Pattern

- You wrote idempotent provisioning bash that re-runs cleanly the second time on every other resource
- The PE create succeeded, the cluster is reachable from the public internet (if not disabled), but a pod inside the VNet gets `bad address` or `NXDOMAIN` for the cluster FQDN
- `az network private-endpoint dns-zone-group list -g <rg> --endpoint-name <pe>` returns `[]` (empty) — the dns-zone-group really isn't there
- But your script's `if az network private-endpoint dns-zone-group show ... 2>/dev/null; then echo "exists"; fi` printed "exists" and skipped the create

## The Approach

**Don't trust the exit code of `az network private-endpoint dns-zone-group show`.** Check the body of the response — specifically whether `name` (or `id`, or `provisioningState`) is non-empty:

```bash
existing=$(az network private-endpoint dns-zone-group show \
             -g "$RG" --endpoint-name "$PE" -n "$DNSGRP" \
             --query 'name' -o tsv 2>/dev/null || true)
if [[ -n "$existing" ]]; then
  echo "exists, skipping"
else
  az network private-endpoint dns-zone-group create ...
fi
```

The `|| true` prevents `set -e` from killing the script if Azure ever decides to fix the bug and start returning non-zero. The `-n "$existing"` check is the actual idempotency gate.

Alternative: use `dns-zone-group list` with a `--query` predicate, which returns `[]` (empty array) cleanly for missing groups. Less efficient (lists all groups on the PE) but exit-code-honest.

## Example

```bash
# WRONG — false-positive on missing dns-zone-group
if az network private-endpoint dns-zone-group show \
     -g "$RG" --endpoint-name "$PE" -n "$DNSGRP" >/dev/null 2>&1; then
  echo "exists"   # printed even when the resource is missing
fi

# RIGHT — body-based check
existing=$(az network private-endpoint dns-zone-group show \
             -g "$RG" --endpoint-name "$PE" -n "$DNSGRP" \
             --query 'name' -o tsv 2>/dev/null || true)
if [[ -n "$existing" ]]; then
  echo "exists"
fi
```
