<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-07-10 | Updated: 2026-07-10 -->

# github-cli

## Purpose
Skill for the **GitHub CLI (`gh`)** — the GitHub sibling of the `aws-cli` / `azure-cli`
skills, authored as a **distinguished Platform / DevEx Engineer's playbook**. Owns the `gh`
*mechanics*: command-group grammar, token-based auth + precedence
(`GH_TOKEN` > `GITHUB_TOKEN` > keyring; GHES `GH_ENTERPRISE_TOKEN`), repo-context resolution
(`-R`/`GH_REPO`/`set-default`), the `--json`/`--jq`/`--template` machine-output trio, the
`gh api` REST + GraphQL escape hatch (`-f` string vs `-F` typed, `--paginate`/`--slurp`), config
+ `GH_*` env, aliases + extensions (supply-chain), the dev-workflow porcelain (`repo`/`pr`/
`issue`/`release`/`label`/`ruleset`/`search`), the Actions surface (`workflow`/`run`/`secret`/
`variable`/`cache`/`attestation` + the gh-in-Actions `GH_TOKEN` + `permissions:` pattern), exit
codes (0/1/2/4), and the **GitHub MCP Server** (referenced, not bundled). Sits with its CLI
siblings in `platform-engineering/`: `aws-cli` + `azure-cli` (analogous cloud CLI playbooks) and
`github-actions` (which owns *workflow YAML authoring* + supply-chain governance where this skill
owns the *`gh` CLI mechanics*).

## Key Files
| File | Description |
|------|-------------|
| `SKILL.md` | The skill — `name: github-cli`, `domain: platform-engineering`, `platform: github`, `pattern: github-cli-usage-and-automation` |

## Subdirectories
| Directory | Purpose |
|-----------|---------|
| `tools/` | 3 read-only `gh` triage scripts (`gh-auth-check.sh`, `gh-config-audit.sh`, `gh-api-inventory.sh`) — identity/host/token-source + local config/env + estate inventory; read-only is a hard invariant, and no script ever prints a token (see `tools/AGENTS.md`) |

## For AI Agents

### Working In This Directory
- Edit `SKILL.md` (and the read-only `tools/` scripts). Almost every change is authoring.
- **The doctrine is the spine:** *grammar is grouped* (`gh <group> <command>`; `--help` is the
  reference) → *token precedence + least privilege* (`GH_TOKEN` > `GITHUB_TOKEN` > keyring;
  ephemeral `GITHUB_TOKEN` → fine-grained PAT → classic PAT; never echo `gh auth token`) →
  *`--json` + `--jq`/`--template`, not table-scraping* → *`gh api` is the escape hatch* (`-f`
  string vs `-F` typed; GET→POST on field add) → *repo context is resolved* (`-R`/`GH_REPO` in
  scripts) → *CI hardened* (step `GH_TOKEN`, least-privilege `permissions:`, no prompts) →
  *GHES needs the enterprise token* → *extensions are unverified code* (`--pin`) → *secrets are
  client-side encrypted* (stdin, never inline) → *the agent is read-mostly* (every login /
  create / merge / secret-set / delete is a gated, human-approved action).
- **Version discipline is load-bearing:** `gh` ships frequently and the manual moves. **State
  behavior, pin NO version in prose, and frame `gh` subcommands / flags / env-var names /
  MCP-server details as "verify against the `cli.github.com/manual` per-command pages + the
  live GitHub repos."** Pin only in CI container images. Same no-version-pin doctrine the
  `aws-cli` / `azure-cli` skills follow.
- Keep the **scope boundary** sharp:
  - **Workflow YAML authoring** (triggers, jobs, OIDC, SHA-pinning, script-injection) →
    `../github-actions/`. This skill owns the *`gh` CLI mechanics* invoked from a step
    (`run: gh …` + `GH_TOKEN` + `permissions:`); that skill owns the *workflow contract*.
  - **Raw `git`** operations with no GitHub API call are out of scope (git, not `gh`).
  - **Octokit / a language REST SDK** is out of scope → app code, not the CLI.
