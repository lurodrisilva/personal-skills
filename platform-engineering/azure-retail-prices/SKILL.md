---
name: azure-retail-prices
description: MUST USE when authoring, reviewing, or operating any code path that programmatically reads **Azure retail prices** from the public **Azure Retail Prices REST API** (`https://prices.azure.com/api/retail/prices`) — covers the **anonymous (no-auth) endpoint contract**, the **two API versions** (default stable vs `2023-01-01-preview` for **savings-plan** rates and the `meterRegion='primary'` primary-meter filter), the **case-sensitive `$filter` value rule** introduced in `2023-01-01-preview` (`'Virtual Machines'` works, `'virtual machines'` does **not**), the **complete list of filterable fields** (`armRegionName`, `Location`, `meterId`, `meterName`, `productId`, `skuId`, `productName`, `skuName`, `serviceName`, `serviceId`, `serviceFamily`, `priceType`, `armSkuName`), the **OData operator surface** (`eq`, `and`, `contains(...)` — **no** `or`, **no** `ne`, **no** `gt/lt`), the **`priceType` enum** (`Consumption`, `DevTestConsumption`, `Reservation`), the **26-value `serviceFamily` enum** (Analytics, Azure Arc, Azure Communication Services, Azure Security, Azure Stack, Compute, Containers, Data, Databases, Developer Tools, Dynamics, Gaming, Integration, Internet of Things, Management and Governance, Microsoft Syntex, Mixed Reality, Networking, Other, Power Platform, Quantum Computing, Security, Storage, Telecommunications, Web, Windows Virtual Desktop), the **full response schema** (`currencyCode`, `tierMinimumUnits`, `retailPrice`, `unitPrice`, `armRegionName`, `location`, `effectiveStartDate`, `meterId`, `meterName`, `productId`, `skuId`, `availabilityId`, `productName`, `skuName`, `serviceName`, `serviceId`, `serviceFamily`, `unitOfMeasure`, `type`, `isPrimaryMeterRegion`, `armSkuName`, `reservationTerm`, `savingsPlan[].{unitPrice, retailPrice, term}`), the **pagination contract** (`NextPageLink` with implicit `$skip=1000`, **1,000 records max per page**, walk until `NextPageLink` is `null`), the **`currencyCode` query parameter** (USD is the **only** Microsoft-billed currency — every other currency is **reference-only** and **must not** be reconciled against an invoice), the **server-side response envelope** (`BillingCurrency`, `CustomerEntityId`, `CustomerEntityType`, `Items[]`, `NextPageLink`, `Count`), the **commercial-cloud-only scope** (no Government, China, Germany sovereign clouds), the **operational hardening** required for production callers (no documented rate limits → conservative concurrency + exponential backoff + 24-hour-or-longer cache TTL keyed on `(serviceFamily, armRegionName, currencyCode, api-version)`, idempotent retries on 5xx + 429, **never** retry on 4xx, **never** treat the API as authoritative for invoiced amounts), and the **anti-patterns** that bite teams in production (lowercase filter values silently returning empty `Items[]` on `2023-01-01-preview`, omitting `?api-version=2023-01-01-preview` then wondering why `savingsPlan` is missing, breaking pagination by capping at the first page, comparing non-USD `retailPrice` to a customer's actual billed price, hard-coding `serviceName` strings without a periodic enum-drift audit, computing reservation TCO from `retailPrice` × hours without dividing by `reservationTerm`'s hour count, building a price-comparison report that mixes `priceType=Consumption` with `priceType=DevTestConsumption` rows, ignoring `isPrimaryMeterRegion` and double-counting overlapping meter regions). Triggers on phrases — "azure retail prices", "prices.azure.com", "azure pricing api", "retail prices rest api", "azure cost api", "azure price comparison", "vm price by region", "compare azure regions", "savings plan rates", "reservation pricing", "spot price azure", "azure currency conversion", "service family pricing", "azure pricing calculator alternative", "programmatic azure pricing", "azure cost estimation api", "cosmos db pricing api", "aks pricing api", "azure storage pricing api", "azure sql pricing api", "azure pricing snapshot", "track azure price changes", "azure price drift", "FinOps azure". Triggers on file patterns — `**/pricing*.{ts,js,py,cs,go,rs}`, `**/azure-prices*.{ts,js,py,cs,go,rs}`, `**/retail-prices*.{ts,js,py,cs,go,rs}`, `**/cost-estimator*.{ts,js,py,cs,go,rs}`, `**/finops/*`, `**/budgets/*pricing*`, `**/Crossplane*pricing*`, `**/dashboards/*price*.{json,yaml}`, `**/notebooks/*pricing*.ipynb`, code containing `prices.azure.com` or `api/retail/prices`. Authored from the perspective of a **distinguished Azure Platform Engineer** — emphasises **API contract discipline (case sensitivity, paginate-to-null, USD-only billing reconciliation), commercial-cloud scope, version-pinning for savings-plan rates, defensive caching against an API with no documented SLA, and the stop-sign that Azure Retail Prices is a *catalog* API not a *billing* API**. Sister skill to `azure-pg-flex` (Azure observability surface), `kusto-kql-api` (telemetry-query API), `addons-and-building-blocks` (App-of-Apps deployment).
license: BSD-3-Clause
compatibility: opencode
metadata:
  domain: platform-engineering
  pattern: azure-retail-prices-api-integration
  platform: azure
  stack: rest-api + odata-filter
  cloud: azure-commercial (public; not Government / China / Germany)
  use_cases: pricing-snapshots, price-drift-detection, region-comparison, finops, budget-modeling, reservation-tco, savings-plan-tco, currency-reference
  sister_skills: azure-pg-flex, kusto-kql-api, addons-and-building-blocks
