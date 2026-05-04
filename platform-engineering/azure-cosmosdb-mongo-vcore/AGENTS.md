<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-05-04 | Updated: 2026-05-04 | DEEPINIT: 2026-05-04 -->

# azure-cosmosdb-mongo-vcore

## Purpose
Knowledge directory for **Azure Cosmos DB for MongoDB vCore** (`Microsoft.DocumentDB/mongoClusters`) provisioning, private-endpoint binding, and connectivity verification. Currently ships only two **companion expertise notes** that capture standalone debugging insights discovered during PE-DNS automation work — no full Distinguished Platform Engineer's Playbook `SKILL.md` exists yet. The expertise notes use the alternative `triggers:` frontmatter schema (auto-load on phrase match) rather than the SKILL.md contract, and each documents a single load-bearing trap with recognition pattern + corrective approach + worked example.

## Key Files
| File | Description |
|------|-------------|
| `az-dns-zone-group-show-false-positive-expertise.md` | The `az network private-endpoint dns-zone-group show` Azure CLI bug: returns `{}` with **exit code 0** for non-existent dns-zone-groups, breaking `if az ... show >/dev/null; then skip; else create; fi` idempotency idioms. Recommended workaround: body-based check via `--query 'name' -o tsv` |
| `mongo-vcore-srv-not-a-record-expertise.md` | The `<cluster>.mongocluster.cosmos.azure.com` host returned in `connectionString` is **SRV-only** (no A record) — naïve `nc -zv $fqdn 10260` probes fail with `bad address` even when the cluster is healthy. Recommended workaround: probe the PE-published FQDN from `dns-zone-group show --query 'privateDnsZoneConfigs[0].recordSets[0].fqdn'`. Includes the HA-tier-minimum bonus (M30+ required; M10/M20 reject `--shard-node-ha true`) |

## Subdirectories
None.

## For AI Agents

### Working In This Directory
- These are **expertise notes**, not the full SKILL.md contract. Frontmatter is `name` + `description` + `triggers` (a list of phrase-matching strings) — there is no `license`, `compatibility`, or `metadata` map, so the SKILL.md validator's required-field checks would falsely fail against them. This is intentional: expertise notes are loaded by phrase-trigger lookup, not by the SKILL.md auto-detection path.
- Both notes follow the same body shape — keep it on extensions: **The Insight** (one paragraph, the trap stated plainly) → **Why This Matters** (concrete failure mode and symptom) → **Recognition Pattern** (bullet list of the breadcrumbs that point at this issue) → **The Approach** (the corrective pattern, with the rationale for each defensive token like `|| true` and `-n`) → **Example** (WRONG vs RIGHT bash blocks). Optionally a **Bonus** subsection for an adjacent gotcha discovered alongside (the SRV-vs-A note carries the M30+ HA tier minimum this way).
- The two notes are **paired** — the SRV-vs-A note relies on `dns-zone-group show --query 'privateDnsZoneConfigs[0].recordSets[0].fqdn'` to *get* the right FQDN to probe, which is the same command whose exit-code semantics are broken in the other note. Cross-link mentally: any new automation that consumes one almost certainly also has to defend against the other.
- A full Distinguished Platform Engineer's Playbook `SKILL.md` for `mongoClusters` would be the natural next step (provisioning verbs, server-parameter governance, diagnostic settings, metric model, network ACLs / `publicNetworkAccess`, HA tier matrix, sharding, geo-replication). When/if one is added, the existing expertise notes should remain — the `triggers:` schema lets them auto-load independently of the heavier SKILL.md, and the Insight-paragraph format is more useful for fast in-context recall than the SKILL.md's exhaustive surface coverage.
- Scope guard: the cluster type covered here is `Microsoft.DocumentDB/mongoClusters` (Cosmos DB for MongoDB **vCore**). Do **not** extend these notes to cover Cosmos DB for MongoDB **RU** (request units, the original Cosmos Mongo offering) or Azure Cosmos DB for PostgreSQL (Citus). They have different RPs, different connection-string formats, different driver expectations, and would dilute the recognition patterns. Add a sibling directory instead.

### Testing Requirements
- **`scripts/validate-skills.sh` does NOT walk this directory** — both because the validator is hardcoded to `coding/` (parent skill's known coverage gap) **and** because these expertise notes do not satisfy the SKILL.md required-field contract by design. Do not "fix" the frontmatter to pass the SKILL.md validator; the alternate `triggers:` schema is correct here.
- Manual checks per file:
  1. Frontmatter parses as YAML (delimited by `---` first/last), with `name`, `description`, and a non-empty `triggers:` list.
  2. Markdown body after the closing `---` is non-empty.
  3. Fenced code-block markers are even in count — these notes ship bash blocks (CLI invocations, idempotency idioms) where unclosed fences are the most likely regression. Run `grep -c '^```' <file>.md` and confirm even.

### Common Patterns
- "The Insight / Why This Matters / Recognition Pattern / The Approach / Example" body skeleton — same shape as the `azure-pg-flex-empty-metrics-expertise.md` companion note next door, and the recommended template for any future expertise note added to this collection.
- WRONG-then-RIGHT bash example pairs (commented `# WRONG` / `# RIGHT`) — preserve on extensions; this is the load-bearing teaching device.
- Defensive bash idioms: `--query 'field' -o tsv 2>/dev/null || true` (decouples missing-resource handling from `set -e`), `[[ -n "$var" ]]` body-presence checks (idempotency gate that doesn't trust the exit code), explicit `-w5` timeout on `nc` probes.
- `description:` opens with the symptom or trap statement (not "MUST USE when …" — that prefix is reserved for the SKILL.md contract, where it is what the auto-loader matches on).

## Dependencies

### Internal
- `../AGENTS.md` — parent platform-engineering directory; describes the Distinguished Platform Engineer tone and the SKILL.md contract that these notes deliberately do **not** follow.
- `../azure-pg-flex/azure-pg-flex-empty-metrics-expertise.md` — sibling expertise note using the same `triggers:`-frontmatter schema and Insight-paragraph body shape; reference exemplar for any future note added here.
- `../../README.md` — does **not** currently reference this directory (the skill is new and untracked in git as of generation). When a `SKILL.md` is added or the expertise notes are otherwise promoted, add a row to the Platform Engineering table.
- `../../scripts/validate-skills.sh` — *does not validate this directory*; manual checks above are the only gate.

### External
None at runtime — these are documentation, not code. The notes *describe* usage of `az network private-endpoint dns-zone-group {show,list,create}`, `az cosmosdb mongocluster show`, `nc` (netcat), `kubectl exec`, `mongosh`, the `mongodb+srv://` driver SRV-resolution behavior, and Azure Private DNS zones bound to Private Endpoints — but ship no executable artifacts.

<!-- MANUAL: -->