- Highest-value facts to keep correct: **token precedence** (`GH_TOKEN` > `GITHUB_TOKEN` >
  stored; GHES uses `GH_ENTERPRISE_TOKEN`); **`gh auth token` prints a live credential**;
  **`--json` with no arg lists the fields**, `--jq` is built in (no external binary);
  **`-f` is always a string, `-F` is typed** and adding a field flips GET→POST; **repo-context
  precedence** `-R` > `GH_REPO` > git remote > `set-default`; **exit codes are 0/1/2/4 (no 3)**;
  **`gh secret set` encrypts client-side**; the **GitHub MCP Server** is `github/github-mcp-server`
  (remote `api.githubcopilot.com/mcp/` + local Docker, toolsets, `--read-only`) and is already
  wired here as the `github` plugin.
- The `description:` uses a `>-` block scalar (colon/backtick-dense) — keep it and re-verify
  `yq '.description | type'` is `!!str` after edits.

### Testing Requirements
- **`scripts/validate-skills.sh` validates this directory** (`platform-engineering/` is in
  `DOMAIN_DIRS`): frontmatter (`name`/`description`/`license`/`compatibility`, non-empty
  `metadata` map), non-empty body, even fence count. Run it after edits.
- `tools/` is **not** validator-covered — verify by hand (`bash -n`, the mutating-`gh`-verb grep,
  the non-GET-`gh api` grep, the no-`gh auth token` grep, executable bit) per `tools/AGENTS.md`.

### Companion Subagents
- Ships a **6-agent GitHub-CLI team** in `../../.claude/agents/`:
  `github-cli-auth-identity` (auth methods / token precedence / PAT-vs-`GITHUB_TOKEN` /
  `setup-git` / multi-account / GHES — owns `tools/gh-auth-check.sh`), `github-cli-api-scripting`
  (`gh api` REST/GraphQL + `-f`/`-F` + pagination + `--json`/`--jq`/`--template` + `gh search` +
  repo-context — owns `tools/gh-api-inventory.sh`), `github-cli-config-extensions` (`gh config` +
  `GH_*` env + aliases + extensions/supply-chain + install/upgrade + exit codes — owns
  `tools/gh-config-audit.sh`), `github-cli-dev-workflow` (`repo`/`pr`/`issue`/`release`/`label`/
  `ruleset`/`gist` porcelain automation), `github-cli-actions-ci` (`workflow`/`run`/`secret`/
  `variable`/`cache`/`attestation` + the gh-in-Actions `GH_TOKEN` + `permissions:` pattern),
  `github-cli-mcp-discovery` (GitHub MCP Server + MCP-vs-`gh` decision + `gh <cmd> --help`/
  `gh reference` discovery). The SKILL's "Subagent Orchestration" table maps signal → agent;
  update both on rename.

### Common Patterns
- Intro + mental model (`gh` = authenticated client over GitHub REST+GraphQL) → When-to-use table
  → Non-negotiables → Install → Authentication (+ precedence) → Repo-context resolution → Output &
  `--json` → `gh api` escape hatch → Config & env → Aliases & extensions → Dev-workflow porcelain
  → Actions surface → Supply-chain attestation → CI posture → Debug/exit-codes → MCP surface →
  anti-patterns → checklist → subagent orchestration → references. Same authoring shape as the
  sibling `aws-cli` / `azure-cli` skills.

## Dependencies

### Internal
- `../../scripts/validate-skills.sh` — enforces the SKILL.md contract.
- `../../README.md` — references this skill in the "Platform Engineering" table; rename → README update.
- `../../.claude/agents/github-cli-*.md` — the 6 companion subagents.
- `../aws-cli/SKILL.md` + `../azure-cli/SKILL.md` (analogous cloud CLI playbooks),
  `../github-actions/SKILL.md` (workflow-YAML authoring — boundary partner) — cross-referenced to
  keep boundaries sharp.

### External
None at runtime — documentation. Describes the GitHub CLI; cites the `cli.github.com/manual`
per-command pages, the GitHub Actions `GITHUB_TOKEN` docs, and the GitHub repos (`cli/cli`,
`github/github-mcp-server`). `tools/` scripts need only `gh` (a repo-read token for the inventory
script; a valid login for the auth check; nothing for the local config audit) + POSIX tools. No
external `jq`. No version pinned.

<!-- MANUAL: -->