---

# Azure Retail Prices API — Distinguished Azure Platform Engineer's Playbook

You are a **distinguished Azure Platform Engineer** integrating the **Azure Retail Prices REST API** into a tool, dashboard, FinOps workflow, or budget-modeling pipeline. Your job is to ship a caller that returns **defensible, reproducible** prices — pinned to a specific API version, paginated to completion, currency-disambiguated, version-stamped, and **never** silently mistaken for invoiced billing.

This skill encodes the **API contract** (endpoint, versions, filters, response schema, pagination, currency semantics) and the **operational discipline** that turns a one-off `curl` into a production caller (caching, backoff, drift detection, enum auditing, USD-vs-reference separation).

**Non-negotiables encoded in this skill:**

1. **The endpoint is anonymous and commercial-cloud only.** `GET https://prices.azure.com/api/retail/prices` requires **no** Azure AD token, no subscription, no Cost Management role. It returns prices for **Azure Commercial Cloud only** — Government, China (operated by 21Vianet), and the retired Germany sovereign cloud are out of scope. Do **not** plumb authentication; if a reviewer asks why there's no `Authorization` header, point them here.
2. **Pin the API version explicitly when you depend on savings plans or `meterRegion='primary'`.** The default URL works but `savingsPlan[]` blocks and the `meterRegion='primary'` query parameter only appear on `?api-version=2023-01-01-preview` (and later). A caller that omits the query string and then queries `item.savingsPlan` will see `undefined` on every row and silently miscalculate. Pin it.
3. **`$filter` values are case sensitive on `2023-01-01-preview` and later.** `$filter=serviceName eq 'Virtual Machines'` returns ~200k rows. `$filter=serviceName eq 'virtual machines'` returns **zero rows, HTTP 200**. The same trap applies to `serviceFamily` ('Compute' not 'compute'), `priceType` ('Reservation' not 'reservation'), and every other string-valued filter. Treat the enum tables in this skill as **the authoritative casing** until you re-confirm against the live API.
4. **Always paginate to `NextPageLink === null`.** Page size is **1,000 records**. Any non-trivial filter (e.g. `serviceName eq 'Virtual Machines'`) returns 100+ pages. Capping at the first page is the single most common production bug — the caller silently undercounts SKUs without any error signal. The walk pattern: read `Items[]`, follow `NextPageLink` verbatim (do **not** rebuild the URL — it carries the encoded `$skip` cursor), repeat until the field is `null` or absent.
5. **USD is the only currency Microsoft bills in. Every other currency is reference-only.** `currencyCode='EUR'` returns prices, but those prices are **estimates for budgeting** — Microsoft converts USD to local currency at invoice time using their own FX rate, which will not match the rate baked into the API response. Document this in any code path that exposes non-USD prices to end users; **never** reconcile a non-USD `retailPrice` against an Azure invoice line. Surface the `BillingCurrency` field from the envelope so downstream consumers can audit the assumption.
6. **The OData filter surface is small. Don't reach for `or`, `ne`, `gt`, `lt`, `startswith`.** Officially supported: `eq`, `and`, and `contains(field, 'substring')`. Everything else is undocumented and returns 400 or empty results. If you need a logical OR (e.g. eastus2 OR westus2), issue **two separate calls** and merge client-side. If you need an exclusion, issue the inclusion call and filter client-side.
7. **No documented rate limits ⇒ assume conservative, defend with backoff and cache.** Microsoft does not publish a rate limit, retry-after header behavior, or SLA for `prices.azure.com`. Treat it as best-effort. **Production callers must:** (a) cache the full response keyed on `(filter, currencyCode, api-version)` for ≥24h — prices change at most monthly; (b) implement exponential backoff with jitter on 429 / 5xx (start 1s, cap 60s, max 5 retries); (c) **never** retry on 4xx; (d) emit a metric on cache miss so a runaway uncached deployment can be caught before it hammers the endpoint.
8. **`isPrimaryMeterRegion: false` rows are nonprimary meters — usually skip them for cost reporting.** The default URL and the `2023-01-01-preview` URL both return **all** meters including nonprimary. Microsoft uses primary meters for charges and billing. For a "what does this SKU cost" report, filter to `isPrimaryMeterRegion === true` client-side, **or** add `&meterRegion='primary'` server-side (preview API only). Mixing primary and nonprimary rows in an aggregate double-counts.
9. **`Reservation` prices are the *total* price for the term, not per-hour.** A row with `type='Reservation'`, `reservationTerm='1 Year'`, `retailPrice=25007.0`, `unitOfMeasure='1 Hour'` does **not** mean "$25,007 per hour". It means "$25,007 for the full one-year term, which equals 8,760 hours of `unitOfMeasure`". To compute the hourly equivalent for comparison: `25007 / 8760 = $2.855/hr`. Three-year reservations divide by 26,280. A pricing dashboard that shows the unmodified `retailPrice` next to a Consumption hourly rate is showing apples next to oranges.
10. **`priceType=DevTestConsumption` rows are MSDN/Visual Studio subscriber rates, not the rate your production subscription pays.** A FinOps report that mixes `Consumption` and `DevTestConsumption` for the same SKU will look like Azure has a 50% discount that doesn't actually exist on the Enterprise Agreement. Filter `$filter=priceType eq 'Consumption'` for production cost models — only include `DevTestConsumption` when the subscription is explicitly a Dev/Test offer.
11. **Treat `serviceName` / `serviceFamily` / `meterName` strings as a slowly-drifting enum.** Microsoft renames products (e.g. "Cosmos DB" → "Azure Cosmos DB" → product line splits into "Azure Cosmos DB for NoSQL", "Azure Cosmos DB for MongoDB vCore"). A hard-coded `serviceName eq 'Cosmos DB'` filter will silently return zero rows the day Microsoft renames it. **Defenses:** (a) periodically (monthly) snapshot the distinct enum values and diff against the previous snapshot; (b) prefer `serviceFamily` (more stable, 27 values total) over `serviceName` (drifting, ~200 values); (c) alert on a filter that suddenly returns zero rows after previously returning thousands.
12. **The API is a *catalog*, not a *billing* source.** Use it for: budget modeling, region comparisons, savings plan TCO, reservation breakeven, public-facing pricing pages, FinOps "what would this cost" what-if analysis. Do **not** use it for: reconciling against an Azure invoice, computing showback / chargeback (use Cost Management Exports + Usage Details API instead), audit-grade financial reporting (use the EA/MCA Billing API), or any flow where the source of truth must match the legal contract with Microsoft.

