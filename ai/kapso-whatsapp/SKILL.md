---
name: kapso-whatsapp
description: >-
  MUST USE when integrating WhatsApp through Kapso (kapso.ai) — "WhatsApp for
  developers". Trigger phrases and patterns: "kapso", "api.kapso.ai",
  "KAPSO_API_KEY", "send a WhatsApp message", "WhatsApp Cloud API" via a
  proxy, "@kapso/whatsapp-cloud-api", "@kapso/cli" / `kapso login` /
  `kapso whatsapp messages send`, "@kapso/workflows" / `kapso pull` /
  `kapso push`, "@kapso/chat-adapter" (Chat SDK), "kapso MCP" /
  `https://api.kapso.ai/mcp`, "WhatsApp webhook" / `X-Webhook-Signature`,
  "WhatsApp template" approval/sync, "WhatsApp Flows", "setup link" /
  onboard customers to WhatsApp, "broadcast" template campaigns, "Kapso
  sandbox", "business-scoped user ID" / BSUID, "24-hour window", personal
  WhatsApp AI agents (OpenClaw / Hermes Agent / n8n / Chat SDK), "Kapso
  Agent" runs API, or files containing `@kapso/` in package.json,
  `kapso.yaml`, `.kapso/` directories, env vars KAPSO_API_KEY /
  KAPSO_PHONE_NUMBER_ID / KAPSO_WEBHOOK_SECRET. Covers the three Kapso APIs
  (WhatsApp Meta-mirror, Platform, Workflows), the TypeScript SDK, the CLI,
  Project MCP + Docs MCP, webhooks (kapso/meta kinds, HMAC verification,
  buffering/ordering/retries), workflows + serverless functions, customer
  onboarding + Tech Provider paths, and agent runtime integrations.
license: BSD-3-Clause
compatibility: opencode
metadata:
  domain: ai
  tool: kapso
  vendor: kapso
  category: whatsapp-messaging-api
  runtime: cloud-api + cli + mcp + typescript-sdk
  api-surfaces: whatsapp-meta-mirror + platform-v1 + workflows
  languages: typescript + rest
---

# Kapso — WhatsApp integration for developers and AI agents

Kapso is "WhatsApp for developers": a hosted platform that connects WhatsApp
Business numbers (its own pre-verified pool, your SIM, or your customers'
numbers) and exposes them through **three APIs behind one project API key**,
a TypeScript SDK that mirrors Meta's Cloud API, a CLI, webhooks, visual/code
workflows, serverless functions, and MCP servers purpose-built for AI
agents. This skill is organized as phases, each owned by a companion agent:

| Phase | Owns | Agent |
|-------|------|-------|
| A — Messaging & templates | send text/media/interactive/template via SDK + Meta-mirror API, 24-hour window, template lifecycle + sync, media, marketing opt-outs, BSUID sends | `kapso-messaging-engineer` |
| B — Numbers, onboarding & sandbox | connect/provision numbers, instant setup, sandbox testing, customers + setup links, Meta billing modes, Tech Provider paths, phone health | `kapso-onboarding-operator` |
| C — Webhooks & events | project vs per-number webhooks, kapso vs meta kinds, HMAC verification, buffering/ordering/retries/auto-pause, event catalog, v1→v2 migration | `kapso-webhook-engineer` |
| D — Workflows & functions | canvas + local workflow dev (`kapso pull/push`, `@kapso/workflows`), node types, start/resume API, burst limits, Cloudflare-Worker functions | `kapso-workflow-automation-engineer` |
| E — Agent integrations: MCP, CLI, runtimes | Project MCP + Docs MCP, CLI for agents, Chat SDK / OpenClaw / Hermes / n8n runtimes, Kapso Agent runs API + approvals | `kapso-agent-integrator` |

## CORE PRINCIPLES (non-negotiable)

1. **Three APIs, one API key.** WhatsApp API at
   `https://api.kapso.ai/meta/whatsapp/v24.0` mirrors Meta's Graph API
   shapes, "so existing Cloud API code ports over with a base URL change".
   Platform API and Workflows API share
   `https://api.kapso.ai/platform/v1` (same service, split only in the
   reference). Authenticate everything with the `X-API-Key` header; the
   WhatsApp API additionally accepts `Authorization: Bearer` so unmodified
   Meta code keeps working. Keys are created in the dashboard under
   **Integrations → API keys**; wire them as `KAPSO_API_KEY`, never
   hardcoded. All requests are HTTPS (plain HTTP rejected); most responses
   wrap a `data` object, list endpoints add a `meta` pagination object.

