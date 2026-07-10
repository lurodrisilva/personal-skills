<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-07-10 | Updated: 2026-07-10 -->

# azure-cli

## Purpose
Skill for the **Azure CLI (`az`)** — the Azure mirror of the `aws-cli` skill, authored as a
**distinguished Azure Platform Engineer's playbook**. Owns the `az` *mechanics*: command-group
grammar, identity-first authentication (managed identity / OIDC over long-lived secrets),
accounts/subscriptions/tenants + sovereign clouds, output formats + client-side JMESPath
`--query`, the two-tier config + `AZURE_*` env surface, extensions, pagination/waiters/`--ids`,
install/versioning, the debug/proxy surface, CI posture, the `az rest` escape hatch, and the
**Azure MCP Server** (referenced, not bundled). Sits with its CLI/cost siblings in
`platform-engineering/`: `aws-cli` (analogous AWS playbook), `azure-finops` (which *uses*
read-only `az costmanagement`/`az graph`), `azure-retail-prices` + `kusto-kql-api` (analogous
Azure public-API / query discipline).

## Key Files
| File | Description |
|------|-------------|
| `SKILL.md` | The skill — `name: azure-cli`, `domain: platform-engineering`, `platform: azure`, `pattern: azure-cli-usage-and-automation` |

## Subdirectories
| Directory | Purpose |
|-----------|---------|
| `tools/` | 3 read-only `az` triage scripts (`az-identity-check.sh`, `az-config-audit.sh`, `az-resource-inventory.sh`) — identity/subscription/cloud + local config/env + estate inventory; read-only is a hard invariant (see `tools/AGENTS.md`) |

## For AI Agents

### Working In This Directory
- Edit `SKILL.md` (and the read-only `tools/` scripts). Almost every change is authoring.
- **The doctrine is the spine:** *identity-first* (managed identity → OIDC → certificate SP →
  scoped secret SP → interactive; ROPC is dead under mandatory MFA) → *secrets never hit logs*
  (`--output none`; `az account get-access-token` output is a live Bearer credential) → *scope
  every `create-for-rbac`* (`--role` + `--scopes`) → *JMESPath not table-scraping* (`-o json`
  for machines, `-o tsv` for capture, `-o table` humans-only) → *waiters not `sleep`* → *CI
  hardened* (`--only-show-errors`, telemetry off, OIDC, pinned image) → *the agent is
  read-mostly* (every credential/role/resource change is a gated, human-approved action).
- **Version discipline is load-bearing:** `az` ships **monthly** and the docs move fast.
  **State behavior, pin NO version in prose, and frame `az` subcommands / extension names /
  output-format lists / MCP-server details as "verify against Microsoft Learn + the live
  GitHub repos."** Pin only in CI (Docker `mcr.microsoft.com/azure-cli:<ver>-azurelinux3.0`).
  Same no-version-pin doctrine the `aws-cli` / `azure-finops` / `azure-sre-agent` skills follow.
- Keep the **scope boundary** sharp:
  - **FinOps cost triage** (`az costmanagement` / `az graph`) → `../azure-finops/`. This skill
    owns the CLI *mechanics*; that skill owns the cost *doctrine*.
  - **Public Retail Prices REST reads** → `../azure-retail-prices/`; **Kusto/KQL engine
    mechanics** → `../kusto-kql-api/`.
  - **Bicep/ARM template authoring**, **Terraform `azurerm`**, **PowerShell `Az`**, and
    language SDKs are out of scope → sibling/other skills. `az deployment` *plumbing* is in
    scope; template *authoring* is not.
  - **CI workflow governance** (SHA-pinning actions, OIDC federation policy) → `../github-actions/`.
- Highest-value facts to keep correct: **`--query` is client-side JMESPath**, case-sensitive,
  single-quote/backtick strings (double quotes in a predicate → empty output); **`-o table`
  drops nested objects + `id`/`type`/`etag`**; **`tsv` has no key-order guarantee** (pin with
  a multiselect list); **managed identity / OIDC beat long-lived secrets**; **sovereign clouds
  need `az cloud set` before `az login`**; **Azure MCP Server reuses the `az login` session**
  and lives in `microsoft/mcp` (the `Azure/azure-mcp` repo is archived).
- The `description:` uses a `>-` block scalar (colon/backtick-dense) — keep it and re-verify
  `yq '.description | type'` is `!!str` after edits.

### Testing Requirements
- **`scripts/validate-skills.sh` validates this directory** (`platform-engineering/` is in
  `DOMAIN_DIRS`): frontmatter (`name`/`description`/`license`/`compatibility`, non-empty
  `metadata` map), non-empty body, even fence count. Run it after edits.
- `tools/` is **not** validator-covered — verify by hand (`bash -n`, the mutating-`az`-verb
  grep, executable bit) per `tools/AGENTS.md`.

### Companion Subagents
- Ships a **5-agent Azure-CLI team** in `../../.claude/agents/`:
  `azure-cli-auth-identity` (login methods / `create-for-rbac` scoping / accounts-subs-tenants
  / sovereign clouds — owns `tools/az-identity-check.sh`), `azure-cli-query-output` (`--query`
  JMESPath + `-o` formats — owns `tools/az-resource-inventory.sh`), `azure-cli-config-extensions`
  (`az config` + `AZURE_*` env + extensions + install/upgrade + proxy/telemetry — owns
  `tools/az-config-audit.sh`), `azure-cli-ci-automation` (`azure/login@v2` OIDC + hardening +
  waiters + `--ids` + exit codes), `azure-cli-mcp-and-discovery` (Azure MCP Server + `az find`/
  `interactive`/`next` + `az rest`). The SKILL's "Subagent Orchestration" table maps signal →
  agent; update both on rename.

### Common Patterns
- Intro + mental model (`az` = MSAL client over ARM REST) → When-to-use table → Non-negotiables
  → Install → Authentication → Accounts/Clouds → Output & `--query` → Config & env → Extensions
  → Pagination/async/`--ids` → Discovery + `az rest` → CI posture → Debug/proxy/exit-codes → MCP
  surface → anti-patterns → checklist → references → subagent orchestration. Same authoring
  shape as the sibling `aws-cli` skill.

## Dependencies

### Internal
- `../../scripts/validate-skills.sh` — enforces the SKILL.md contract.
- `../../README.md` — references this skill in the "Platform Engineering" table; rename → README update.
- `../../.claude/agents/azure-cli-*.md` — the 5 companion subagents.
- `../aws-cli/SKILL.md` (analogous playbook), `../azure-finops/SKILL.md` (cost triage that uses
  `az`), `../azure-retail-prices/SKILL.md`, `../kusto-kql-api/SKILL.md`, `../github-actions/SKILL.md`
  — cross-referenced to keep boundaries sharp.

### External
None at runtime — documentation. Describes the Azure CLI; cites Microsoft Learn
(`learn.microsoft.com/cli/azure`, `learn.microsoft.com/azure/developer/azure-mcp-server`) and the
GitHub repos (`Azure/azure-cli`, `Azure/azure-cli-extensions`, `Azure/login`, `microsoft/mcp`).
`tools/` scripts need only `az` (Reader RBAC for the inventory script; a valid `az login` for the
identity check; nothing for the local config audit) + POSIX tools. No `jq`. No version pinned.

<!-- MANUAL: -->
