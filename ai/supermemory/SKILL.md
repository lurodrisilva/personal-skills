---
name: supermemory
description: >-
  MUST USE when adding persistent memory to AI applications or agentic
  workflows with Supermemory (supermemory.ai) — the memory/context API. Trigger
  phrases and patterns: "supermemory", "memory API", "agent memory",
  "long-term memory for my agent/LLM", "containerTag", "add memory", "search
  memories", "user profile static/dynamic", "@supermemory/tools",
  "withSupermemory", "supermemoryTools", "supermemory MCP" /
  "mcp.supermemory.ai", "supermemory local" / self-hosted memory on
  localhost:6767, "SuperRAG", "dreaming instant/dynamic", "forget-matching",
  "scoped API key sm_", "connectors sync (Google Drive/Notion/Gmail/OneDrive/
  GitHub)", migrating from Mem0 or Zep, Claude Code plugin
  claude-supermemory, or files containing `supermemory` in package.json /
  requirements.txt / pyproject.toml / .mcp.json / ~/.cursor/mcp.json, env vars
  SUPERMEMORY_API_KEY / SUPERMEMORY_BASE_URL / SUPERMEMORY_CC_API_KEY. Covers
  the v3/v4 REST API (documents, conversations, search, memories, profiles,
  container-tags, connections, settings), TS + Python SDKs, framework
  integrations (Vercel AI SDK, OpenAI, Mastra, Claude memory tool, LangChain/
  LangGraph/CrewAI/Agno/OpenAI Agents, Microsoft Agent Framework), MCP
  servers, and the self-hosted single binary.
license: BSD-3-Clause
compatibility: opencode
metadata:
  domain: ai
  tool: supermemory
  vendor: supermemory
  category: memory-api
  runtime: cloud-api + self-hosted-binary + mcp
  api-versions: v3 + v4
  languages: typescript + python
---

# Supermemory — memory and context engine for agentic workflows

Supermemory is "context infrastructure for AI agents": a hosted Memory API
(`https://api.supermemory.ai`, console at `console.supermemory.ai`) and an
API-compatible self-hosted single binary (`npx supermemory local`, serving
`http://localhost:6767`). Each ingested document produces **three artifacts**
per container: raw **document chunks** (RAG grounding), extracted **memories**
(atomic facts in a temporal graph with Updates/Extends/Derives relationships,
automatic contradiction resolution and forgetting), and a per-container
**profile** (static + dynamic summary). This skill is organized as phases,
each owned by a companion agent:

| Phase | Owns | Agent |
|-------|------|-------|
| A — Ingestion & data model | documents/conversations/batch ingest, customId + diff billing, dreaming, taskType, containerTag + container-tags API, metadata rules, connectors + org settings | `supermemory-ingestion-engineer` |
| B — Retrieval & memory lifecycle | /v4/search + /v3/search, filters, profiles + buckets, /v4/memories CRUD, versioning, forgetting | `supermemory-retrieval-engineer` |
| C — SDKs & framework integrations | `supermemory` TS/Python SDKs, `@supermemory/tools` v2 (ai-sdk/openai/mastra/claude-memory), Python framework patterns, MS Agent Framework | `supermemory-sdk-integrator` |
| D — Platform: MCP, self-hosting, keys, billing | Memory MCP + Docs MCP, Claude Code plugin, `supermemory local`, scoped API keys, pricing meters | `supermemory-platform-operator` |
| E — Agentic-workflow design | memory architecture for agents: automatic vs tool-based, tag schemes, write→search timing, latency budgets, migration from Mem0/Zep | `supermemory-agentic-architect` |

## CORE PRINCIPLES (non-negotiable)