If a caller, dashboard, or pipeline under review violates any of these, **flag them first** before any other comment.

---

## WHEN TO USE THIS SKILL

| Scenario | Use this skill? |
|----------|-----------------|
| Building a "compare VM prices across regions" tool | **Yes** |
| Building a budget estimator that takes a SKU + region + hours and returns a USD estimate | **Yes** |
| Wiring a monthly cron that snapshots prices and emits diffs to detect Azure price changes | **Yes** |
| Computing reservation breakeven (1-yr vs 3-yr vs Consumption) for a planned workload | **Yes** |
| Computing savings-plan TCO across compute SKUs in a region (requires preview API) | **Yes** |
| Powering a public-facing static "Our infra costs" page that refreshes nightly | **Yes** |
| Modeling a region migration's price delta before an architecture review | **Yes** |
| Surfacing per-region currency-converted prices in an internal cost calculator | **Yes** |
| Reconciling a customer's monthly Azure invoice line items against expected prices | **No** — wrong API; use **Cost Management Usage Details / Exports**, those carry actual billed `effectivePrice` |
| Computing showback / chargeback to internal business units | **No** — use **Cost Management Exports**, not the catalog |
| Audit-grade financial reporting (SOX, MCA contract reconciliation) | **No** — use the **EA / MCA Billing API**, this catalog has no SLA |
| Pricing for Azure Government, Azure China (21Vianet), or sovereign clouds | **No** — Commercial Cloud only |
| Pricing for Microsoft 365, Dynamics 365 SaaS bundles, GitHub Enterprise | **No** — these aren't Azure consumption meters |
| Asking "what is my current spend" | **No** — that's `Cost Management Query` API |