2. **The 24-hour window governs every send.** Free-form messages (text,
   media, interactive) require an open customer-service window; only an
   **approved template** can start or reopen a conversation. Templates are
   reviewed by Meta (typically up to 24h; statuses `PENDING` → `APPROVED` /
   `REJECTED` / `DISABLED`) and can be synced from WhatsApp Manager with
   `POST /whatsapp_templates/sync`.

3. **Never assume a phone number in payloads.** WhatsApp now sends identity
   without a phone number (**business-scoped user IDs**). Kapso adds
   `business_scoped_user_id`, `parent_business_scoped_user_id`, and
   `username` to relevant payloads — update parsers before assuming
   `phone_number`, `wa_id`, `from`, or `to` exist. Send to a BSUID with
   `"recipient": "US.13491208655302741918"` instead of `to`.

4. **Verify webhooks on the RAW body, timing-safe, then ack fast.** Kapso
   signs every webhook with HMAC SHA256 of the raw JSON payload in
   `X-Webhook-Signature`. Verify against the bytes as they arrived
   (`express.raw`, `request.get_data()`) — re-serializing a parsed body
   fails; compare with `crypto.timingSafeEqual` (guard length first, or a
   forged signature 500s instead of 401s). Return `200` within **10
   seconds**; process asynchronously; dedupe on `X-Idempotency-Key`.
   Failed deliveries retry at 10s / 40s / 90s (~2.5 min total), and a
   webhook is **auto-paused** when, inside a 15-minute window, ≥20
   deliveries + ≥10 failures + ≥85% failure rate all hold.

5. **Pick webhook scope and kind deliberately.** *Project webhooks* carry
   project-wide events (connection lifecycle, workflow executions,
   `project.event`, `kapso_agent.run.*`) — no message events. *WhatsApp
   webhooks* are per phone number, in two kinds: `kapso` (default —
   event-filtered, structured payloads, optional buffering) and `meta`
   (raw Meta payload forwarding, no filtering/buffering, one per number,
   `X-Idempotency-Key` = SHA256 of payload). With buffering on, EVERY
   delivery uses the batch envelope — check `X-Webhook-Batch` / `batch`
   rather than assuming shape.

6. **Two rate limiters plus Meta's.** Kapso enforces a fixed per-minute
   window per API key (Free/Legacy 100, Pro 500, Platform 1000, Enterprise
   2000; `X-RateLimit-Limit`/`-Remaining`, 429 + `Retry-After`) and a
   second per-second **per-workflow burst limit** on execution starts
   (Free/Legacy 5, Pro 15, Platform/Enterprise 30;
   `X-Burst-RateLimit-*`). Meta enforces its own throughput and messaging
   tiers on top — a request can pass Kapso and still be rejected upstream.
   Broadcasts are exempt from self-throttling: Kapso paces them internally.

7. **Workflow definitions are lock-versioned replacement sets.** `PATCH
   /workflows/{id}` must include the latest `lock_version`; inside
   `definition`, `nodes` and `edges` are **replacement sets when present**
   (send one node and every other node is removed — omit a collection to
   leave it unchanged). Prefer the CLI loop (`kapso pull` → edit →
   `kapso build` → `kapso push --dry-run` → `kapso push`), which protects
   dirty files and checks stale remote state.

8. **Sandbox before production, and know its limits.** The Kapso sandbox
   (WhatsApp → Sandbox, 6-character activation code, expires in 15
   minutes) tests text and interactive flows — but **cannot send
   templates, sync templates, message multiple recipients, or accept
   BSUID recipients**. The free plan grants one lifetime Kapso-managed
   number per user (on the user's default first project; pre-verified
   only when pool capacity allows, with fallback to standard
   provisioning); unused numbers (no production messages in 30 days) are
   auto-released, and deleting the number does not reset the claim.

