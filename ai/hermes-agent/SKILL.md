---
name: hermes-agent
description: 'MUST USE when installing, configuring, operating, automating, integrating, or extending **Hermes Agent** — the open-source (MIT) autonomous AI agent framework by Nous Research (hermes-agent.nousresearch.com) that runs one `AIAgent` core across CLI, TUI, desktop, a 25+-platform messaging gateway, IDEs (ACP), and an OpenAI-compatible API server. Covers the script-only install contract (`curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash` / `install.ps1`; pip, uv tool, Homebrew, AUR, and macOS Intel are UNSUPPORTED), the `~/.hermes/` directory contract (secrets ONLY in `~/.hermes/.env` chmod 600, behavior ONLY in `config.yaml` via `hermes config set`, code at `~/.hermes/hermes-agent/`, binary symlink `~/.local/bin/hermes`, SQLite sessions `state.db`, `$HERMES_HOME` relocation), the CLI/TUI surface (`hermes`, `hermes --tui`, `hermes chat -q`, one-shot `hermes -z` with `--usage-file`, resume `-c`/`-r latest`, `hermes model` vs `/model`, `hermes doctor`, `hermes update`, `hermes backup`, worktree mode `hermes -w`, shell mode `!`, `/yolo`, slash commands, `hermes prompt-size`), profiles as separate Hermes homes (`hermes profile create|use|export`, `hermes -p <name>`, the "never point two agent processes at the same profile" rule) and git-distributed **profile distributions** (`distribution.yaml`, `hermes profile install github.com/you/repo --alias`, update semantics that preserve `config.yaml`/memories/`.env`), secrets sources (Bitwarden `bws`, 1Password `op://` refs with `override_existing: true` by default, command helpers, deterministic precedence), the **iron-proxy egress firewall** (`hermes egress install|setup|start|status`, TLS-terminating credential substitution, proxy tokens in sandboxes, default host allowlist + SSRF deny CIDRs incl. IMDS, Docker-backend-only in v1, AWS SigV4/GCP OAuth bypass), the tool/toolset system (~86 tools / 28+ toolsets, `--toolsets`, composite `coding`, minimal `safe`, capability gates that `all` does NOT override, kanban off even under `all`), terminal backends (`local|docker|ssh|singularity|modal|daytona|vercel_sandbox`, one persistent Docker container surviving `/new`, dangerous-command checks SKIPPED in container backends), the skills system (SKILL.md + `metadata.hermes` frontmatter, `~/.hermes/skills/`, progressive disclosure `skills_list()`→`skill_view()`, hub install `hermes skills install official/<cat>/<skill>` with security scanning + trust levels, project-local `.hermes/skills/` requiring `hermes skills trust`, 95 bundled + 127 optional skills, the curator lifecycle active→stale(30d)→archived(90d), skill bundles, `/learn`), memory (MEMORY.md 2,200-char / USER.md 1,375-char caps, no read action — injected at session start and frozen, nine external providers honcho/openviking/mem0/hindsight/holographic/retaindb/byterover/supermemory/memori via `memory.provider`), context files (only ONE loads, first match: `.hermes.md`/`HERMES.md` > `AGENTS.override.md` > `AGENTS.md` > `CLAUDE.md` > `.cursorrules`; SOUL.md loads separately from `$HERMES_HOME` as system-prompt slot #1), `@`-references (`@file`, `@folder`, `@diff`, `@staged`, `@git:N`, `@url` — CLI-only, 25%/50% soft/hard caps), automation (unified `cronjob` tool, `hermes cron create "every 2h" ...`, `jobs.json`, drift guard, `--no-agent --script` $0 polling with `{"wakeAgent": false}`, `[SILENT]` delivery suppression, delivery targets `telegram|discord|slack|github_comment|sms:+1...`, `/heartbeat every` idle-only coalescing ticks, webhooks on port 8644 with `{pull_request.number}` template vars), hooks (four systems: gateway HOOK.yaml, 26 plugin hook events via `ctx.register_hook`, shell hooks with stdin JSON + exit-code-2 block + `pre_tool_call` fail-closed, outbound webhooks), the web dashboard (port 9119, fail-closed auth on non-loopback bind, REST `/api/*`, dashboard plugins + themes) and OpenAI-compatible API server (port 8642, `API_SERVER_KEY` required, `/v1/chat/completions`, `/v1/responses`, `/v1/runs`, full toolset INCLUDING terminal), providers (30+ slugs incl. openrouter/nous/anthropic/copilot/gemini/vertex/bedrock/deepseek/xai/zai/kimi-coding/huggingface/lmstudio, env-var matrix, OAuth quirks — Anthropic OAuth needs Claude Max, Copilot needs `gho_*`/`github_pat_*`; custom `providers.<name>` blocks with `key_env`/`transport`/`key_cmd`/`extra_body`; `fallback_providers`; OpenRouter `provider_routing` sort price/throughput/latency + Pareto Code Router; the 64,000-token minimum context rule; local backends Ollama/vLLM (`--enable-auto-tool-choice --tool-call-parser hermes`)/llama.cpp (`--jinja`)/SGLang/LM Studio), **MCP integration** (`mcp_servers:` in config.yaml — stdio `command`/`args`/`env` or HTTP `url`/`headers`, `tools.include`/`exclude` where include overrides exclude, `auth: oauth` PKCE with callback ports 27890-27894, tool naming `mcp__<server>__<tool>`, `hermes mcp add|test`, `/reload-mcp`, `hermes mcp serve` to expose Hermes AS an MCP server, Hermes Cloud management via `https://portal.nousresearch.com/mcp`), the Python library (NO PyPI wheel — clone + `uv sync`, `from run_agent import AIAgent`, sync-only, one instance per thread), and the developer surface (three entry points → one `AIAgent`; 3-tier cached prompt assembly stable→context→volatile; tools self-register at import via `registry.register()` returning JSON strings with errors as `{"error": ...}` never raised; `api_mode` chat_completions|codex_responses|anthropic_messages; plugin types — general/platform/memory-provider/context-engine/secret-source/model-provider/browser-provider/terminal-environment via `register(ctx)`; subagent lifecycle API; gateway session keys `agent:main:{platform}:{chat_type}:{chat_id}` with default-deny authorization). Triggers on phrases — "hermes agent", "hermes-agent", "nous research agent", "install hermes", "hermes chat", "hermes gateway", "hermes cron", "hermes skills", "hermes profile", "hermes dashboard", "hermes mcp", "iron proxy", "hermes egress", "SOUL.md", "hermes tui", "hermes model", "hermes plugins", "hermes memory provider", "hermes api server", "delegate to hermes", "hermes python library", "hermes toolsets", "hermes distribution", "hermes worktree", "hermes hooks", "hermes webhook", "hermes heartbeat". Triggers on file patterns — `~/.hermes/config.yaml`, `~/.hermes/.env`, `SOUL.md`, `HERMES.md`, `.hermes.md`, `AGENTS.override.md`, `distribution.yaml`, `~/.hermes/skills/**/SKILL.md` with `metadata.hermes`, `mcp_servers:` blocks, `HOOK.yaml`, `plugin.yaml` with `register(ctx)`, `jobs.json` under `cron/`, `iron-proxy` / `proxy.yaml`. Authored as a working playbook — read-only inspection first; every install, config change, credential edit, gateway start, or plugin enable is a deliberate human-approved action.'
license: BSD-3-Clause
compatibility: opencode
metadata:
  domain: ai
  tool: hermes-agent
  vendor: nous-research
  category: autonomous-agent-framework
  runtime: cli + tui + gateway + acp + api-server + mcp
  config-root: ~/.hermes
  language: python-3.11