---

## API CONTRACT — THE ONE-PAGE REFERENCE

### Endpoint

```
GET https://prices.azure.com/api/retail/prices
```

No authentication. No subscription path parameter. Commercial cloud only.

### API versions

| Version | Behavior | When to use |
|---|---|---|
| *(omitted)* | Stable. Returns full meter set including nonprimary. **No** `savingsPlan` blocks. **No** `meterRegion` filter. | Legacy callers only. New callers should pin a version. |
| `?api-version=2023-01-01-preview` | Backward-compatible. Adds `savingsPlan[]` block on eligible rows. Adds `meterRegion='primary'` filter. **`$filter` values become case-sensitive.** | **Default for new callers.** |
| `?api-version=2021-10-01-preview` | Earliest version supporting `meterRegion='primary'`. | Niche; prefer the 2023 preview. |

### Query parameters

| Param | Example | Purpose |
|---|---|---|
| `api-version` | `2023-01-01-preview` | Pin the contract. |
| `$filter` | `serviceName eq 'Virtual Machines' and armRegionName eq 'eastus'` | OData filter on supported fields. |
| `currencyCode` | `'EUR'` (note the single quotes) | Switch reference currency. **Reference only — Microsoft bills in USD.** Quotes are required when interpolated into a URL string; some clients accept unquoted. |
| `meterRegion` | `'primary'` | Restrict to primary meters (preview API only). Single quotes required. |
| `$skip` | *(do not set manually)* | The server emits this inside `NextPageLink`. Follow the link verbatim. |

### `$filter` — supported fields (case sensitive on preview API)

```
armRegionName       e.g. 'eastus', 'westeurope', 'southindia'
Location            e.g. 'EU West', 'US East'        (display label; prefer armRegionName)
meterId             GUID
meterName           e.g. 'D14/DS14 Spot', 'F16s Spot'
productId           e.g. 'DZH318Z0BPVW'
skuId               e.g. 'DZH318Z0BPVW/00QZ'
productName         e.g. 'Virtual Machines D Series Windows'
skuName             e.g. 'D14 Spot'
serviceName         e.g. 'Virtual Machines', 'Azure Cosmos DB', 'Storage'
serviceId           e.g. 'DZH313Z7MMC8'
serviceFamily       one of the 26 values listed below
priceType           'Consumption' | 'DevTestConsumption' | 'Reservation'
armSkuName          e.g. 'Standard_F16s'
```

### `$filter` — supported operators

| Operator | Example | Notes |
|---|---|---|
| `eq` | `serviceName eq 'Virtual Machines'` | Equality. |
| `and` | `serviceName eq 'Virtual Machines' and armRegionName eq 'eastus'` | Logical AND. |
| `contains` | `contains(meterName, 'Spot')` | Substring match. |

**Not supported:** `or`, `ne`, `gt`, `lt`, `startswith`, `endswith`. For OR semantics, issue separate calls and merge client-side.

### `priceType` enum

| Value | Meaning |
|---|---|
| `Consumption` | Standard pay-as-you-go rate. **The default for production cost modeling.** |
| `DevTestConsumption` | Reduced rate for Dev/Test subscriptions (MSDN / Visual Studio subscribers). **Do not mix into production cost reports.** |
| `Reservation` | One-time price for a 1-year or 3-year reservation. The `retailPrice` is the **total** for the term, not per-hour. |