9. **Agent access is a blast-radius decision.** Docs MCP
   (`https://docs.kapso.ai/mcp`) reads documentation only. Project MCP
   (`https://api.kapso.ai/mcp`) and the CLI both operate real numbers —
   MCP for agents without shell access, CLI when the agent has a
   terminal. Message sends, webhook changes, template creation, and
   number provisioning are gated, human-approved actions (the
   read-mostly / gated-write posture of `operations/agentic-k8s-ops`
   generalizes here).

## Phase A — Messaging & templates (`kapso-messaging-engineer`)

SDK (`npm install @kapso/whatsapp-cloud-api`) or REST — same shapes:

```typescript
import { WhatsAppClient } from '@kapso/whatsapp-cloud-api';

const client = new WhatsAppClient({
  baseUrl: 'https://api.kapso.ai/meta/whatsapp',
  kapsoApiKey: process.env.KAPSO_API_KEY!
});
await client.messages.sendText({
  phoneNumberId: '647015955153740',
  to: '15551234567',
  body: 'Hello! Your order #12345 has been shipped.'
});
```

```bash
curl -X POST 'https://api.kapso.ai/meta/whatsapp/v24.0/{phone_number_id}/messages' \
  -H 'X-API-Key: YOUR_API_KEY' -H 'Content-Type: application/json' \
  -d '{"messaging_product": "whatsapp", "to": "15551234567",
       "type": "text", "text": {"body": "Hello!"}}'
```

- **Two SDK modes**: `{ accessToken }` calls Meta's Graph API directly
  (no Kapso storage/query); `{ baseUrl, kapsoApiKey }` proxies through
  Kapso and unlocks conversations/messages-history/contacts/call-logs
  queries, storage, Supabase sync, and extra `fields=kapso(...)` response
  fields. The SDK quickstart shows `baseUrl:
  'https://app.kapso.ai/api/meta/'` while every send guide and the Chat
  SDK default use `https://api.kapso.ai/meta/whatsapp` — prefer the
  latter; verify against current docs before "fixing" either.
- **Message types**: text, image, video, audio/voice, document, sticker,
  location + location request, contacts + contact-info request, reaction,
  interactive (buttons ≤3, lists, products, CTA URL, WhatsApp Flows,
  carousel), Brazil Pix order messages, mark-as-read (+ typing
  indicator). Templates via `send-a-message` with `type: template` or the
  dedicated marketing-message endpoint.
- **Templates**: create in Kapso (**WhatsApp → Templates**) or in
  WhatsApp Manager then **Sync from WhatsApp** (`POST
  /whatsapp_templates/sync`; disabled for sandbox numbers). Categories
  matter (utility vs marketing mis-categorization is a top rejection
  reason). Marketing opt-outs: contacts can stop marketing messages —
  mirror preference via the Platform contacts marketing-preferences
  endpoints before campaign sends.
- **Media**: upload (returns media ID for sends), get URL, delete,
  download via short-lived authenticated token; Platform media upload
  also accepts public URLs.
- WhatsApp usernames, business profile get/update, block/unblock users,
  and calls (connect/pre-accept/accept/reject/terminate + permission
  state) all live on the same Meta-mirror surface. Display-name change
  requests (Meta review 24–48h, some approved instantly) go through the
  Platform API instead: `POST
  /platform/v1/whatsapp/phone_numbers/{id}/display_name_requests`.

## Phase B — Numbers, onboarding & sandbox (`kapso-onboarding-operator`)

- **Connect a number**: `kapso setup` (resolves project + customer,
  generates a setup link) or dashboard. Paths: **instant setup**
  (default; Kapso-managed, opportunistically pre-verified — falls back to
  standard provisioning + OTP), bring-your-own-SIM, coexistence
  (WhatsApp Business App alongside API), local numbers via your own
  Twilio account, or manual Meta configuration.
- **Customer onboarding** (SaaS platforms): create a customer, then a
  setup link:

```bash
curl -X POST https://api.kapso.ai/platform/v1/customers/{customer_id}/setup_links \
  -H "X-API-Key: YOUR_API_KEY" -H "Content-Type: application/json" \
  -d '{"setup_link": {
        "success_redirect_url": "https://your-app.com/whatsapp/success",
        "failure_redirect_url": "https://your-app.com/whatsapp/failed",
        "allowed_origins": ["https://your-app.com"],
        "meta_billing_mode": "partner_managed"}}'
```

  Response `data.url` (`https://setup.kapso.ai/s/…`) goes to the
  customer. Key fields: `allowed_connection_types` (default
  `["coexistence", "dedicated"]`; a single value auto-selects),
  `meta_billing_mode` `customer_managed` (default) | `partner_managed` —
  **cannot be changed after creation**; `provision_phone_number`
  (non-US requires your own telephony credentials), `language`
  (`en|es|pt|hi|id|ar`). Detect completion via the
  `whatsapp.phone_number.created` project webhook, manage/revoke/expire
  links via the setup-links API.
- **Tech Provider**: onboard with your own Meta app (embedded signup),
  with or without a Multi-partner Solution; or your infrastructure with
  Kapso managed billing.
- **Health**: `GET /platform/v1/whatsapp/phone_numbers/{id}/health`
  checks Meta APIs + Kapso services (surfaces e.g. payment-method
  issues). Template send failures are frequently Meta payment/business
  setup problems — see the payment-issues guide.
- **Sandbox**: per CORE PRINCIPLE 8. Route sandbox traffic to an agent,
  workflow, or webhooks from **WhatsApp → Configurations**.

## Phase C — Webhooks & events (`kapso-webhook-engineer`)

Register a per-number webhook (kind `kapso`):

```bash
curl -X POST 'https://api.kapso.ai/platform/v1/whatsapp/phone_numbers/{phone_number_id}/webhooks' \
  -H 'X-API-Key: YOUR_API_KEY' -H 'Content-Type: application/json' \
  -d '{"whatsapp_webhook": {
        "kind": "kapso",
        "url": "https://your-app.com/webhooks/whatsapp",
        "events": ["whatsapp.message.received"],
        "secret_key": "your-secret-key"}}'
```

- **Per-number events**: `whatsapp.message.received|sent|delivered|read|
  failed`, `whatsapp.conversation.created|ended|inactive`,
  `whatsapp.contact.identity_changed`.
- **Project events**: `whatsapp.phone_number.created|deleted|offboarded|
  disconnected|reconnected`, `whatsapp.account.disabled|restricted|
  reinstated|violation` (WABA-level Meta enforcement),
  `workflow.execution.handoff|failed`, `project.event`,
  `kapso_agent.run.approval_required|completed|failed|cancelled`.
- **Headers** (kapso kind): `X-Webhook-Event`, `X-Webhook-Signature`
  (HMAC-SHA256 hex), `X-Idempotency-Key` (UUID),
  `X-Webhook-Payload-Version: v2`; batched deliveries add
  `X-Webhook-Batch: true` + `X-Batch-Size`. Meta kind:
  `X-Idempotency-Key` = SHA256 of payload, exact Meta body — parse with
  `normalizeWebhook()` from `@kapso/whatsapp-cloud-api/server`.
- **Buffering** (only `whatsapp.message.received`): debounce window 1–60s
  (default 5), max batch 1–100 (default 50), per-conversation buffers;
  envelope `{type, batch: true, data: [...], batch_info}`. **Ordering**:
  sequence-based per conversation with a 30-second timeout after which
  delivery proceeds out of order. **Origin filter**:
  `message.kapso.origin` = `cloud_api` | `business_app` |
  `history_sync` — skip `business_app` to avoid reprocessing manual
  team sends.
- **Delivery ops**: retries + auto-pause per CORE PRINCIPLE 4; paused
  webhooks set `active: false`, mark pending deliveries failed, email
  all project members; re-enable from **Integrations → Webhooks**.
  Inspect attempts with `GET /platform/v1/webhook_deliveries` or the
  dashboard. New webhooks default to payload v2; migrate v1 via the
  legacy guide.

## Phase D — Workflows & functions (`kapso-workflow-automation-engineer`)

A workflow is a directed graph: Start node → action nodes (send_text /
send_template / send_interactive / function / webhook / set_variable /
call / handoff / emit event) → wait_for_response / decide (AI or
function) / agent nodes. Two equivalent build paths — dashboard canvas or
local repo:

```bash
npm install -g @kapso/cli            # Node.js >= 20.19
npm install --save-dev @kapso/workflows
kapso login && kapso link --project <project-id>
kapso pull                            # writes kapso.yaml, .kapso/, workflows/, functions/
# edit workflows/<slug>/workflow.js (camelCase) or definition.json (snake_case)
kapso build && kapso push --dry-run && kapso push workflow <slug>
```

