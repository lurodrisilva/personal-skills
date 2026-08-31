<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-08-31 -->

# ai/kapso-whatsapp

## Purpose
Skill for **Kapso** (kapso.ai) — "WhatsApp for developers": the hosted
platform that connects WhatsApp Business numbers and exposes them through
three APIs behind one project API key (WhatsApp Meta-mirror at
`api.kapso.ai/meta/whatsapp/v24.0`, Platform + Workflows at
`api.kapso.ai/platform/v1`), the `@kapso/whatsapp-cloud-api` TypeScript
SDK, the `@kapso/cli`, webhooks (kapso/meta kinds, HMAC verification,
buffering/ordering/retries/auto-pause), visual + local-code workflows with
Cloudflare-Worker functions, customer onboarding via setup links, and two
MCP servers (Project MCP `api.kapso.ai/mcp`, Docs MCP
`docs.kapso.ai/mcp`) plus agent runtimes (Chat SDK, OpenClaw, Hermes
Agent, n8n). Five phases (A–E in the SKILL.md) are delegated to five
companion subagents in `../../.claude/agents/` (`kapso-*`).

## Key Files
| File | Description |
|------|-------------|
| `SKILL.md` | The skill: phase↔agent table, 9 CORE PRINCIPLES (three-APIs-one-key, 24-hour window, BSUID-safe parsing, raw-body HMAC + fast ack, webhook scope/kind choice, dual rate limiters + Meta's, lock-versioned replacement-set workflow definitions, sandbox limits, agent blast-radius), Phase A–E playbooks, MCP SURFACE table, anti-patterns, verification checklist, subagent orchestration |

## Subdirectories
| Directory | Purpose |
|-----------|---------|
| `tools/` | 3 strictly read-only scripts: `kapso-api-probe.sh` (reachability/auth/numbers/customers/rate-limit headroom), `kapso-webhook-audit.sh` (webhook inventory + paused detection + recent deliveries), `kapso-workflow-inventory.sh` (workflows/executions/functions snapshot) (see `tools/AGENTS.md`) |

## For AI Agents

### Working In This Directory
- The SKILL.md `description` opens with `MUST USE when …` — keep trigger
  phrases exhaustive when editing; auto-loading matches on that string.
- Every technical claim traces to the Kapso docs
  (`https://docs.kapso.ai/llms.txt` indexes every page as fetchable
  `.md`; endpoint paths verified against the `/api/...md` OpenAPI-derived
  pages). One documented discrepancy is called out in-place: the SDK
  quickstart shows `baseUrl: 'https://app.kapso.ai/api/meta/'` while the
  send guides and Chat SDK default use
  `https://api.kapso.ai/meta/whatsapp` — verify against current docs
  before "fixing" either.
- `tools/` scripts must stay read-only: GET-only Platform API calls, key
  from `KAPSO_API_KEY` only (never an argument, never printed), graceful
  exit 0 without a key.
- Companion subagents live in `../../.claude/agents/kapso-*.md`; keep
  their frontmatter `name:` equal to the filename stem and their hand-off
  lists in sync with the SKILL.md phase table.

### Validation (this tree is NOT walked by the validator)
`../../scripts/validate-skills.sh` covers only its `DOMAIN_DIRS`
(`coding/`, `platform-engineering/`, `operations/`, `security/`,
`networking/`) — but the README badge count DOES include `ai/`. After any
edit here, manually verify:

```bash
f=ai/kapso-whatsapp/SKILL.md
fm=$(awk '/^---$/{n++} n==1 && !/^---$/{print} n==2{exit}' "$f")
echo "$fm" | yq eval '.' - >/dev/null && echo "yaml ok"
grep -cE '^\s*```' "$f"   # must be even
bash -n ai/kapso-whatsapp/tools/*.sh
```

## Dependencies

### Internal
- `../../.claude/agents/kapso-*.md` — the 5 companion subagents
  (messaging-engineer, onboarding-operator, webhook-engineer,
  workflow-automation-engineer, agent-integrator).
- `../hermes-agent/` — Hermes-side plugin mechanics for the
  `gokapso/hermes-agent-plugin` runtime hand-off.
- `../../operations/agentic-k8s-ops/` — the blast-radius doctrine cited
  by CORE PRINCIPLE 9 and the MCP SURFACE section.
- `../../README.md` — AI-domain table row + skills badge count include
  this skill.
- `../AGENTS.md` — parent domain table lists this directory.

### External
- Kapso docs: `https://docs.kapso.ai` (llms.txt index), API reference
  under `/api/...`, `github.com/gokapso/whatsapp-cloud-api-js`,
  `github.com/gokapso/chat-sdk-adapter`,
  `github.com/gokapso/agent-skills`, Project MCP
  `https://api.kapso.ai/mcp`, Docs MCP `https://docs.kapso.ai/mcp`.