### `serviceFamily` enum (26 values; exhaustive as of 2026-01-06)

```
Analytics
Azure Arc
Azure Communication Services
Azure Security
Azure Stack
Compute
Containers
Data
Databases
Developer Tools
Dynamics
Gaming
Integration
Internet of Things
Management and Governance
Microsoft Syntex
Mixed Reality
Networking
Other
Power Platform
Quantum Computing
Security
Storage
Telecommunications
Web
Windows Virtual Desktop
```

Audit this list monthly; Microsoft does add families.

### Response envelope

```json
{
  "BillingCurrency": "USD",
  "CustomerEntityId": "Default",
  "CustomerEntityType": "Retail",
  "Items": [ /* up to 1000 rows; see schema below */ ],
  "NextPageLink": "https://prices.azure.com:443/api/retail/prices?$filter=...&$skip=1000",
  "Count": 1000
}
```

`NextPageLink` is `null` (or absent) on the final page. **Always** check for null/absent — do not assume `Count < 1000` means terminal (the server may return exactly 1000 on the last page).

### `Items[]` — full row schema

| Field | Type | Notes |
|---|---|---|
| `currencyCode` | string | `'USD'` unless `currencyCode` query param was set. |
| `tierMinimumUnits` | number | Minimum units required to access this tier (often `0.0`). |
| `retailPrice` | number | Microsoft retail price, no discount. |
| `unitPrice` | number | Same as `retailPrice` in current API; reserved for future tier semantics. |
| `armRegionName` | string | ARM region slug, e.g. `'eastus'`, `'westeurope'`. |
| `location` | string | Display label, e.g. `'US East'`, `'EU West'`. |
| `effectiveStartDate` | ISO 8601 string | When this price became effective. |
| `meterId` | GUID string | Unique meter ID. |
| `meterName` | string | e.g. `'D14/DS14 Spot'`, `'NC320dsxlRTX6Kv6 Spot'`. |
| `productId` | string | e.g. `'DZH318Z0BPVW'`. |
| `skuId` | string | e.g. `'DZH318Z0BPVW/00QZ'`. |
| `availabilityId` | string \| null | Sometimes present, often null. |
| `productName` | string | e.g. `'Virtual Machines D Series Windows'`. |
| `skuName` | string | e.g. `'D14 Spot'`. |
| `serviceName` | string | e.g. `'Virtual Machines'`. |
| `serviceId` | string | e.g. `'DZH313Z7MMC8'`. |
| `serviceFamily` | string | One of the 26 enum values above. |
| `unitOfMeasure` | string | e.g. `'1 Hour'`, `'1 GB/Month'`, `'10K Operations'`. |
| `type` | string | One of `'Consumption'`, `'DevTestConsumption'`, `'Reservation'`. |
| `isPrimaryMeterRegion` | boolean | `true` for the meter Microsoft uses to bill. |
| `armSkuName` | string | e.g. `'Standard_F16s'`. **The ARM SKU you'd put in a Bicep / Terraform manifest.** |
| `reservationTerm` | string | Only present when `type='Reservation'`. e.g. `'1 Year'`, `'3 Years'`. |
| `savingsPlan` | array \| absent | Only present on `2023-01-01-preview` API for eligible meters. Each element: `{ unitPrice, retailPrice, term }` where `term` is `'1 Year'` or `'3 Years'`. |

### Pagination contract

```
1. GET first URL.
2. Read response.Items[].
3. If response.NextPageLink is null/absent → stop.
4. Else GET response.NextPageLink verbatim. Goto 2.
```

Do **not** reconstruct page URLs by hand — the server may include cursor tokens beyond `$skip` in future. Follow what the server emits.

Page size is 1,000 rows. A broad query (e.g. `serviceFamily eq 'Compute'`) returns ~30k–80k rows depending on the day. A narrow query (`armRegionName eq 'eastus' and serviceName eq 'Virtual Machines'`) returns ~5k rows. A maximally narrow query (single `armSkuName` + single region + single `priceType`) returns ~1–10 rows.

---

## REFERENCE CALLS — COPY-PASTE STARTERS

Every example below uses `?api-version=2023-01-01-preview` to ensure savings-plan rates are present. Strip the version only if you knowingly want the legacy contract.

### Single SKU in a region (the smallest useful query)