1. **Scoping is load-bearing.** Every write AND every search includes a
   `containerTag` — in the JSON body, never a header. One tag per
   user/project/agent/org, derived deterministically from IDs you already have
   (`user_{userId}`, `org:{orgId}:user:{userId}`; pattern `^[a-zA-Z0-9_:-]+$`,
   ≤100 chars, colons express hierarchy). `containerTag` is the HARD isolation
   boundary between tenants; `metadata` + `filters` is soft filtering WITHIN a
   container. The plural `containerTags` array is legacy — v4 endpoints take
   the singular. Containers auto-create on first write.

2. **Know which of the three artifacts you are querying.** `searchMode:
   "memories"` (default) returns extracted facts from the graph;
   `"documents"` returns raw chunks (RAG); `"hybrid"` returns both.
   `POST /v3/search` is the document/SuperRAG endpoint — never use it for
   memory recall. Profiles (`client.profile()`) are the third read path:
   stable facts without a search round-trip (docs cite 50–100ms vs 200–500ms).

3. **`customId` is the dedupe, update, AND billing key.** Re-ingesting under
   the same `customId` updates the existing document and bills only the
   net-new token delta (diff billing). Conversations go through
   `POST /v4/conversations` keyed by `conversationId`. Ingesting without
   stable IDs duplicates data and pays full price every time.

4. **Writes are eventually searchable — never assume read-after-write.**
   Default `dreaming: "dynamic"` batches related documents; if an agent must
   search what it just wrote in the same session, use `dreaming: "instant"`
   (costs +1 operation per document) or poll the document status to `done`
   (`unknown → queued → extracting → chunking → embedding → indexing → done`).

5. **Deletion is soft and updates are versioned.** `PATCH /v4/memories` with
   `newContent` creates a new version (old kept, `isLatest: false`);
   `DELETE /v4/memories` marks `isForgotten: true` (409 if already
   forgotten); `forgetAfter` schedules expiry; bulk semantic forgetting goes
   through `POST /v4/memories/forget-matching` — ALWAYS with `dryRun: true`
   first (`maxForget` 1–500). The only hard-destructive surfaces are document
   deletes, `DELETE /v3/container-tags/{tag}`, and `POST /v3/settings/reset`
   (requires a confirmation string) — all human-gated.

6. **Keys are least-privilege.** Org keys (`sm_...`) live server-side only.
   Anything client-distributable gets a **scoped key**: restricted to given
   containerTag(s) and to `/v3/documents`, `/v3/memories`, `/v4/memories`,
   `/v3|v4/search`, `/v4/profile`; `expiresInDays` 1–365; per-key rate limit (default 500
   req/60s). Never hardcode `sm_` keys — use `SUPERMEMORY_API_KEY`.

7. **One API, two deployments.** Cloud and self-hosted (`supermemory local`,
   port 6767, data in `./.supermemory`, local `Xenova/bge-base-en-v1.5`
   embeddings, BYO LLM incl. Ollama — fully offline capable) differ only by
   `baseURL`. Managed connectors, the hosted MCP, and proprietary extraction
   models are **cloud-only**; the self-hosted free tier caps at ~10k
   documents.

8. **Automatic vs tool-based memory is an architecture decision, not a
   default.** Automatic = `withSupermemory` wrappers (mode `profile` |
   `query` | `full`, `addMemory: "always"` since v2) — zero agent effort,
   memory on every turn. Tool-based = `supermemoryTools` /
   `getToolDefinitions` — the model decides when to search/add. Since
   `@supermemory/tools` v2.0.0 both require `containerTag` AND `customId`
   (construction throws otherwise).

## Phase A — Ingestion & data model (`supermemory-ingestion-engineer`)

Auth for every call: `Authorization: Bearer $SUPERMEMORY_API_KEY`.

```bash
curl -s https://api.supermemory.ai/v3/documents \
  -H "Authorization: Bearer $SUPERMEMORY_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "content": "Acme prefers weekly invoicing, net-30.",
    "containerTag": "org:acme:user:jane",
    "customId": "crm-note-8841",
    "metadata": {"source": "crm", "priority": "high"},
    "dreaming": "instant"
  }'
```