- `@kapso/workflows` compiles idiomatic camelCase
  (`workflow.addNode("classify", { type: "decide", decisionType: "ai",
  providerModel: "gpt-5-mini", conditions: [...] })`) to the Platform
  API's snake_case JSON. Local sources reference by slug
  (`functionSlug`, `workflowSlug`); direct API calls use IDs. Keep
  `.kapso/remote-map.json` committed in shared repos.
- **Start/resume via API** (workflow must be `active` with an active API
  trigger): `POST /platform/v1/workflows/{id}/executions` → `202` with
  `id` + `tracking_id` (an immediate GET can 404 — the row is created
  when the queued job picks up); resume waiting executions with `POST
  /platform/v1/workflow_executions/{id}/resume` — `message`/`variables`
  at TOP level (not under `workflow_execution`), one pending resume at a
  time (`409` otherwise). Context: `{{vars.*}}`, `{{context.*}}`,
  `{{system.trigger_type}}` = `api_call`, `{{last_user_input}}`.
- **Functions** run on Cloudflare Workers: define `async function
  handler(request, env)` — **no `export default`** (Kapso wraps it).
  Invoke at `https://api.kapso.ai/platform/v1/functions/{id}/invoke`
  (`X-API-Key` unless `public_endpoint: true`); new functions use
  `invoke_response_mode: passthrough`; `env.KV` for persistence;
  secrets injected as env vars (values never listed back). Doc
  discrepancy: the functions overview says "The Kapso CLI does not
  manage functions yet" (create/update/deploy via dashboard or API),
  while the build-locally guide shows `kapso pull` writing
  `functions/<slug>/` and `kapso push function <slug>` syncing function
  source — verify against current docs before "fixing" either; treat
  deploy as dashboard/API.
- Project events (`POST /events`, lowercase dot-segmented names) trigger
  workflows and feed **Findings** (AI-detected recurring conversation
  problems with evidence, investigations, addressed/dismissed states).

## Phase E — Agent integrations: MCP, CLI, runtimes (`kapso-agent-integrator`)

- **Project MCP** — `https://api.kapso.ai/mcp` (streamable HTTP). Auth:
  browser sign-in (pick one project) or API key via `Authorization:
  Bearer` **or** `X-API-Key`:

```bash
claude mcp add --transport http kapso https://api.kapso.ai/mcp \
  --header "Authorization: Bearer $KAPSO_API_KEY"
codex mcp add kapso --url https://api.kapso.ai/mcp --bearer-token-env-var KAPSO_API_KEY
```

  Grouped tools take `action` + `params` (use `action: "help"` for
  required params): `status`, `search_docs`, `customers`
  (`list|get|create|update|delete`), `setup_links`
  (`list|create|update|revoke`), `whatsapp_numbers`
  (`list|get|resolve|health|start_setup|create|update|delete`),
  `whatsapp_conversations` (`list|get|set_status`), `whatsapp_messages`
  (`list|get|send|mark_read`), `whatsapp_templates`
  (`list|get|create`), `whatsapp_webhooks`
  (`list|get|create|update|delete`), `findings`
  (`list|get|read_evidence|start_investigation|dismiss|mark_addressed`).
  The `send`/`create`/`delete`/`start_setup` actions mutate — gate them.
- **Docs MCP** — `https://docs.kapso.ai/mcp`, documentation search only.
  `llms.txt` at `https://docs.kapso.ai/llms.txt` indexes every page as
  fetchable `.md`. Agent skills for codebases: `npx skills add
  gokapso/agent-skills`.
- **CLI for agents with shell**: install via `curl -fsSL
  https://kapso.ai/install.sh | bash` or `npm install -g @kapso/cli`;
  `KAPSO_API_KEY` makes it headless (CI/containers); `--output json`
  (default for most commands) pipes into `jq`.