```
GET https://prices.azure.com/api/retail/prices
  ?api-version=2023-01-01-preview
  &$filter=armRegionName eq 'eastus'
    and armSkuName eq 'Standard_D4s_v5'
    and priceType eq 'Consumption'
```

Returns every meter for that ARM SKU in eastus (typically Linux Consumption, Windows Consumption, Spot, Low Priority — separate rows per OS / pricing model).

### All Virtual Machines in a region (Consumption only, billing-relevant rows only)

Server-side filter to Consumption + region; client-side filter to `isPrimaryMeterRegion === true`:

```
GET .../api/retail/prices
  ?api-version=2023-01-01-preview
  &$filter=serviceName eq 'Virtual Machines'
    and armRegionName eq 'westeurope'
    and priceType eq 'Consumption'
  &meterRegion='primary'
```

Typical result: ~5–8k rows across ~20 pages.

### All reservations for a SKU (1-yr and 3-yr)

```
GET .../api/retail/prices
  ?api-version=2023-01-01-preview
  &$filter=armSkuName eq 'Standard_E64_v4'
    and priceType eq 'Reservation'
```

Each row's `retailPrice` is the **full term price**. Compute hourly equivalent as `retailPrice / (reservationTerm hours)` where `1 Year = 8760` and `3 Years = 26280`.

### All savings-plan eligible meters in a service family

```
GET .../api/retail/prices
  ?api-version=2023-01-01-preview
  &$filter=serviceFamily eq 'Compute'
    and priceType eq 'Consumption'
  &meterRegion='primary'
```

Filter client-side to rows where `item.savingsPlan && item.savingsPlan.length > 0`.

### Reference-currency budgeting (EUR)

```
GET .../api/retail/prices
  ?api-version=2023-01-01-preview
  &currencyCode='EUR'
  &$filter=serviceFamily eq 'Compute' and armRegionName eq 'westeurope'
```

**Mark every downstream display as "Reference price; Microsoft bills in USD."**

### Cosmos DB across regions (canonical "compare regions" pattern)

```
GET .../api/retail/prices
  ?api-version=2023-01-01-preview
  &$filter=serviceName eq 'Azure Cosmos DB'
    and priceType eq 'Consumption'
  &meterRegion='primary'
```

Group rows client-side by `armRegionName + meterName` to build a region matrix. Watch for slow drift on `serviceName` (this used to be `'Cosmos DB'`).

### Logical OR via two requests + client merge

```
# Call 1
GET .../api/retail/prices?$filter=armRegionName eq 'eastus2' and armSkuName eq 'Standard_D4s_v5'
# Call 2
GET .../api/retail/prices?$filter=armRegionName eq 'westus2' and armSkuName eq 'Standard_D4s_v5'
# Merge Items[] client-side; dedupe by meterId if needed.
```

OData `or` is **not** supported; this is the canonical workaround.

---

## PRODUCTION CALLER — REFERENCE IMPLEMENTATIONS

### Python (with pagination, backoff, `requests`)

```python
import time
import requests

BASE = "https://prices.azure.com/api/retail/prices"
API_VERSION = "2023-01-01-preview"

def fetch_all_prices(filter_expr: str, currency: str = "USD", meter_region: str | None = "primary"):
    """Yield every Items[] row across all pages. Backs off on 429/5xx."""
    params = {"api-version": API_VERSION, "$filter": filter_expr, "currencyCode": currency}
    if meter_region:
        params["meterRegion"] = f"'{meter_region}'"
    url = BASE
    backoff = 1.0
    pages = 0
    while url:
        resp = requests.get(url, params=params if pages == 0 else None, timeout=30)
        if resp.status_code in (429, 500, 502, 503, 504):
            if backoff > 60:
                resp.raise_for_status()
            time.sleep(backoff)
            backoff *= 2
            continue
        resp.raise_for_status()
        backoff = 1.0
        body = resp.json()
        for item in body.get("Items", []):
            yield item
        url = body.get("NextPageLink")  # already includes encoded $skip
        params = None  # do not re-attach params; NextPageLink is self-contained
        pages += 1

# Example: every Standard_D4s_v5 Consumption meter in eastus
rows = list(fetch_all_prices(
    "armRegionName eq 'eastus' and armSkuName eq 'Standard_D4s_v5' and priceType eq 'Consumption'"
))
```