---

# Hermes Agent — Operate, Automate, Integrate, Extend

Hermes Agent (Nous Research, MIT) is an open-source autonomous agent framework: one synchronous `AIAgent` core (`run_agent.py`) reached through three entry points — the CLI/TUI (`cli.py`), the messaging **gateway** (`gateway/run.py`, 25+ platform adapters), and the **ACP** adapter for IDEs — plus an OpenAI-compatible API server and a web dashboard. Everything lives under `~/.hermes/` (relocatable via `$HERMES_HOME`), sessions persist in SQLite + FTS5 (`state.db`), and the model side speaks any OpenAI-compatible API through 30+ built-in providers. No telemetry; state stays local.

This skill is the playbook for the whole lifecycle, split into six phases with a companion subagent each:

| Phase | Owns | Companion agent |
|---|---|---|
| A — Install & operate | install contract, platform tiers, CLI/TUI, sessions, worktrees, doctor/update/backup | `hermes-installer-operator` |
| B — Config, profiles & secrets | `.env` vs `config.yaml` split, profiles, distributions, secret sources, iron-proxy egress, safety env vars | `hermes-config-secrets` |
| C — Skills, memory & context | skills system + hub + curator, MEMORY.md/USER.md + external providers, context files, SOUL.md, `@`-references | `hermes-skills-memory-engineer` |
| D — Automation & gateway | cron, heartbeat, hooks, webhooks, messaging gateway, dashboard (9119), API server (8642) | `hermes-automation-gateway-engineer` |
| E — Providers, MCP & library | provider matrix, routing/fallbacks, local LLMs, MCP client + server + Hermes Cloud, Python library | `hermes-provider-integrator` |
| F — Extending | architecture, prompt assembly, adding tools/providers/adapters, all plugin types, subagent lifecycle | `hermes-extension-developer` |

Three read-only triage scripts ship under `tools/`: `hermes-env-audit.sh`, `hermes-profile-inventory.sh`, `hermes-surface-probe.sh`.