- **Agent runtimes for personal WhatsApp agents**: Chat SDK
  (`npm install chat @kapso/chat-adapter @chat-adapter/state-memory`;
  env `KAPSO_API_KEY` + `KAPSO_PHONE_NUMBER_ID` + `KAPSO_WEBHOOK_SECRET`;
  webhook route `bot.webhooks.kapso(request)`; buttons ≤3, labels 1–20
  chars); OpenClaw (`openclaw plugins install
  clawhub:@kapso/openclaw-whatsapp`); Hermes Agent (`hermes plugins
  install gokapso/hermes-agent-plugin --enable` — see `ai/hermes-agent`);
  n8n official Kapso node; or plain webhooks.
- **Kapso Agent** (the project-level agent in the dashboard/Slack/API —
  not the workflow agent node): `GET /platform/v1/kapso-agent/modes`
  (only modes whose `available_invocations` includes `api` accept runs),
  sessions per mode, `POST /platform/v1/kapso-agent/runs` `{mode, input:
  {prompt}, metadata}` → async run; statuses `queued|running|paused|
  waiting_for_approval|completed|failed|cancelled`; pause/resume/cancel;
  approve/reject tool calls (surfaced by the
  `kapso_agent.run.approval_required` project webhook). Only runs
  created with the same API key are retrievable. Runs consume AI
  credits.

## Read-only tools (`tools/`)

| Script | What it answers | Owner agent |
|--------|-----------------|-------------|
| `kapso-api-probe.sh` | Is the API reachable/authorized; numbers, customers, rate-limit headroom | `kapso-onboarding-operator` |
| `kapso-webhook-audit.sh` | What webhooks exist (project + per-number), recent delivery outcomes, paused endpoints | `kapso-webhook-engineer` |
| `kapso-workflow-inventory.sh` | Which workflows/functions exist, statuses, recent execution history | `kapso-workflow-automation-engineer` |

All three are strictly read-only (GET-only against the Platform API),
take the key from `KAPSO_API_KEY` (never an argument, never printed),
degrade gracefully without credentials, and never create, modify, or
delete anything.

## MCP SURFACE

Two official remote servers, both streamable HTTP:

| Server | Endpoint | Auth | Posture |
|--------|----------|------|---------|
| Project MCP | `https://api.kapso.ai/mcp` | browser sign-in OR `Authorization: Bearer` / `X-API-Key` project key | reads AND writes — `whatsapp_messages action=send`, `whatsapp_numbers action=start_setup/create/delete`, `setup_links action=create/revoke`, `whatsapp_webhooks action=create/update/delete`, `whatsapp_templates action=create`, `customers action=create/update/delete` all mutate: **gate them** |
| Docs MCP | `https://docs.kapso.ai/mcp` | none | read-only documentation search |

Client wiring (Claude Code / Codex / Cursor) is in Phase E. Guardrails:
connect an agent with the least surface it needs (Docs MCP for
context-only tasks); a project API key hands the agent the whole
project, so keep human confirmation on mutating tool actions; per this
repo's doctrine (`operations/agentic-k8s-ops`), list/get/help actions
are free for analysis while sends, provisioning, webhook changes, and
template creation are gated, human-approved actions. Pair with the
read-only probes in `tools/` rather than granting broader access.

## Anti-patterns

| Anti-pattern | Why it's wrong | Instead |
|---|---|---|
| Free-form message outside the 24-hour window | Non-template messages require an open customer-service window | Approved template to start/reopen, then free-form |
| Parsing payloads assuming `phone_number`/`from` present | BSUID-only identity breaks the parser | Handle `business_scoped_user_id` / `recipient`; see BSUID guide |
| Verifying signature on `JSON.stringify(req.body)` | Key order/whitespace/unicode differ from signed bytes | Raw body (`express.raw`, `get_data()`) |
| `===` signature comparison | Timing attacks; missing-header throws → 500 | Length-guarded `crypto.timingSafeEqual` → 401 |
| Slow webhook handler (>10s) | Kapso retries, then auto-pauses at 85% failure | Ack 200 immediately, process in background jobs |
| Assuming single-message payloads with buffering on | Every buffered delivery uses the batch envelope | Check `X-Webhook-Batch` / `body.batch` |
| Processing `business_app` origin messages as inbound automation triggers | Your own team's manual sends loop back | Filter on `message.kapso.origin` |
| PATCH workflow definition without `lock_version` / with partial `nodes` | Overwrites concurrent edits; replacement-set semantics delete omitted nodes | Latest `lock_version`; omit collections you aren't changing; prefer `kapso push` |
| Polling `GET /workflow_executions/{id}` immediately after `202` and treating 404 as failure | Row is created when the queued job starts | Retry after a moment |
| Sleeping a fixed time on 429 | `Retry-After` is authoritative; burst limiter resets per second | Exponential backoff honoring `Retry-After` |
| Throttling broadcast sends client-side | Kapso paces broadcasts internally | Create → add recipients (≤1000/call, draft) → send/schedule |
| Testing templates against the sandbox | Sandbox cannot send or sync templates | Connect a production number |
| `export default` in a Kapso function | Kapso wraps and calls `handler(request, env)` | Top-level `async function handler(request, env)` |
| Hardcoding the API key / passing it as a CLI argument | Credential leak | `KAPSO_API_KEY` env var |
| Giving a coding agent Project MCP for a docs question | Full project access for a read task | Docs MCP / `llms.txt` |
| Changing `meta_billing_mode` on a live setup link | Immutable after creation | Create a new setup link |