- **Endpoints**: `POST /v3/documents` (text/URL/JSON/YouTube), `POST
  /v3/documents/file` (multipart, 50MB max — PDF/DOC/DOCX/TXT/MD, images,
  CSV, MP4), `POST /v3/documents/batch` (1–600 docs with batch-level
  defaults), `POST /v4/conversations` (`conversationId` + role-tagged
  `messages[]`), `PATCH /v3/documents/{id}` (full reprocess), `DELETE
  /v3/documents/{id}` (by id or customId), `DELETE /v3/documents/bulk`
  (`ids[]` 1–100 or `filepath` prefix). Reads: `GET /v3/documents/{id}`,
  `POST /v3/documents/list` (paginated), `GET /v3/documents/processing`,
  `GET /v3/documents/{id}/chunks`, `GET /v3/documents/{id}/file-url`
  (24h presigned URL).
- **Steering extraction**: `entityContext` (≤1500 chars) per document or per
  container (`PATCH /v3/container-tags/{tag}`); org-wide `workspacePrompt`
  via `PATCH /v3/settings`. `taskType: "superrag"` skips memory extraction
  (RAG-only, ~5x cheaper meters); default `"memory"` does both.
- **Metadata rules**: flat object; values string/number/boolean/array-of-
  strings; keys ≤64 chars from `a-zA-Z0-9_-.`, case-sensitive.
- **Container-tags API**: list/get/patch/delete plus async merge —
  `POST /v3/container-tags/merge` (exactly 2 sources → target, returns 202 +
  `mergeId`; poll `GET /v3/container-tags/merge/{mergeId}` through
  `queued|copying_vectors|db_committing|…|completed`). Tag delete removes
  documents and marks memories forgotten — gated.
- **Connectors** (cloud-only): Google Drive, Gmail, Notion, OneDrive, GitHub,
  Granola, Web Crawler. `POST /v3/connections/{provider}` (accepts
  `containerTag`, `documentLimit` default 5000, `redirectUrl`) → returns
  OAuth URL → callback activates → webhook sync (subscriptions renew; 7d
  Gmail/Drive, 30d OneDrive) + 4h scheduled sync. Bring-your-own OAuth app
  via provider clientId/secret + `<provider>CustomKeyEnabled` in settings;
  callback URL `https://api.supermemory.ai/v3/connections/auth/callback/{provider}`.

## Phase B — Retrieval & memory lifecycle (`supermemory-retrieval-engineer`)

```bash
curl -s https://api.supermemory.ai/v4/search \
  -H "Authorization: Bearer $SUPERMEMORY_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "q": "how does this customer want to be invoiced?",
    "containerTag": "org:acme:user:jane",
    "searchMode": "hybrid",
    "limit": 5,
    "filters": {"AND": [{"key": "source", "value": "crm"}]}
  }'
```

- **`POST /v4/search`** knobs: `threshold` 0–1 (default 0.6 per API
  reference; one concepts page says 0.5 — verify against the live OpenAPI),
  `rerank` (+~100ms), `rewriteQuery` (+~400ms), `aggregate` (synthesized
  answers, flagged `isAggregated`), `include`
  `{documents, summaries, relatedMemories, forgottenMemories}`. Results carry
  `similarity`, `version`, `rootMemoryId`, and graph `context`
  (parents/children/related).
- **`POST /v3/search`** (documents/RAG): `chunkThreshold`,
  `onlyMatchingChunks` (default true; false adds surrounding chunks),
  `docId` to search within one document, `includeFullDocs`/`includeSummary`.
- **Filters** (both): root `{"AND":[...]}` or `{"OR":[...]}`; conditions
  with `filterType` `metadata` (default) | `numeric` | `array_contains` |
  `string_contains`, plus `negate`, `ignoreCase`, `numericOperator`.
