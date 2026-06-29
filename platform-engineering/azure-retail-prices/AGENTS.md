<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-05-24 | Updated: 2026-05-24 | DEEPINIT: 2026-05-24 -->

# azure-retail-prices

## Purpose
Skill that guides authoring + reviewing code paths that programmatically read **Azure retail prices** from the public **Azure Retail Prices REST API** (`https://prices.azure.com/api/retail/prices`). Covers the **anonymous (no-auth) commercial-cloud-only endpoint contract**, the **two API versions** (default stable vs `2023-01-01-preview` for `savingsPlan[]` and `meterRegion='primary'`), the **case-sensitive `$filter` value rule** on preview, the small OData operator surface (`eq`, `and`, `contains(...)` — no `or`/`ne`/`gt`/`lt`), the `priceType` enum (`Consumption` / `DevTestConsumption` / `Reservation`), the 26-value `serviceFamily` enum, the full response schema, the **paginate-to-`NextPageLink === null`** contract (1,000 records/page), the **USD-only billing reconciliation rule** (every other currency is reference-only), `isPrimaryMeterRegion` double-count avoidance, **reservation total-not-hourly** trap, `DevTestConsumption` vs `Consumption` mixing trap, slowly-drifting enum-string discipline, defensive caching (≥24 h TTL keyed on `(filter, currencyCode, api-version)`), and exponential backoff on 5xx/429 only.

## Key Files
| File | Description |
|------|-------------|
| `SKILL.md` | Skill definition — `name: azure-retail-prices`, `domain: platform-engineering`, `pattern: azure-retail-prices-api-integration`, `platform: azure`, `stack: rest-api + odata-filter`, `cloud: azure-commercial` |

## Subdirectories
None.

## For AI Agents

### Working In This Directory
- Edit `SKILL.md` only.
- The 12 non-negotiables at the top of the body are flag-first rules in any pricing-caller PR. Load-bearers: anonymous + commercial-cloud only (#1), pin `?api-version=2023-01-01-preview` for savings plans (#2), **case-sensitive `$filter` values** on preview (#3), paginate to `NextPageLink === null` (#4), USD-only billing reconciliation (#5), small OData surface (#6), defensive caching + backoff with no documented SLA (#7), `isPrimaryMeterRegion` filter (#8), reservation `retailPrice` is **total**, not hourly (#9), don't mix `Consumption` + `DevTestConsumption` (#10), drifting `serviceName` enum audit (#11), catalog-not-billing-source stop-sign (#12).
- Sister skills (`azure-pg-flex`, `kusto-kql-api`, `addons-and-building-blocks`) — extend description triggers when introducing new FinOps / dashboard / Crossplane file patterns.

### Testing Requirements
- **`scripts/validate-skills.sh` validates this directory** (its `DOMAIN_DIRS` includes `platform-engineering/`) — CI runs it on every push and PR. Run it locally before pushing; it checks:
  1. YAML frontmatter parses and contains `name`, `description`, `license`, `compatibility`, non-empty `metadata` map.
  2. Markdown body after the closing `---` is non-empty.
  3. Fenced code-block markers are even in count.
- Every example caller snippet must paginate to `NextPageLink === null`, pin an `api-version`, declare `currencyCode`, and cache the response.

### Common Patterns
- "Non-negotiables encoded in this skill" numbered list — same authoring style as other platform-engineering skills.
- "WHEN TO USE THIS SKILL" matrix opens the body; explicitly excludes invoice reconciliation (Cost Management Usage Details / Exports), showback / chargeback, audit-grade financial reporting (EA / MCA Billing API), and sovereign / non-Azure clouds.
- Anti-patterns table maps each violation to "what breaks in production" — silent zero-row returns from lowercase filter values, undercounted SKUs from first-page-only callers, non-USD prices mistakenly reconciled against invoices.

## Dependencies

### Internal
- `../../README.md` — references this skill in the "Platform Engineering" table.
- `../../scripts/validate-skills.sh` — validates this file (its `DOMAIN_DIRS` includes `platform-engineering/`); CI runs it on every push and PR.
- `../azure-pg-flex/SKILL.md` — sibling whose Azure observability discipline complements the FinOps surface.
- `../kusto-kql-api/SKILL.md` — sibling for the analogous "telemetry-query API" discipline (paginate, version, parse-fail-loudly).
- `../addons-and-building-blocks/SKILL.md` — sibling for App-of-Apps deployment that a pricing-snapshot cron might ship under.

### External
None at runtime — this is documentation, not code.

<!-- MANUAL: -->