## Verification checklist (before declaring a Kapso integration done)

- [ ] API key wired via `KAPSO_API_KEY`; no key in source, args, or logs
      (`kapso-api-probe.sh` reports authorized).
- [ ] Sends handle the 24-hour window: template path exists for
      conversation-opening messages; template statuses checked before use.
- [ ] Payload parsers tolerate BSUID-only identity (no hard dependency on
      `phone_number` / `wa_id` / `from` / `to`).
- [ ] Webhook endpoint: raw-body HMAC verification, timing-safe compare,
      401 on bad signature, 200 within 10s, `X-Idempotency-Key` dedupe,
      batch envelope handled (`kapso-webhook-audit.sh` shows healthy,
      unpaused webhooks).
- [ ] Webhook scope/kind chosen deliberately (project vs per-number,
      kapso vs meta) and the event list is minimal.
- [ ] 429 handling honors `Retry-After` on both the per-minute and
      workflow-burst limiters; Meta-side rejections surfaced distinctly.
- [ ] Workflow edits go through `kapso pull/build/push` (or carry
      `lock_version` + full replacement sets); executions start/resume
      verified (`kapso-workflow-inventory.sh`).
- [ ] Functions follow the `handler(request, env)` contract; secrets via
      function secrets, not code.
- [ ] Sandbox used for message-flow tests; production number connected
      before template work; phone health checked.
- [ ] Agent access least-surface: Docs MCP for context, Project MCP/CLI
      only where operation is required, mutating MCP actions and sends
      human-gated.

## SUBAGENT ORCHESTRATION

This skill drives a **5-agent Kapso team** in `.claude/agents/`:

| Agent | Owns |
|---|---|
| `kapso-messaging-engineer` | Phase A — SDK + Meta-mirror sends (all message types), 24-hour window, templates (create/sync/lifecycle/opt-outs), media, business profile, usernames, calls, BSUID sends |
| `kapso-onboarding-operator` | Phase B — number connection paths (instant setup / BYO SIM / coexistence / Twilio local / manual), customers + setup links, Meta billing modes, Tech Provider, phone health, sandbox; owns `kapso-api-probe.sh` |
| `kapso-webhook-engineer` | Phase C — webhook scopes/kinds, HMAC verification, buffering/ordering/retry/auto-pause, event catalog, deliveries triage, v1→v2 migration; owns `kapso-webhook-audit.sh` |
| `kapso-workflow-automation-engineer` | Phase D — canvas + local workflow dev, `@kapso/workflows` node table, start/resume API + burst limits, Cloudflare-Worker functions, project events + findings; owns `kapso-workflow-inventory.sh` |
| `kapso-agent-integrator` | Phase E — Project MCP + Docs MCP wiring and tool gating, CLI-for-agents, Chat SDK / OpenClaw / Hermes / n8n runtimes, Kapso Agent runs API + approval webhooks |

**Handoffs:** Hermes-side plugin mechanics → `ai/hermes-agent`
(`hermes-automation-gateway-engineer`); agentic blast-radius doctrine →
`operations/agentic-k8s-ops`; generic webhook-receiver infrastructure and
CI → the relevant platform skills. Message sends, number provisioning,
webhook mutation, and broadcast sends are gated, human-approved actions.