- **Profiles**: `client.profile({containerTag})` → `profile.static`,
  `profile.dynamic`, `profile.buckets`. Buckets are the topic axis (default
  `preferences`); configure org-wide in settings or per container (add-only);
  `POST /v3/settings/suggest-buckets` AI-drafts them; bucket descriptions
  steer the classifier.
- **Direct memories (`/v4/memories`)** — create (1–100 per call, `content`
  1–10k chars, `isStatic` for permanent identity traits, `forgetAfter` TTL,
  `temporalContext`), PATCH (versioning), DELETE (soft forget),
  `forget-matching` (semantic bulk-forget, `dryRun` first). The docs state
  **no SDK support yet — use fetch/cURL** for these.
- Audit inferred facts via the memory-review surface (`/docs/recall/
  memory-review`) and `include.forgottenMemories` when debugging recall.

## Phase C — SDKs & framework integrations (`supermemory-sdk-integrator`)

- **TS** (`npm install supermemory`, Node 20+): `new Supermemory({apiKey})`
  (defaults to `SUPERMEMORY_API_KEY`; self-hosted via
  `baseURL: "http://localhost:6767"`); `client.add(...)`,
  `client.search({q, searchMode, ...})` (unified; `search.memories()` /
  `search.documents()` deprecated), `client.profile(...)`,
  `client.documents.*`. **Python** (`pip install supermemory`, 3.9+):
  snake_case mirror; `client.search.memories(...)` is still the current
  Python call.
- **`@supermemory/tools` v2.0.0** — subpaths `/ai-sdk`, `/openai`,
  `/mastra`, `/claude-memory`. v2 breaking changes: config-object signature
  `withSupermemory(model, {containerTag, customId, ...})`;
  `conversationId`/`threadId` → **required `customId`**; `addMemory` default
  flipped to `"always"`; conversation persistence now goes through
  `/v4/conversations`.

```typescript
import { withSupermemory, supermemoryTools } from "@supermemory/tools/ai-sdk"

const model = withSupermemory(openai("gpt-5"), {
  containerTag: "user_123",
  customId: "chat_456",       // required in v2
  mode: "full",               // "profile" (default) | "query" | "full"
  skipMemoryOnError: true,
})
// or agentic: tools: { ...supermemoryTools(process.env.SUPERMEMORY_API_KEY!) }
```

- **OpenAI**: TS `@supermemory/tools/openai` (`withSupermemory` or
  `getToolDefinitions` + `createToolCallExecutor`); Python
  `pip install supermemory-openai-sdk` (`SupermemoryTools`,
  `execute_memory_tool_calls`; search tool takes `informationToGet`).
- **Mastra**: `withSupermemory`, `createSupermemoryProcessors()` (input =
  injection, output = save); per-request thread via `MASTRA_THREAD_ID_KEY`.
- **Claude native memory tool**: `createClaudeMemoryTool(apiKey, {...})`
  from `/claude-memory` backs Anthropic's `memory_20250818` (beta
  `context-management-2025-06-27`); paths must start with `/memories/`.
- **Python agent frameworks** (LangChain, LangGraph, CrewAI, Agno, OpenAI
  Agents SDK): no dedicated package — the documented pattern is plain SDK:
  `profile()` → system prompt, `search.memories()` → recall,
  `add()` → persist outcomes. **Microsoft Agent Framework** has its own
  prerelease package `supermemory-agent-framework`
  (`SupermemoryContextProvider`, `SupermemoryTools`, chat middleware).
- The **Memory Router proxy** (base-URL `api.supermemory.ai/v3/<provider-url>`
  + `x-supermemory-api-key`/`x-sm-user-id` headers) is gone from the current
  docs nav — treat it as legacy; the supported paths are the
  `withSupermemory` wrappers and `/v4/conversations`.

## Phase D — Platform: MCP, self-hosting, keys, billing (`supermemory-platform-operator`)

- **Memory MCP** (hosted, cloud-only): remote HTTP server at
  `https://mcp.supermemory.ai/mcp`, **OAuth — no API key**. Client config:

```json
{ "mcpServers": { "supermemory": { "url": "https://mcp.supermemory.ai/mcp" } } }
```

  Exposes 7 tools: `search_memory`, `add_memory`, `listDocuments`,
  `getDocument`, `listMemories`, `listSpaces`, `whoAmI`. Source lives at
  `apps/mcp` in the monorepo.
- **Docs MCP** (for coding agents): `https://supermemory.ai/docs/mcp` — lets
  an agent search Supermemory's own docs; add to Claude Code
  (project `.mcp.json`), Cursor (`~/.cursor/mcp.json`), VS Code, Codex,
  OpenCode. Recommended coding-agent stack: skill + Docs MCP +
  `npx supermemory setup --json` (machine-readable), plus the
  `supermemoryai/skills` repo.
- **Claude Code plugin**: `/plugin marketplace add
  supermemoryai/claude-supermemory` → `/plugin install supermemory`; env
  `SUPERMEMORY_CC_API_KEY`; commands `/supermemory:index|project-config|
  session|status`; config `~/.supermemory-claude/settings.json` +
  project `.claude/.supermemory-claude/config.json` (supports `baseUrl` for
  self-hosted).
- **Self-hosting**: `curl -fsSL https://supermemory.ai/install | bash` or
  `npx supermemory local` → `http://localhost:6767`, auto-generated API key,
  data in `./.supermemory`, local embeddings, BYO LLM (OpenAI/Anthropic/
  Gemini/Groq or any OpenAI-compatible local endpoint), offline-capable,
  `doctor` diagnostics; "self-hosted lite" ~10k-document cap. Cloud-only:
  managed connectors, hosted MCP, proprietary extractors.
- **Keys & billing**: scoped keys per CORE PRINCIPLE 6. Tiers Free ($5
  credits) / Pro $19 / Scale $399 / Enterprise; six USD meters (memory
  tokens text/rich, SuperRAG tokens text/rich, search queries, operations);
  out-of-credit returns **402**; diff billing via `customId`; error shape
  `{error, details}`.

## Phase E — Agentic-workflow design (`supermemory-agentic-architect`)

The decision framework when wiring memory into an agent:

1. **Tag scheme first**: enumerate tenants and pick deterministic
   containerTags before any code. Per-user, per-project, per-agent, or
   hierarchical (`org:x:user:y`). If two agents must share memory, they share
   a tag; if they must not, they never do.
2. **Injection strategy**: `profile` mode for cheap stable personalization on
   every turn; `query` mode when per-message semantic recall matters; `full`
   for both; tool-based when the agent should *reason* about remembering.
   `skipMemoryOnError: true` keeps the LLM call alive when memory fails.
3. **Write policy**: automatic capture (`addMemory: "always"`) vs explicit
   `addMemory` tool calls vs end-of-run `client.add()` summaries. Use
   `POST /v4/memories` with `isStatic: true` for durable identity facts and
   `forgetAfter` for anything with a natural TTL.
4. **Read-your-writes timing**: same-session recall needs
   `dreaming: "instant"` or a status poll; cross-session recall can rely on
   the default dynamic dreaming.
5. **Latency budget**: profile ≈50–100ms, search ≈200–500ms, `rerank` +100ms,
   `rewriteQuery` +400ms. Put profile in the hot path, rerank only where
   precision pays for itself.
6. **Hygiene**: schedule `forget-matching` reviews (dryRun first), audit
   Derived memories via memory review, merge containers when tenants
   consolidate, and keep `metadata` rich enough that filters can partition
   within a container.
7. **Migrations**: dedicated guides exist for Mem0 and Zep
   (`/docs/migration/from-mem0`, `/docs/migration/from-zep`).

## Read-only tools (`tools/`)