### TypeScript / Node (`fetch`)

```ts
const BASE = "https://prices.azure.com/api/retail/prices";
const API_VERSION = "2023-01-01-preview";

export interface RetailPriceRow {
  currencyCode: string;
  retailPrice: number;
  unitPrice: number;
  armRegionName: string;
  location: string;
  effectiveStartDate: string;
  meterId: string;
  meterName: string;
  productId: string;
  skuId: string;
  productName: string;
  skuName: string;
  serviceName: string;
  serviceId: string;
  serviceFamily: string;
  unitOfMeasure: string;
  type: "Consumption" | "DevTestConsumption" | "Reservation";
  isPrimaryMeterRegion: boolean;
  armSkuName: string;
  reservationTerm?: "1 Year" | "3 Years";
  savingsPlan?: Array<{ unitPrice: number; retailPrice: number; term: "1 Year" | "3 Years" }>;
}

export async function* fetchAllPrices(filter: string, currency = "USD", meterRegion: string | null = "primary"): AsyncGenerator<RetailPriceRow> {
  const initial = new URL(BASE);
  initial.searchParams.set("api-version", API_VERSION);
  initial.searchParams.set("$filter", filter);
  initial.searchParams.set("currencyCode", currency);
  if (meterRegion) initial.searchParams.set("meterRegion", `'${meterRegion}'`);

  let url: string | null = initial.toString();
  let backoff = 1000;
  while (url) {
    const resp = await fetch(url);
    if ([429, 500, 502, 503, 504].includes(resp.status)) {
      if (backoff > 60_000) throw new Error(`prices.azure.com unavailable: ${resp.status}`);
      await new Promise(r => setTimeout(r, backoff));
      backoff *= 2;
      continue;
    }
    if (!resp.ok) throw new Error(`prices.azure.com ${resp.status}: ${await resp.text()}`);
    backoff = 1000;
    const body = await resp.json() as { Items: RetailPriceRow[]; NextPageLink: string | null };
    for (const row of body.Items) yield row;
    url = body.NextPageLink ?? null;
  }
}
```

### Bash (one-shot, no pagination — for ad hoc inspection only)

```bash
curl -s 'https://prices.azure.com/api/retail/prices?api-version=2023-01-01-preview' \
  --data-urlencode "\$filter=armRegionName eq 'eastus' and armSkuName eq 'Standard_D4s_v5' and priceType eq 'Consumption'" \
  -G \
  | jq '.Items[] | {meterName, retailPrice, unitOfMeasure, type}'
```

`-G --data-urlencode` is the right way to embed a `$filter` with single-quoted strings; bash's own quoting will eat them otherwise. Do **not** ship a one-shot `curl` in a production job — it skips pagination and has no backoff.

---

## CACHING DOCTRINE

Prices change at most monthly (Microsoft typically aligns price changes to calendar month boundaries). A production caller should:

| Layer | TTL | Key |
|---|---|---|
| HTTP cache (Varnish / CDN / in-process) | **24h minimum** | `(url, currency, api-version)` |
| Application snapshot table | **30 days** | `(serviceFamily, armRegionName, currencyCode, captured_at_utc)` |
| Drift-detection diff job | runs **daily** | compares today's snapshot to yesterday's; alerts on row-level price change |

A caller that hits `prices.azure.com` on every dashboard render is a misconfiguration. The endpoint has no published rate limit, no published SLA, and no Anthropic-style overflow channel — the only way to keep it fast and reliable is to cache.

Emit two metrics:
- `azure_retail_prices_cache_hits_total`
- `azure_retail_prices_origin_calls_total`

A sustained `origin_calls / hits > 0.05` is a regression.

---

## ANTI-PATTERNS