## CORE PRINCIPLES (non-negotiable)

1. **Install only via the official script.** `curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash` (Linux/macOS/WSL2/Termux) or `iex (irm https://hermes-agent.nousresearch.com/install.ps1)` (Windows). PyPI (`pip`/`uv tool`), Homebrew, AUR, and macOS **Intel** are explicitly unsupported. The installer provisions uv, Python 3.11, Node.js v22, ripgrep, ffmpeg; Git is the only universal prerequisite. Code lands at `~/.hermes/hermes-agent/`, the binary symlink at `~/.local/bin/hermes`, data at `~/.hermes/`.
2. **The config split is a hard invariant.** Secrets and API keys go ONLY in `~/.hermes/.env` (chmod 600). Behavior goes ONLY in `~/.hermes/config.yaml`, applied via `hermes config set <key> <value>` — never hand-edit the YAML, never put a key-shaped value in it. Profile exports and distributions always strip `auth.json` and `.env`.
3. **64,000 tokens of context is the model floor.** Any model — cloud or local — needs ≥64k context. Local backends additionally need tool-calling wired: llama.cpp `--jinja -c 64000`, vLLM `--enable-auto-tool-choice --tool-call-parser hermes --max-model-len 65536`, Ollama `OLLAMA_CONTEXT_LENGTH=64000` (verify with `ollama ps`), SGLang `--tool-call-parser qwen --context-length 65536`.
4. **Never point two agent processes at the same profile.** A profile is a separate Hermes home (`~/.hermes/profiles/<name>/`) with isolated config, `.env`, SOUL.md, memories, sessions, skills, cron, and `state.db`. Two writers compound each other's memory into state nobody authored. Profiles do **not** sandbox the filesystem.
5. **The system prompt is immutable mid-conversation** (prompt caching depends on it). Customize through the sanctioned surfaces — `SOUL.md` (identity, slot #1), project context files, skills, MEMORY.md/USER.md, `HERMES_EPHEMERAL_SYSTEM_PROMPT` — never by editing `agent/prompt_builder.py`. Mid-session memory writes hit disk but only appear in the prompt next session. Switching model mid-session resets the prompt cache (the cache key includes the model).
6. **Only ONE project context file loads, first match wins:** `.hermes.md`/`HERMES.md` (walks to git root) > `AGENTS.override.md` > `AGENTS.md` > `CLAUDE.md` > `.cursorrules` (CWD). `SOUL.md` loads independently and only from `$HERMES_HOME` — personality there, project facts in `AGENTS.md`. All context files are security-scanned (prompt-injection markers, hidden HTML, invisible Unicode) and truncated.
7. **Know where the safety rails actually are.** Dangerous-command approval (`rm -rf`, `curl | sh`, …) applies to the local backend but is **skipped in container backends** (Docker/Singularity/Modal/Daytona) — the container IS the boundary there. `--yolo`/`HERMES_YOLO_MODE` bypasses approvals. `HERMES_WRITE_SAFE_ROOT` is a hard write sandbox with no approval prompt — and pointing it at a project dir also blocks Hermes's own `~/.hermes` state writes (cron `jobs.json`, skills). The API server exposes the **full toolset including terminal** — `API_SERVER_KEY` is mandatory. The dashboard fails closed on non-loopback binds without an auth provider. `TELEGRAM_WEBHOOK_SECRET` is mandatory with a webhook URL or the gateway refuses to start.
8. **Read-only first.** Inspect with `hermes status`, `hermes doctor`, `hermes config get`, `hermes prompt-size`, the `tools/` scripts, and dashboard/API GETs. Every install, upgrade, config write, credential change, gateway/cron/plugin enablement is a separate, human-approved action.

## Phase A — Install & operate

```bash
# Install (Linux / macOS Apple Silicon / WSL2 / Termux)
curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash
source ~/.bashrc            # or ~/.zshrc
hermes model                # provider/model wizard (OAuth, keys, custom endpoints)
hermes setup --portal       # quick Nous Portal OAuth (model + Tool Gateway)
hermes doctor               # diagnostics (--fix available)
```

Platform tiers: Tier 1 = macOS Apple Silicon, Windows 10/11, Linux/WSL2 (glibc + systemd), Docker (`hermes update` does NOT work in containers — new image required). Tier 2 best-effort = Android/Termux, Nix. Headless servers: `sudo npx playwright install-deps chromium`, install with `--skip-browser`, `sudo loginctl enable-linger <service-user>`.

Daily driving:

```bash
hermes                       # classic CLI chat        hermes --tui   # TUI (Node ≥20, shares state.db)
hermes chat -q "one shot with tool output in transcript"
hermes -z "pure one-shot"    # ONLY final text on stdout; --usage-file usage.json for cost/tokens
hermes -c                    # continue last session    hermes -r latest   # resume by id/title
hermes -w -z "Fix issue #123"   # disposable git worktree under .worktrees/, branch hermes/hermes-<hash>
hermes chat --toolsets "web,terminal,skills" -s github-pr-workflow
```

- **`hermes model` vs `/model`**: the CLI command is the full wizard (OAuth/keys/custom endpoints); the slash command only switches between already-configured providers (`/model custom:local:qwen-2.5` for named custom providers).
- Shell mode `!<cmd>` runs with zero model invocation; `/background <prompt>` forks an isolated background session; `/busy queue|steer|interrupt` picks what typing mid-run does.
- Worktree hygiene: `hermes worktree prune` never deletes uncommitted tracked changes or unpushed commits; untracked scratch is archived to `~/.hermes/archive/worktree-prune/`; warnings at >10 trees or 5 GB.
- Maintenance: `hermes update` (syncs bundled skills to all profiles), `hermes config check|migrate` after updates, `hermes backup` / `hermes import` for machine migration (backup includes keys; `hermes profile export` strips them). `hermes serve`/`hermes dashboard` exit code **75** = port occupied.
- Cost hygiene: `hermes prompt-size` (offline per-message fixed cost), `/usage`, `/insights`, `/compress` (keeps final 2 exchanges verbatim), trim `--toolsets`.

## Phase B — Config, profiles, secrets, egress

**Profiles** — one agent per role, isolated state:

```bash
hermes profile create research --description "arXiv scout" --clone   # config/skills/SOUL only
hermes profile use research          # sticky; `use default` reverts
hermes -p research cron list         # ad-hoc targeting; alias wrapper ~/.local/bin/research also works
hermes profile export research       # .tar.gz — ALWAYS strips auth.json + .env
```

**Profile distributions** package a whole agent as a git repo (`distribution.yaml` + `SOUL.md` + `config.yaml` + `skills/` + `cron/` + `mcp.json`):

```bash
hermes profile install github.com/you/research-bot --alias
hermes profile update research-bot        # replaces SOUL.md/skills/cron/mcp.json;
                                          # preserves config.yaml (--force-config overrides);
                                          # NEVER touches memories/sessions/.env
```

Distribution cron jobs are **not auto-scheduled** (enable via `hermes -p <name> cron list`). Reserved names: `hermes`, `test`, `tmp`, `root`, `sudo`. Distributions are unsigned — trust the git host and author like a browser extension.

**Secrets sources** (resolve provider keys at startup instead of plaintext `.env`): Bitwarden Secrets Manager (`BWS_ACCESS_TOKEN`, `secrets.bitwarden.project_id`), 1Password (`op://vault/item/field` refs, `OP_SERVICE_ACCOUNT_TOKEN`, `hermes secrets onepassword setup|set|sync --apply`, 300s cache — note it ships `override_existing: true`, the opposite of the general default), and command helpers printing `KEY=VALUE`. Precedence is deterministic: local `.env`/shell wins unless a source sets `override_existing: true`; mapped beats bulk; first source wins per category; cross-source conflicts warn at startup, never silently.

**Iron-proxy egress firewall** (sandboxes hold proxy tokens, never real keys):

```bash
hermes egress install && hermes egress setup   # pinned SHA-256-verified binary → ~/.hermes/bin/iron-proxy
hermes egress start && hermes egress status
```

HTTPS CONNECT+MITM on `proxy.tunnel_port` (default 9090, HTTP on 9091), TLS termination + credential substitution, default upstream host allowlist (openrouter.ai, api.openai.com, api.anthropic.com, …) + SSRF deny CIDRs covering loopback/link-local/**IMDS 169.254.169.254**/RFC1918/ULA/CGNAT, checked at connect time (DNS-rebinding safe). Never binds 0.0.0.0. v1 limits: **Docker backend only**; AWS SigV4 (Bedrock) and GCP OAuth (Vertex) bypass it entirely; after `--rotate-tokens` running sandboxes keep old tokens until restarted. `enforce_on_docker: true` (default) refuses sandbox creation when the proxy is enabled but down.

**Safety env vars worth memorizing:** `HERMES_MAX_ITERATIONS` (500), `DELEGATION_MAX_CONCURRENT_CHILDREN` (3), `HERMES_YOLO_MODE`, `HERMES_WRITE_SAFE_ROOT` (hard sandbox — see CORE PRINCIPLES 7), `HERMES_SAFE_MODE` / `--safe-mode` (disables ALL customizations: plugins, hooks, MCP, memory), `--ignore-user-config` + `--ignore-rules` for isolated CI runs.

## Phase C — Skills, memory, context

**Skills** live at `~/.hermes/skills/<category>/<skill>/SKILL.md` (+ `references/`, `templates/`, `scripts/`). Frontmatter uses a `metadata.hermes` namespace:

```yaml
---
name: my-skill
description: Brief description of what this skill does
version: 1.0.0
metadata:
  hermes:
    tags: [python, automation]
    category: devops
    requires_toolsets: [terminal]     # hidden unless available
    fallback_for_toolsets: [web]      # hidden when web IS available
    config:
      - key: my.setting
        description: "What this controls"
        prompt: "Prompt shown at setup"
required_environment_variables:
  - name: MY_API_KEY
    prompt: "Enter your API key"
---
```

Declared env vars are stored in `~/.hermes/.env` (never shown to the model) and auto-passed into `execute_code`/`terminal` sandboxes. Progressive disclosure: `skills_list()` (~3k tokens) → `skill_view(name)` → `skill_view(name, file_path)`. Every installed skill becomes a slash command (`/github-pr-workflow`, stack up to 5). Skills take effect in **new** sessions (`--now` invalidates the prompt cache).

- Hub: `hermes skills browse|search|install official/<category>/<skill>|audit` — installs are security-scanned; trust levels `builtin > official > trusted > community`; 95 bundled + 127 optional skills. Custom taps: `hermes skills tap add myorg/skills-repo`.
- Project-local skills (`<repo>/.hermes/skills/`, `<repo>/.agents/skills/`) require a `.git` ancestor AND explicit `hermes skills trust`.
- The **curator** maintains agent-created skills only: `active → stale (30d) → archived (90d)`, never auto-deletes; LLM consolidation is opt-in (`curator.consolidate: true`); `hermes curator adopt` brings manual skills under management.
- `/learn <source>` distills a skill from a dir/URL/PDF; `skill_manage` lets the agent create/patch skills (gate with `skills.write_approval: true`).

**Memory**: `~/.hermes/memories/MEMORY.md` (2,200-char cap) + `USER.md` (1,375-char cap). The `memory` tool has `add`/`replace`/`remove` — **no read**; content is injected at session start and frozen. Over-limit writes error rather than silently dropping. External providers via `memory.provider:` — `honcho`, `openviking`, `mem0`, `hindsight`, `holographic`, `retaindb`, `byterover`, `supermemory`, `memori` (`hermes memory setup|status|off`; only one active). Session recall is separate: `session_search` over `state.db` FTS5 returns actual messages, no summarization.

**Context**: precedence per CORE PRINCIPLES 6. `SOUL.md` = identity/tone only (slot #1); `AGENTS.md` = project architecture/conventions. `@`-references (`@file:path:10-25`, `@folder:`, `@diff`, `@staged`, `@git:5`, `@url:`) are CLI-only, appended under `--- Attached Context ---`, soft-capped at 25% and hard-refused at 50% of context; SSH keys, shell profiles, `~/.aws/`, `$HERMES_HOME/.env` are blocked paths.

## Phase D — Automation, gateway, dashboard, API server

**Cron** (isolated, fresh session per run — prompts must be self-contained):

```bash
hermes cron create "0 2 * * *" "Triage the backlog…" --name nightly-triage --deliver telegram
hermes cron create "every 5m" --no-agent --script memory-watchdog.sh --deliver telegram   # $0 polling
```

Schedules: relative `30m`, `every 2h`, `every 1d at 09:00`, 5-field cron, ISO timestamps (all UTC). Jobs in `~/.hermes/cron/jobs.json` (atomic writes, 60s tick under a cross-process file lock). Script jobs: empty stdout = silent tick; final line `{"wakeAgent": false}` skips the LLM entirely; `{"wakeAgent": true, "context": {...}}` passes context. `[SILENT]` in a response suppresses delivery. Delivery: `origin|local|telegram[:chat[:thread]]|discord[:#channel]|slack|sms:+1…|github_comment|bot-chat[:<profile>]|all`. The **model drift guard** skips runs when an unpinned model changed (disable `cron.model_drift_guard: false`). Recursion guard: cron runs cannot schedule cron jobs. Workdir jobs (`--workdir /abs/path`) load that dir's context files and run sequentially.

**Heartbeat** vs cron: `/heartbeat every 10m <prompt>` is context-aware inside a session — idle-only (never interrupts a turn), coalesces missed ticks into one, minimum 60s. Cron is isolated and self-contained.

**Webhooks** (event-driven activation, port 8644): `hermes webhook subscribe github-pr-review --events pull_request --prompt "Review PR #{pull_request.number}…" --skills github-code-review --deliver github_comment`, or YAML under `platforms.webhook.extra.routes` with template vars `{pull_request.title}`, `{repository.full_name}`, `{action}`, `{__raw__}`.

**Hooks — four systems:** (1) gateway hooks: `HOOK.yaml` + `handler.py` in `~/.hermes/hooks/`, events `gateway:startup`, `session:start/end`, `agent:start/step/end`, `command:*`; (2) plugin hooks: 26 events via `ctx.register_hook` — directive (`pre_tool_call` can return `{"action": "block"}` / `{"action": "modify", "args": {…}}`, `pre_llm_call` injects context), transform (`transform_tool_result`, …), observer (`post_tool_call`, `subagent_start/stop`, …); (3) shell hooks: `hooks:` blocks in config.yaml, stdin JSON, **exit code 2 = block**, `pre_tool_call` timeouts fail closed, consent-gated via `~/.hermes/shell-hooks-allowlist.json` (`hermes hooks list|test|doctor|revoke`); (4) outbound webhooks (`hooks.outbound`).

**Gateway** (`hermes gateway install|start|status`; WSL2 prefers `hermes gateway run` in tmux): adapters normalize to `MessageEvent`, session key `agent:main:{platform}:{chat_type}:{chat_id}`, authorization hierarchy per-platform allow-all → platform allowlist (`TELEGRAM_ALLOWED_USERS`, …) → DM pairing (`hermes pairing approve …`) → `GATEWAY_ALLOW_ALL_USERS` → **default deny**. One bot token per profile (duplicate tokens block the second gateway). Logs at `~/.hermes/logs/gateway.log`.

**Web dashboard**: `hermes dashboard` → `http://127.0.0.1:9119` (auth gate OFF on loopback, **fail-closed** on any other bind: Nous Portal OAuth, basic auth for trusted networks only, self-hosted OIDC public+PKCE, or a `DashboardAuthProvider` plugin). Pages for config/env/sessions/cron/skills/MCP/channels; REST under `/api/*`; `GET /api/status` is the public probe.

**API server** (OpenAI-compatible): set `API_SERVER_ENABLED=true` + `API_SERVER_KEY=…` in `.env`, run `hermes gateway` → `http://127.0.0.1:8642`. Endpoints `/v1/chat/completions`, `/v1/responses`, `/v1/runs` (+ events SSE, stop, approval), `/v1/models`, `/v1/health`; multi-profile at `/p/<profile>/v1/…` with that profile's key. It exposes the **full toolset including terminal** — treat the key like a shell credential; keep CORS narrow; default 10 concurrent runs.

## Phase E — Providers, MCP, Python library

**Providers**: keys in `~/.hermes/.env`, chosen via `hermes model` (wizard) / `--provider` / config. Highlights: `openrouter` (`OPENROUTER_API_KEY`, plus `provider_routing:` sort `price|throughput|latency`, `only`/`ignore`/`order`, `data_collection: deny`, Pareto Code Router `openrouter/pareto-code` + `openrouter.min_coding_score`), `nous` (Portal OAuth, `hermes setup --portal`, includes the paid Tool Gateway — per-category `web.backend: nous`, `image_gen.provider: nous`; `use_gateway:` is deprecated), `anthropic` (OAuth requires **Claude Max with purchased extra usage credits** — Claude Pro must use `ANTHROPIC_API_KEY`), `copilot` (token precedence `COPILOT_GITHUB_TOKEN` → `GH_TOKEN` → `GITHUB_TOKEN` → `gh auth token`; `gho_*`/`github_pat_*` (the providers page also lists GitHub-App `ghu_*`), classic `ghp_*` unsupported), `gemini`/`vertex` (service account / ADC), `bedrock` (AWS chain), `deepseek`, `xai`, `zai` (`GLM_API_KEY`), `kimi-coding`, `huggingface` (`HF_TOKEN`, `:fastest|:cheapest` suffixes), `lmstudio`, keyless `opencode-free`. Custom endpoints:

```yaml
providers:
  work:
    api: https://gpu-server.internal.corp/v1
    key_env: CORP_API_KEY
    transport: chat_completions        # or anthropic_messages
    models:
      qwen3.5:27b: {context_length: 64000}
fallback_providers:
  - {provider: openrouter, model: anthropic/claude-sonnet-4}
```

`key_cmd:` mints tokens from a CLI; `extra_body:` passes provider-specific fields. Local backends: see CORE PRINCIPLES 3; Mac guide recommends llama.cpp (`brew install llama.cpp`) with Qwen GGUF Q4_K_M, `-ngl 99 -c 131072 -fa on --cache-type-k q4_0 --cache-type-v q4_0`, plus `HERMES_API_TIMEOUT=1800` / `HERMES_STREAM_READ_TIMEOUT=1800` for slow local inference. Model catalog is a remote manifest cached 1h at `~/.hermes/cache/model_catalog.json`, silent fallback to the in-repo snapshot; pricing/context are fetched live, not in the manifest.

**MCP client** (`uv pip install -e ".[mcp]"` if missing):

```yaml
mcp_servers:
  github:
    command: npx
    args: ["-y", "@modelcontextprotocol/server-github"]
    env: {GITHUB_PERSONAL_ACCESS_TOKEN: "ghp_xxx"}
    tools: {include: [create_issue, "list_*"], exclude: [dangerous_tool], resources: true, prompts: false}
  internal_api:
    url: "https://mcp.internal.example.com"
    headers: {Authorization: "Bearer ***"}
  hermes-cloud:
    url: "https://portal.nousresearch.com/mcp"
    auth: oauth                       # PKCE + DCR; tokens in ~/.hermes/mcp-tokens/
    tools: {include: [agents]}        # read-only restriction
```

Tools surface as `mcp__<server>__<tool>` (non-alphanumerics → `_`); `include` overrides `exclude`; defaults `timeout: 300` / `connect_timeout: 60`; OAuth callback pinned to ports 27890–27894; `ssl_verify: false` disables cert checks entirely — don't. Manage with `hermes mcp add|test|serve`, reload with `/reload-mcp`. **Hermes as an MCP server**: `hermes mcp serve` exposes terminal/file/search/memory/skills/run_agent tools to Claude Desktop/Cursor. Hermes Cloud's `agent` tool (start/stop/create/destroy/update_env) is the mutating half — omit it for read-only.

**Python library**: no PyPI wheel. `git clone https://github.com/NousResearch/hermes-agent && cd hermes-agent && uv sync`, then:

```python
from run_agent import AIAgent
agent = AIAgent(model="anthropic/claude-sonnet-4.6", quiet_mode=True, skip_memory=True)
print(agent.chat("ping"))                       # sync; final text only
r = agent.run_conversation("first turn")        # {"final_response", "messages"}
```

Fully synchronous; one `AIAgent` per thread; `enabled_toolsets=[…]`, `ephemeral_system_prompt=…`, `max_iterations=500`, `save_trajectories=True` writes ShareGPT jsonl.

## Phase F — Extending (developer surface)

- **Architecture**: three entry points → one `AIAgent`; flow `run_conversation() → prompt_builder.build_system_prompt() → runtime_provider.resolve_runtime_provider() → API call → model_tools.handle_function_call()`. "The core is a narrow waist" — when two subsystems are involved, the narrower one owns the change; tests mirror source layout.
- **Prompt assembly**: 3 cached tiers `stable → context → volatile` (identity/SOUL.md → context files → MEMORY.md/USER.md/metadata); rebuilds only on session start, compression, or explicit invalidation; per-turn content (`ephemeral_system_prompt`, `pre_llm_call` context) goes into the **user message**, never the system prompt.
- **Adding a tool** (two files): `tools/your_tool.py` with a top-level `registry.register(name=…, toolset=…, schema=…, handler=…, check_fn=…)` (auto-discovered by AST scan at startup), plus `toolsets.py`. Contract: handlers return a JSON **string** via `json.dumps()`; errors return `{"error": "…"}`, never raise; `check_fn` returning False silently hides the tool; `schema["description"]` is what the model sees.
- **Adding a provider**: `api_mode` is the key abstraction (`chat_completions` | `codex_responses` | `anthropic_messages`; `ProviderProfile` additionally accepts `bedrock_converse`); history is stored internally in OpenAI chat-completions shape and native adapters convert FROM it. Fast path: a plugin at `plugins/model-providers/<name>/` calling `register_provider(ProviderProfile(...))` (last-writer-wins) auto-wires CLI, runtime resolution, and fallback.
- **Platform adapters**: extend `BasePlatformAdapter` (`connect/disconnect/send`), register via `ctx.register_platform(...)` with `env_enablement_fn`, `cron_deliver_env_var`, `standalone_sender_fn`, `max_message_length`, `platform_hint`.
- **Plugin types** all register via `register(ctx)` in `~/.hermes/plugins/<name>/__init__.py` + `plugin.yaml`: `ctx.register_tool/hook/command/platform/memory_provider/context_engine/secret_source/browser_provider/terminal_environment_provider`. Pip distribution via entry-point groups `hermes_agent.plugins` / `hermes_agent.memory_providers` (pip plugins need `plugins.enabled:` opt-in). Capabilities (`tools.override`, `llm.model_override`, `gateway.platform_actions`, …) are consent-gated at install — consent, **not** a sandbox: plugins are in-process Python. Install-time scan verdicts: safe / caution / dangerous (dangerous blocks even `--force`); pack refs must be exact 40-char commit SHAs.
- **Sharp plugin contracts**: memory providers — `sync_turn()` MUST be non-blocking, only one external provider active, precedence reversed (early sources win); context engines — only one registers, never auto-activated (`context.engine:` opt-in); secret sources — `fetch()` MUST NOT raise or prompt, "you fetch, the orchestrator applies"; browser providers — session dict key literally `bb_session_id` regardless of vendor, `is_available()` runs at registration time so no network; terminal environments — `create_environment(**kwargs)` must ignore unknown kwargs, reserved names can't shadow built-ins.
- **Plugin LLM access**: `ctx.llm.complete()/complete_structured()` (+ async) → results with `PluginLlmUsage` incl. `cost_usd`; provider/model/agent_id/profile overrides are **denied by default**, gated per-plugin in `plugins.entries.<id>.llm.allow_*_override`, raising `PluginLlmTrustError` otherwise.
- **Subagent lifecycle**: `service.launch(SubagentLaunchRequest(goal, context, role, correlation_id, allowed_toolsets)) → SubagentHandle`; `wait/result/status/cancel/reconnect`; states `PENDING→STARTING→RUNNING→{SUCCEEDED, FAILED, INTERRUPTED, CANCELLED}`; terminal results immutable, ≤32KB, no transcripts, retained 1h; post-restart `reconnect` returns `RECONNECT_UNAVAILABLE`.

## Read-only tools in this skill

| Script | Answers |
|---|---|
| `tools/hermes-env-audit.sh` | Is Hermes installed correctly? Binary/version, `~/.hermes` layout, `.env` permissions, config-split violations (key-shaped values inside config.yaml) |
| `tools/hermes-profile-inventory.sh` | What exists? Profiles, skills counts, cron jobs, MCP servers, plugins, memory-file sizes vs caps |
| `tools/hermes-surface-probe.sh` | What's listening? Dashboard 9119 `/api/status`, API server 8642 `/v1/health`, gateway + egress status |

All three are strictly read-only (`hermes <sub> status`-class commands, file reads, local GETs). Review before running; they never mutate state.

## Anti-patterns

| Anti-pattern | Why it's wrong | Instead |
|---|---|---|
| `pip install hermes-agent` / `brew install hermes-agent` | Unsupported install paths; PyPI/Homebrew/AUR don't exist for this | Official `install.sh` / `install.ps1` |
| API keys in `config.yaml`, or hand-editing the YAML | Breaks the config split; exports/distributions assume `.env` holds secrets | Keys → `~/.hermes/.env`; behavior → `hermes config set` |
| Local model with default 4k–8k context | Below the 64k floor — the agent loop truncates and fails | `--ctx-size 65536` / `num_ctx 64000` / `--max-model-len 65536` |
| Two processes on one profile | Both auto-write memory; state nobody authored | One process per profile; external memory provider for sharing |
| Editing `agent/prompt_builder.py` to customize behavior | Global product change, overwritten on update | SOUL.md / AGENTS.md / skills / `HERMES_EPHEMERAL_SYSTEM_PROMPT` |
| Trusting `--toolsets all` to enable everything | Capability gates still apply; kanban stays off by design | List gated toolsets explicitly; provide backends/credentials |
| Treating Docker sandbox as "approvals still on" | Dangerous-command checks are skipped in container backends | The container is the boundary — image, mounts, egress proxy |
| Exposing the API server or dashboard without auth | API server = full toolset incl. terminal; dashboard fails closed for a reason | `API_SERVER_KEY`, keep loopback, real auth provider on other binds |
| Expecting a cron prompt to see chat history | Cron runs are fresh isolated sessions | Self-contained prompts; `context_from=` for job chaining |
| `ssl_verify: false` on an MCP server | Disables certificate verification entirely | CA bundle path, or fix the cert |
| Editing memory then expecting it mid-session | Memory is injected at session start and frozen | New session; writes land next session |
| Distribution update with `--force-config` by default | Clobbers the installer's tuned model/provider | Default preserve; `--force-config` only deliberately |

## Verification checklist (before calling Hermes work done)

- [ ] `hermes doctor` clean; `hermes --version` current; `hermes config check` passes after updates.
- [ ] Secrets only in `~/.hermes/.env` (0600); nothing key-shaped in `config.yaml` (`tools/hermes-env-audit.sh`).
- [ ] Model meets the 64k context floor; local backends have tool-calling flags; `hermes chat -q "ping"` answers.
- [ ] One agent process per profile; gateway bot tokens unique per profile.
- [ ] Cron jobs listed with correct UTC schedules and pinned models where drift matters; script jobs use `wakeAgent` gating.
- [ ] Dashboard on loopback or fail-closed auth configured; `API_SERVER_KEY` set if the API server is enabled; `TELEGRAM_WEBHOOK_SECRET` set with any webhook URL.
- [ ] MCP servers `hermes mcp test <name>` green; mutating tools excluded where read-only was intended.
- [ ] Egress: `hermes egress status` healthy if enabled; sandboxes show `HERMES_EGRESS_PROXY=1` and proxy tokens, not real keys.
- [ ] New skills pass the hub security scan; project-local skill dirs explicitly trusted; skills verified in a NEW session.
- [ ] For code changes to Hermes itself: tool handlers return JSON strings with `{"error": …}` (never raise); tests mirror the source layout and pass.