| Script | What it answers | Owner agent |
|--------|-----------------|-------------|
| `supermemory-api-probe.sh` | Is the API reachable/authorized; org settings, container tags, in-flight documents | `supermemory-platform-operator` |
| `supermemory-search-probe.sh` | Does retrieval work end-to-end for one query/tag; timing + similarity readout | `supermemory-retrieval-engineer` |
| `supermemory-config-audit.sh` | How is this project wired: SDK deps, env vars, hardcoded keys, MCP entries, local server state | `supermemory-sdk-integrator` |

All three are strictly read-only (GETs and read-semantics list/search POSTs
only), degrade gracefully without credentials, and never create, modify, or
delete anything.

## Anti-patterns

| Anti-pattern | Why it's wrong | Instead |
|---|---|---|
| Writes/searches without `containerTag` | Data lands unscoped; cross-tenant leakage risk | Deterministic tag on every call (body, not header) |
| Plural `containerTags` on v4 calls | Legacy shape; v4 takes singular | `containerTag: "user_123"` |
| Re-ingesting content without `customId` | Duplicates documents AND pays full tokens each time | Stable `customId` → update + diff billing |
| Search immediately after write, default dreaming | Extraction is async; recall misses | `dreaming: "instant"` or poll status → `done` |
| Expecting DELETE /v4/memories to hard-delete | It sets `isForgotten` (soft); 409 on repeat | Treat as forget; hard deletes are document/tag level |
| `forget-matching` without `dryRun` | LLM-matched bulk forgetting is irreversible in effect | `dryRun: true`, review, then execute with `maxForget` |
| Org `sm_` key in client/browser/mobile code | Full org access leaked | Scoped key (tag-restricted, expiring, rate-limited) |
| Hardcoded `sm_` keys in source | Credential leak | `SUPERMEMORY_API_KEY` env var |
| `rerank` + `rewriteQuery` on every call | +100ms/+400ms latency for marginal gain | Enable per call-site where precision matters |
| `/v3/search` for memory recall | It searches document chunks, not the fact graph | `/v4/search` (searchMode memories/hybrid) |
| Profile ignored, search on every turn | 200–500ms + query cost for facts the profile already holds | `profile()` for stable facts (50–100ms) |
| v1 `@supermemory/tools` positional args / `conversationId` | v2.0.0 breaking changes; construction throws | Config object with required `customId` |
| Building on the Memory Router proxy | Removed from current docs — legacy | `withSupermemory` wrappers + `/v4/conversations` |
| Assuming connectors/hosted MCP work self-hosted | Cloud-only features | Self-host = core API only; ingest via API |
| `POST /v3/settings/reset` casually | Deletes docs/memories/spaces/connections org-wide | Human-gated, understand the confirmation contract |

## Verification checklist (before declaring memory integration done)

- [ ] Every write and search call carries a deterministic `containerTag`.
- [ ] Ingestion uses `customId` (or `/v4/conversations` with
      `conversationId`) so updates dedupe and diff-bill.
- [ ] Same-session read-your-writes handled (`dreaming: "instant"` or status
      poll to `done`) wherever an agent searches what it just wrote.
- [ ] `searchMode` chosen deliberately per call-site (memories / documents /
      hybrid), and profiles used for stable facts instead of repeated search.
- [ ] Client-side surfaces use scoped keys; no `sm_` key committed to source
      (`supermemory-config-audit.sh` clean).
- [ ] `@supermemory/tools` pinned `^2.0.0` with config-object signature and
      explicit `customId`; no legacy Memory Router wiring.
- [ ] Latency-adding options (`rerank`, `rewriteQuery`, `aggregate`)
      enabled only where justified.
- [ ] Forgetting policy defined (TTL via `forgetAfter`, periodic
      `forget-matching` with `dryRun`), and destructive surfaces
      (tag delete, settings reset) gated behind human approval.
- [ ] Self-hosted vs cloud decided; `baseURL`/`base_url` wired everywhere
      the SDK/plugin is constructed if self-hosted.
- [ ] `supermemory-api-probe.sh` and `supermemory-search-probe.sh` pass
      against the target deployment.