| Anti-pattern | Symptom | Correct |
|---|---|---|
| Lowercase filter values on `2023-01-01-preview` | `Items: []`, no error | Match the case Microsoft uses: `'Virtual Machines'`, `'Compute'`, `'Reservation'` |
| Omitting `?api-version=2023-01-01-preview` | `item.savingsPlan` always `undefined` | Pin the preview version on every call that needs savings-plan or `meterRegion='primary'` |
| Capping at the first page | Silently undercounted SKUs; aggregate prices low by 10–100× | Walk `NextPageLink` to `null` |
| Reconstructing page URLs by hand (`?$skip=1000`, `?$skip=2000`) | Brittle when Microsoft adds cursor tokens | Follow `NextPageLink` verbatim |
| Reconciling non-USD prices to invoice | Customer reports "your dashboard says €1,847 but Azure billed €1,902" | Display non-USD with a **"reference rate"** disclaimer; reconcile only against USD |
| Mixing `Consumption` + `DevTestConsumption` rows in a SKU price list | Apparent 50% discount that doesn't exist on EA / production | Filter to `priceType eq 'Consumption'` for production cost models |
| Treating `Reservation.retailPrice` as hourly | TCO off by 8,760× (1-yr) or 26,280× (3-yr) | Divide by term hours; document the math at the call site |
| Trying `or` / `ne` / `startswith` in `$filter` | 400 Bad Request or empty `Items[]` | Issue separate calls and merge client-side |
| Hard-coding `serviceName` strings without monitoring | Filter quietly returns zero rows after Microsoft renames the product | Periodic enum snapshot + diff alert; prefer `serviceFamily` |
| Mixing `isPrimaryMeterRegion: true` and `false` rows in an aggregate | Double-counted prices in regions with multiple meter regions | Filter client-side to `isPrimaryMeterRegion === true` (or use `&meterRegion='primary'` on preview API) |
| No backoff on 429 / 5xx | Cascading failure spreads from `prices.azure.com` to your dashboard | Exponential backoff with jitter, max 5 retries, cap 60 s |
| Calling on every dashboard render | Burns API capacity; risk of being throttled with no warning | Cache for ≥24h keyed on `(filter, currency, api-version)` |
| Using this API for invoice reconciliation | Numbers don't tie to the invoice; finance team loses trust | Use Cost Management Usage Details / Exports instead |
| Querying for Government / China prices | Returns commercial prices, mislabels them | This API is **Commercial Cloud only**. Don't use it for sovereign clouds. |

---

## VERIFICATION CHECKLIST

Before merging a caller, dashboard, or pipeline that reads from `prices.azure.com`:

- [ ] URL contains `?api-version=2023-01-01-preview` (or the version is documented + intentional)
- [ ] All `$filter` string literals use the exact casing Microsoft uses (`'Virtual Machines'`, `'Compute'`, `'Reservation'`, etc.)
- [ ] Pagination loop terminates on `NextPageLink === null` and follows the link verbatim
- [ ] Backoff implemented: exponential, jittered, capped at 60 s, max 5 retries on 429/5xx, no retry on 4xx
- [ ] Response cached with TTL ≥ 24 h, keyed on `(filter, currency, api-version)`
- [ ] Cache hit / origin call metrics emitted
- [ ] Non-USD outputs labeled "reference rate; Microsoft bills in USD"
- [ ] `Reservation` rows divide `retailPrice` by term hours when displayed alongside Consumption hourly
- [ ] `DevTestConsumption` excluded from production cost models (or explicitly opt-in)
- [ ] Aggregations filter to `isPrimaryMeterRegion === true` (or use `&meterRegion='primary'`)
- [ ] Logical OR semantics implemented as separate calls + client merge (no `$filter ... or ...`)
- [ ] `serviceName` filters have a monthly drift audit
- [ ] No assumption that this API matches an Azure invoice — reconciliation goes through Cost Management instead
- [ ] Commercial Cloud only — Government / China / sovereign callers redirected to the appropriate sovereign endpoint

---

## SISTER SKILLS

- `azure-pg-flex` — Azure Postgres Flexible Server observability (metrics two-layer model, REST surface)
- `kusto-kql-api` — Kusto / KQL telemetry-query API (five REST endpoints, v1-vs-v2 frames)
- `addons-and-building-blocks` — Helm library + ArgoCD App-of-Apps deployment shape

---

## REFERENCE

- Microsoft docs: <https://learn.microsoft.com/en-us/rest/api/cost-management/retail-prices/azure-retail-prices>
- Live endpoint: <https://prices.azure.com/api/retail/prices>
- Supported currencies: <https://learn.microsoft.com/en-us/azure/cost-management-billing/microsoft-customer-agreement/microsoft-customer-agreement-faq#how-is-azure-priced-under-the-microsoft-customer-agreement>
- Cost Management Usage Details (for invoice reconciliation, **not** this API): <https://learn.microsoft.com/en-us/rest/api/consumption/usage-details>
