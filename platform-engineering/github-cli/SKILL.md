---
name: github-cli
description: >-
  MUST USE when authoring, reviewing, automating, or debugging anything that runs the
  **GitHub CLI (`gh`)** — covers the **command grammar** (`gh <group> <command>
  [subcommand] [--flags]`, discovery via `gh <cmd> --help` / `gh reference`, the global
  `-R/--repo` override), the **token-based authentication + precedence model**
  (`gh auth login` interactive web / device flow / `--with-token` stdin / `--hostname`
  for GitHub Enterprise Server / `--git-protocol ssh|https` / `--scopes` / `--skip-ssh-key`;
  the credential precedence **`GH_TOKEN` > `GITHUB_TOKEN` > keyring/`hosts.yml`** for
  github.com/`*.ghe.com` and **`GH_ENTERPRISE_TOKEN` > `GITHUB_ENTERPRISE_TOKEN` >
  stored** for a GHES host; `gh auth setup-git` credential-helper wiring, `gh auth
  status`/`refresh`/`switch` multi-account, keyring-vs-`hosts.yml` storage; fine-grained
  PAT > classic PAT > ephemeral `GITHUB_TOKEN`; the min PAT scopes `repo`,`read:org`,`gist`),
  the **repo-context resolution order** (`-R/--repo [HOST/]OWNER/REPO` > `GH_REPO` env >
  current git remote > `gh repo set-default` for multi-remote clones), the **machine-output
  trio** (`--json <fields>` — no-arg lists the fields — plus built-in `--jq` (no external
  `jq` binary) or `--template` Go templates with the helpers `tablerow`/`tablerender`/
  `timeago`/`timefmt`/`hyperlink`/`autocolor`/`color`/`join`/`pluck`/`truncate`), the
  **`gh api` REST + GraphQL escape hatch** (auth + base URL + version header supplied for
  you; `-f/--raw-field` = always a string vs `-F/--field` = typed `true`/`false`/`null`/int
  and `@file`/`@-` stdin; adding a field flips **GET → POST** so force `-X GET` for a
  query-string GET; `{owner}`/`{repo}`/`{branch}` placeholders; `--paginate` follows REST
  `Link` headers, GraphQL needs `$endCursor` + `pageInfo`; `--slurp`, `--input` raw body,
  `--cache`), the **config + environment surface** (`gh config get|set|list` keys
  `git_protocol`/`editor`/`prompt`/`pager`/`browser`/`http_unix_socket`/`telemetry` with
  `--host` per-host override; the `GH_*` env vars `GH_TOKEN`, `GH_HOST`, `GH_REPO`,
  `GH_ENTERPRISE_TOKEN`, `GH_EDITOR`, `GH_PAGER`, `GH_BROWSER`, `GH_CONFIG_DIR`,
  `GH_PROMPT_DISABLED`, `GH_DEBUG`/`GH_DEBUG=api`, `GH_FORCE_TTY`, `NO_COLOR`,
  `GH_NO_UPDATE_NOTIFIER`, `GH_TELEMETRY`; config in `~/.config/gh/config.yml` + `hosts.yml`),
  **aliases** (`gh alias set` with `$1`/`$2` positionals, `!`/`--shell` shell aliases via
  `sh`, `-` stdin, `--clobber`), **extensions** (`gh extension install owner/gh-x` — arbitrary
  **unverified third-party code**, `--pin` to a tag/commit, `upgrade --all`,
  `create --precompiled=go|other`, `exec` when a name shadows a core command), the **dev-workflow
  porcelain** (`gh repo` create/clone/fork/edit/sync/`set-default`; `gh pr` create
  `--fill`/`--reviewer`/`--base`/`--draft` + merge `--squash`/`--auto`/`--delete-branch`/`--admin`;
  `gh issue`; `gh release create --generate-notes --verify-tag` with `file#label` asset globs;
  `gh label`; `gh ruleset check`; `gh search repos|issues|prs|code|commits`), the **GitHub
  Actions surface** (`gh workflow run` `-f`/`-F`/`--json` stdin + `--ref` triggering a
  `workflow_dispatch`; `gh run list/view --exit-status/--log-failed`, `gh run watch
  --exit-status` (cannot use a fine-grained PAT), `rerun --failed`, `download`; `gh secret set`
  libsodium client-side encryption via stdin/`--body`/`-f` across repo/env/org/user +
  `--app actions|dependabot|codespaces`; `gh variable` the plaintext counterpart; `gh cache`),
  **supply-chain** (`gh attestation verify --owner|--repo` SLSA provenance / Sigstore,
  `--signer-workflow`, `--deny-self-hosted-runners`, `--format json`, offline `--bundle`), the
  **CI/CD posture** (`gh` preinstalled on GitHub-hosted runners; step-level
  `env: GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}` + a least-privilege `permissions:` block where
  every unlisted scope is no-access except `metadata`; a PAT / GitHub App token for cross-repo
  writes; `GH_PROMPT_DISABLED` in automation), the **exit codes** (0 success / 1 error /
  2 cancelled / 4 auth-required — there is no code 3), the **debug/proxy** surface
  (`GH_DEBUG=api`, `http_unix_socket`), the **GitHub MCP Server** (`github/github-mcp-server` —
  remote `https://api.githubcopilot.com/mcp/` + local Docker, toolsets, `--read-only`, PAT/OAuth —
  the typed read-only-guardrailed tool surface for agents, complementary to the deterministic
  `gh` CLI; both ride a GitHub token), and the **anti-patterns** that bite teams (echoing/logging
  `gh auth token` — a live credential; a classic PAT where `GITHUB_TOKEN` or a fine-grained PAT
  fits; a PAT in a repo / `.env` / tfvars; scraping the human `gh pr list` table instead of
  `--json --jq`; a CI `gh` script with no `-R`/`GH_REPO` hanging on the multi-remote prompt; an
  omitted `permissions:` block leaving `GITHUB_TOKEN` write-all; a secret value inline on the
  command line landing in shell history; an unpinned `gh extension install` of an untrusted repo;
  `gh release create` in CI without `--verify-tag`; assuming `GH_TOKEN` authenticates a GHES host).
  Triggers on phrases — "github cli", "gh cli", "`gh auth`", "`gh auth login`", "`gh pr
  create`", "`gh pr merge`", "`gh issue`", "`gh release`", "`gh api`", "`gh api graphql`",
  "`gh run`", "`gh run watch`", "`gh workflow run`", "`gh secret set`", "`gh variable`",
  "`gh cache`", "`gh attestation`", "`gh extension`", "`gh alias`", "`gh config`", "`gh
  search`", "`gh repo set-default`", "`--json` `--jq` `--template`", "`-f` vs `-F` gh api",
  "GH_TOKEN", "GITHUB_TOKEN", "GH_ENTERPRISE_TOKEN", "GH_HOST", "GH_REPO", "gh in github
  actions", "gh github enterprise server", "gh device flow", "gh with-token", "github mcp
  server". Triggers on file patterns — `**/*.sh` invoking `gh ` (trailing space),
  `**/Makefile` rules calling `gh`, `**/.github/workflows/*.{yml,yaml}` with `run: gh …` or
  `GH_TOKEN:` / `GITHUB_TOKEN:` in step env, `**/*.{yml,yaml}` defining `gh alias import`
  aliases, `**/hosts.yml` / `**/config.yml` under a `gh/` config dir. Authored from the
  perspective of a **distinguished Platform / DevEx Engineer** — emphasises **command-group
  discipline, token-precedence + least-privilege auth (ephemeral `GITHUB_TOKEN` / fine-grained
  PAT over classic PAT / long-lived secret), `--json` + `--jq`/`--template` competency over
  table-scraping, the `gh api` escape hatch, repo-context determinism (`-R`/`GH_REPO` in
  scripts), config + env-var literacy, extension supply-chain hygiene, CI hardening
  (step-level `GH_TOKEN`, minimal `permissions:`, no prompts), and the stop-sign that `gh`
  is a *thin authenticated client over the GitHub REST + GraphQL API* you can read with
  `GH_DEBUG=api` — every command is an HTTPS call to `api.github.com` (or `api.<ghes-host>`),
  not a magic control plane**. Sister skill to `aws-cli` and `azure-cli` (the analogous cloud
  CLI playbooks), and to `github-actions` (which owns *workflow YAML authoring* + supply-chain
  governance where this skill owns the *`gh` CLI mechanics*).
license: BSD-3-Clause
compatibility: opencode
metadata:
  domain: platform-engineering
  pattern: github-cli-usage-and-automation
  platform: github
  stack: gh (github-cli) + github-rest-api + github-graphql-api + jq + go-templates
  target: github.com + github-enterprise-server (via GH_HOST + GH_ENTERPRISE_TOKEN)
  discipline: cli-usage, automation, ci-cd, identity, supply-chain
  use_cases: ad-hoc-ops, ci-cd-pipelines, makefile-tasks, github-actions, pr-and-release-automation, issue-triage, gh-api-scripting, workflow-dispatch, secret-and-variable-management, attestation-verify, ghes, github-mcp-integration
  sister_skills: aws-cli, azure-cli, github-actions
  reference_docs:
    - https://cli.github.com/manual/
    - https://cli.github.com/manual/gh_auth_login
    - https://cli.github.com/manual/gh_help_environment
    - https://cli.github.com/manual/gh_help_exit-codes
    - https://cli.github.com/manual/gh_help_formatting
    - https://cli.github.com/manual/gh_api
    - https://cli.github.com/manual/gh_extension
    - https://docs.github.com/en/actions/how-tos/security-for-github-actions/security-guides/use-github_token-in-workflows
    - https://github.com/cli/cli
    - https://github.com/github/github-mcp-server
---

# GitHub CLI (`gh`) — Distinguished Platform / DevEx Engineer's Playbook

You are a **distinguished Platform / DevEx Engineer** writing or reviewing code that drives the
**GitHub CLI (`gh`)** — interactive ops, Makefile glue, GitHub Actions steps, PR and release
automation, issue triage, one-shot API calls. Your job is to ship `gh` usage that is
**reproducible, token-precedence-aware, least-privilege, `--json`-parsed (never table-scraped),
repo-context-deterministic, and CI-hardened**.

This skill encodes the **`gh` contract** (command grammar, authentication + precedence,
repo-context resolution, output/`--json`, the `gh api` escape hatch, config + env, aliases +
extensions, the dev-workflow porcelain, the Actions surface, supply-chain attestation,
CI posture, debug/exit-codes) and the **operational discipline** that turns a one-off
`gh pr list` into a production caller. `gh` is a **thin authenticated client over the GitHub
REST + GraphQL API** — every command is an HTTPS call to `api.github.com` (or `api.<ghes-host>`)
you can read with `GH_DEBUG=api` and reproduce with `gh api`.

**Non-negotiables encoded in this skill:**

1. **Command grammar is grouped.** `gh <group> <command> [<subcommand>] [--flags]`. Groups map
   to surfaces (`auth`, `repo`, `pr`, `issue`, `release`, `run`, `workflow`, `secret`, `api`,
   `config`, `extension`). Discover with `gh <cmd> --help` (works at every level) or the full
   `gh reference`. The global **`-R/--repo [HOST/]OWNER/REPO`** overrides repo auto-detection on
   almost every command. Never guess a flag — the `--help` output is the same reference the
   manual ships.

2. **Auth is token-based and precedence is load-bearing.** For github.com / `*.ghe.com` the
   effective credential is **`GH_TOKEN` > `GITHUB_TOKEN` > stored (keyring, else `hosts.yml`)**;
   for a **GitHub Enterprise Server** host it is **`GH_ENTERPRISE_TOKEN` > `GITHUB_ENTERPRISE_TOKEN`
   > stored** (plain `GH_TOKEN` does **not** apply to a GHES host). Prefer the **ephemeral
   `GITHUB_TOKEN`** (in Actions) → **fine-grained PAT** → **classic PAT** → nothing longer-lived.
   **Never echo or log `gh auth token`** — it prints a live credential. If you see a PAT in a
   repo, `.env`, tfvars, or CI secret, **flag it first** before any other comment.

3. **`--json` + `--jq`/`--template`, never scrape human output.** Read/list/view commands emit
   `--json <fields>` (run `--json` with **no argument** to list the available fields), then
   `--jq <expr>` (jq is **built in** — no external binary) or `--template <go-template>`. The
   human table/colors are for humans; scripts pin fields. `--jq`/`--template` require `--json`.

4. **`gh api` is the escape hatch.** REST is the default; `gh api graphql` for GraphQL. Auth,
   base URL, and the version/`Accept` headers are supplied for you. Know **`-f/--raw-field` =
   always a literal string** vs **`-F/--field` = typed** (`true`/`false`/`null`/int coerced,
   `@file`/`@-` reads a file/stdin). Adding **any** field flips the method **GET → POST** — force
   `-X GET` for a query-string GET. Placeholders `{owner}`/`{repo}`/`{branch}` resolve from repo
   context. `--paginate` follows REST `Link` headers; for GraphQL your query must accept
   `$endCursor` + select `pageInfo{ hasNextPage endCursor }`, and `--slurp` merges pages.

5. **Repo context is resolved, not guessed.** Precedence (highest first): explicit
   **`-R/--repo`** > **`GH_REPO`** env > the **current git remote** > **`gh repo set-default`**
   (for a clone with multiple remotes, e.g. a fork). In a script/CI, **pass `-R` (or set
   `GH_REPO`) explicitly** — otherwise a multi-remote clone prompts interactively and a
   non-interactive run hangs.

6. **CI hygiene is not optional.** `gh` is preinstalled on GitHub-hosted runners. Authenticate
   by setting **`GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}` as step-level `env`** (never baked into
   the command), grant exactly the scopes the step needs via a **least-privilege `permissions:`
   block** (every unlisted scope becomes no-access except `metadata`, always read), disable
   prompting (`GH_PROMPT_DISABLED`), and read machine output (`--json`). Use a **PAT / App token**
   only for what `GITHUB_TOKEN` can't do (cross-repo writes, triggering other workflows).

7. **GitHub Enterprise Server needs the enterprise token.** Point `gh` at the host
   (`--hostname` / `GH_HOST` / `gh auth login --hostname`) **and** provide `GH_ENTERPRISE_TOKEN`.
   Run `gh auth setup-git --hostname <host>` to wire the git credential helper.

8. **Extensions run arbitrary, unverified third-party code.** `gh extension install owner/gh-x`
   executes code with your permissions — extensions are **not** verified, signed, or endorsed by
   GitHub. Review the source, prefer trusted authors, and **`--pin`** to a tag/commit for
   supply-chain safety.

9. **Secrets are encrypted client-side — keep them off the command line and out of logs.**
   `gh secret set` encrypts the value locally (libsodium sealed box) before sending. Feed the
   value via **stdin / `--body` / `--env-file`**, never inline (shell history). Distinguish
   **repo / environment / organization / user** scope and the **`--app actions|dependabot|
   codespaces`** target. `gh variable` is the **plaintext** counterpart — never put a secret in
   a variable.

If a script, Makefile, workflow, or wrapper under review violates any of these, **flag them
first** before any other comment.

---

## WHEN TO USE THIS SKILL

| Scenario | Use this skill? |
|----------|-----------------|
| Writing a Makefile / shell script that calls `gh pr create`, `gh release create`, `gh api …` | **Yes** |
| A GitHub Actions step running `run: gh …` with `GH_TOKEN` + a `permissions:` block | **Yes** |
| Debugging "my CI `gh` step hangs" (multi-remote prompt) or "exit code 4 / auth required" | **Yes** |
| Scripting the GitHub REST/GraphQL API through `gh api` (`-f`/`-F`, `--paginate`, `--jq`) | **Yes** |
| Choosing between `GITHUB_TOKEN`, a fine-grained PAT, and a classic PAT for a caller | **Yes** |
| Targeting a **GitHub Enterprise Server** host (`GH_HOST` + `GH_ENTERPRISE_TOKEN`) | **Yes** |
| Wiring the **GitHub MCP Server** into an agent, or deciding MCP-vs-`gh` | **Yes** |
| Verifying artifact provenance with `gh attestation verify` | **Yes** |
| Authoring the **GitHub Actions workflow YAML** itself (triggers, jobs, OIDC, SHA-pinning) | → `github-actions` |
| Raw `git` operations (branch, rebase, merge conflicts) with no GitHub API call | No (git, not `gh`) |
| Writing an app against **Octokit** / the GitHub REST SDK in a language | No (SDK, not the CLI) |
| CI supply-chain *governance* (SHA-pinning actions, OIDC federation policy) | → `github-actions` |

---

## INSTALLATION & FIRST-RUN

`gh` runs on Windows, Linux, macOS, in Docker, and is **preinstalled on GitHub-hosted Actions
runners and in Codespaces**. Releases land frequently — prefer "install latest + upgrade" over
pinning, **except in CI containers**, where you pin the image tag for reproducibility.

```bash
# macOS — Homebrew
brew install gh

# Windows — WinGet
winget install --id GitHub.cli

# Linux — Debian/Ubuntu (official apt repo; see cli.github.com for the keyring steps)
sudo apt install gh          # once the GitHub apt repo is configured
# Fedora/RHEL: sudo dnf install gh   |   Arch: sudo pacman -S github-cli

# Verify
gh --version
```

First-run login (interactive):

```bash
gh auth login                    # prompts host, protocol (https/ssh), auth method (web/token)
gh auth status                   # confirm active account, host, token source, scopes
```

Config + non-secret host state live under `$GH_CONFIG_DIR` (default `~/.config/gh/`):
`config.yml` (global prefs) and `hosts.yml` (per-host active user + git_protocol; and the token
if the OS keyring is unavailable or `--insecure-storage` was used).

---

## AUTHENTICATION

### Login methods

```bash
# Interactive — browser/device OAuth flow (default); pick https or ssh git protocol
gh auth login
gh auth login --web --clipboard            # open browser, copy the one-time device code

# Non-interactive — token from stdin (CI/headless). PAT min scopes: repo, read:org, gist
gh auth login --with-token < token.txt

# GitHub Enterprise Server
gh auth login --hostname ghe.example.com

# Suppress the SSH-key generate/upload prompt; choose protocol explicitly
gh auth login --git-protocol https --skip-ssh-key
```

`gh auth login` flags: `-p/--git-protocol {ssh|https}`, `-h/--hostname`, `-s/--scopes`,
`--skip-ssh-key`, `-w/--web`, `--with-token`, `-c/--clipboard`, `--insecure-storage` (write the
token in plaintext to `hosts.yml` instead of the OS keyring).

### Token precedence — which credential wins

| Target host | Precedence (highest first) |
|-------------|----------------------------|
| github.com / `*.ghe.com` | `GH_TOKEN` → `GITHUB_TOKEN` → stored credential (keyring, else `hosts.yml`) |
| GitHub Enterprise Server host | `GH_ENTERPRISE_TOKEN` → `GITHUB_ENTERPRISE_TOKEN` → stored credential for that host |

An env token **overrides any stored credential** for the matching host. When an env token is set,
`gh auth login`/`logout`/`switch` do not change the effective credential (gh uses the env token).
Prefer, in order: **ephemeral `GITHUB_TOKEN`** (Actions) → **fine-grained PAT** (scoped to specific
repos + permissions) → **classic PAT** (broad scopes) → anything longer-lived. **Never echo or log
`gh auth token`** — it emits a live credential.

### Supporting auth commands

```bash
gh auth status                                   # active account/host, token source, scopes (redacted)
gh auth setup-git                                # configure git to use gh as HTTPS credential helper
gh auth setup-git --hostname ghe.example.com     # per-host (GHES); --force needs --hostname
gh auth refresh --scopes write:packages          # add scopes to the ACTIVE account's stored token
gh auth refresh --reset-scopes                   # back to the minimum repo,read:org,gist
gh auth switch --user monalisa                   # change the active account (multi-account)
gh auth token                                     # ⚠ prints a LIVE credential — do not log/echo
```

`gh auth setup-git` sets `credential.helper` to `gh auth git-credential` for HTTPS clone/fetch/push;
it fails if no host is authenticated (unless `--force --hostname`). `gh auth refresh` operates on the
**active** account only — `gh auth switch` first for another. `gh auth switch` with exactly two
accounts toggles; with more, pass `--user`.

| Context | Use |
|---------|-----|
| Human laptop / ad-hoc | Interactive `gh auth login` (web/device), token in the OS keyring |
| GitHub Actions | The ephemeral **`GITHUB_TOKEN`** as `GH_TOKEN` step env + least-privilege `permissions:` |
| CI outside Actions / cross-repo automation | A **fine-grained PAT** (or GitHub App token) via `GH_TOKEN`, stored in the secret manager |
| GitHub Enterprise Server | `GH_HOST` + **`GH_ENTERPRISE_TOKEN`**; `gh auth login --hostname` |

---

## REPO-CONTEXT RESOLUTION

Almost every `gh` command resolves a target repo. Precedence (highest first):

1. Explicit **`-R/--repo [HOST/]OWNER/REPO`** flag on the command.
2. **`GH_REPO`** environment variable.
3. The repo of the **current directory's git remote** (auto-detection).
4. For a clone with **multiple remotes**, the one chosen by **`gh repo set-default`** — else `gh`
   prompts interactively.

```bash
gh pr list -R cli/cli                       # explicit — deterministic, works outside a clone
GH_REPO=cli/cli gh issue list               # env — one target for a whole script
gh repo set-default cli/cli                 # pin a multi-remote clone (fork: origin + upstream)
gh repo set-default --view                  # inspect / --unset to clear
```

**In scripts and CI, always pass `-R` (or export `GH_REPO`).** A non-interactive run in a
multi-remote clone with no default set will hang on the picker.

---

## OUTPUT & SCRIPTING — `--json` / `--jq` / `--template`

```bash
gh pr list --json                            # NO argument → prints the available field names
gh pr list --json number,title,author        # selected fields as JSON (pretty on a terminal)
gh pr list --json number,author --jq '.[] | "\(.number) \(.author.login)"'   # built-in jq
gh issue list --json title,url \
  --template '{{range .}}{{hyperlink .url .title}}{{"\n"}}{{end}}'            # Go template

# tablerow/tablerender align a table; timeago/autocolor decorate it
gh pr list --json number,title,headRefName,updatedAt --template \
  '{{range .}}{{tablerow (printf "#%v" .number | autocolor "green") .title .headRefName (timeago .updatedAt)}}{{end}}{{tablerender}}'
```

- `--json <fields>` — comma-separated; **no arg lists the fields** for that command.
- `--jq <expr>` — jq is **built in** (no external `jq` binary); requires `--json`.
- `--template <go-template>` — Go `text/template`; requires `--json`. Helper functions:
  `autocolor`, `color`, `join`, `pluck`, `tablerow`, `tablerender`, `timeago`, `timefmt`,
  `truncate`, `hyperlink` (plus Sprig `contains`/`hasPrefix`/`hasSuffix`/`regexMatch` and Go
  `printf`/`range`).

Supported on `pr list|view|status|checks`, `issue list|view|status`, `release list|view`,
`label list`, `ruleset list|view`, `run list|view`, `cache list`, and **all** `search …`.
Mutating commands (`create`/`merge`/`edit`/`close`/`delete`/`upload`) do not emit `--json`.

> `gh api`'s own `--jq`/`--template` act on **raw API JSON**; the porcelain `--json <fields>`
> shapes a **curated field set** first. Both use the same built-in jq engine.

---

## `gh api` — THE REST + GraphQL ESCAPE HATCH

`gh api <endpoint>` reaches any endpoint the porcelain doesn't cover. **Auth token, base URL, and
the API-version/`Accept` headers are supplied automatically** (needs a prior `gh auth login`) —
you never set `Authorization` or the host by hand.

```bash
# REST (default). Placeholders {owner}/{repo}/{branch} resolve from repo context.
gh api repos/{owner}/{repo}/releases --jq '.[].tag_name'
gh api repos/{owner}/{repo}/issues/123/comments -f body='Hi from CLI'   # -f → POST (string body)
gh api -X GET search/issues -f q='repo:cli/cli is:open remote'          # force GET + query string
gh api repos/{owner}/{repo}/rulesets --input ruleset.json               # raw JSON body (- = stdin)
gh api --paginate --slurp 'repos/{owner}/{repo}/stargazers'             # all pages → one array

# GraphQL — query text as a -f field; variables as extra -f/-F; paginate with $endCursor
gh api graphql --paginate --slurp -F owner='{owner}' -F name='{repo}' -f query='
  query($owner: String!, $name: String!, $endCursor: String) {
    repository(owner: $owner, name: $name) {
      pullRequests(first: 100, after: $endCursor) {
        nodes { number title }
        pageInfo { hasNextPage endCursor }
      }
    }
  }'
```

**`-f` vs `-F` — the highest-value distinction:**

| Flag | Semantics |
|------|-----------|
| `-f`, `--raw-field key=value` | Value is **always a literal string** — no coercion |
| `-F`, `--field key=value` | Value is **typed**: `true`/`false`/`null` → JSON bool/null, integer-looking → number, `@file` → file **contents**, `@-` → stdin, `{owner}`/`{repo}`/`{branch}` → placeholder |

Nested/array params (both flags): `key[subkey]=v` → object; `key[]=a key[]=b` → array; `key[]` → `[]`.
Other flags: `-X/--method`, `--input <file|->`, `--paginate`, `--slurp`, `--cache 3600s`,
`-H/--header`, `--hostname` (GHES), `-i/--include`, `--verbose`, `--silent`, `-q/--jq`, `-t/--template`.

> Adding **any** field param flips the method from **GET to POST**. For a GET that needs
> parameters, use `-X GET` (they become a query string).

---

## CONFIGURATION & ENVIRONMENT VARIABLES

```bash
gh config set git_protocol ssh                   # clone/push over SSH by default
gh config set editor "code --wait"               # PR/issue body editor
gh config set prompt disabled                    # never prompt (scriptable)
gh config set pager cat                           # disable paging
gh config set git_protocol https --host ghe.example.com   # per-host override
gh config list                                    # dump effective settings
```

Config keys: `git_protocol` (`https`|`ssh`), `editor`, `prompt` (`enabled`|`disabled`),
`prefer_editor_prompt`, `pager`, `http_unix_socket`, `browser`, `color_labels`,
`accessible_colors`, `accessible_prompter`, `spinner`, `telemetry` (`enabled`|`disabled`|`log`).
`--host` scopes a key to one GitHub instance. Files: `~/.config/gh/config.yml` +
`~/.config/gh/hosts.yml` (relocate both with `GH_CONFIG_DIR`).

Environment surface (`gh help environment` is the source of truth):

| Env var | Effect |
|---------|--------|
| `GH_TOKEN` / `GITHUB_TOKEN` | Auth token for github.com / `*.ghe.com` (that precedence) |
| `GH_ENTERPRISE_TOKEN` / `GITHUB_ENTERPRISE_TOKEN` | Auth token for a **GHES** host |
| `GH_HOST` | Default GitHub host when not inferable from the git remote |
| `GH_REPO` | Target repo `[HOST/]OWNER/REPO` for commands run outside a clone |
| `GH_EDITOR` / `GIT_EDITOR` | Editor for authoring text |
| `GH_PAGER` / `PAGER` | Terminal pager |
| `GH_BROWSER` / `BROWSER` | Browser for opening links |
| `GH_CONFIG_DIR` | Relocate config + `hosts.yml` (give each concurrent script its own to avoid clashes) |
| `GH_PROMPT_DISABLED` | Any value → disable interactive prompting (set this in CI) |
| `GH_DEBUG` | Truthy → verbose stderr; `GH_DEBUG=api` → also log HTTP traffic |
| `GH_FORCE_TTY` | Force TTY-style output when redirected (numeric = column count) |
| `NO_COLOR` / `CLICOLOR` / `CLICOLOR_FORCE` | Color control |
| `GH_NO_UPDATE_NOTIFIER` | Disable the update-check notice (set in CI) |
| `GH_TELEMETRY` | `false`/`0` → disable telemetry; `log` → print instead of send (beats `DO_NOT_TRACK`) |

---

## ALIASES & EXTENSIONS

```bash
gh alias set pv 'pr view'                                     # gh pv 123 → gh pr view 123
gh alias set bugs 'issue list --label=bugs'
gh alias set epicsBy 'issue list --author="$1" --label="epic"'   # $1 positional; gh epicsBy monalisa
gh alias set --shell igrep 'gh issue list --label="$1" | grep "$2"'   # ! / --shell → runs via sh
gh alias import aliases.yml                                    # load a set from YAML
```

An alias with `$1`/`$2` inserts args positionally (otherwise extra args are appended); a
`!`-prefixed or `--shell` expansion is evaluated by `sh` (pipes/redirects allowed); pass `-` to
read the expansion from stdin; `--clobber` overwrites.

```bash
gh extension install owner/gh-poi                # install (repo name must start with gh-)
gh extension install owner/gh-poi --pin v1.2.3   # ⚠ pin to a tag/commit — supply-chain hygiene
gh extension list                                 # installed + version + pin state
gh extension upgrade --all --dry-run             # preview upgrades
gh extension exec poi …                           # run when the name shadows a core command
gh extension create --precompiled=go gh-mytool   # scaffold (script | --precompiled=go|other)
```

**Extensions are unverified third-party code that runs with your permissions** — GitHub does not
sign or endorse them. Review the source and prefer `--pin` for anything used in automation.

---

## DEV-WORKFLOW PORCELAIN — `repo` / `pr` / `issue` / `release`

```bash
# Repositories
gh repo create acme/service --private --clone --template acme/service-template
gh repo fork cli/cli --clone --remote            # sets origin + upstream
gh repo sync --source cli/cli                     # sync a fork with upstream
gh repo edit --default-branch main --delete-branch-on-merge --enable-auto-merge

# Pull requests
gh pr create --fill --base main --reviewer @me --label ready   # --fill = title+body from commits
gh pr create --draft --title "WIP: cache" --body-file .github/pr-body.md
gh pr checks --watch                               # wait on CI for the current PR
gh pr merge 123 --squash --auto --delete-branch    # queue an auto-squash-merge, prune the branch
gh pr list --state open --json number,title,reviewDecision --jq '.[] | select(.reviewDecision=="APPROVED")'

# Issues
gh issue create --title "Bug: retry" --body-file bug.md --label bug --assignee @me
gh issue list --search 'is:open label:bug sort:created-asc' --json number,title
gh issue develop 42 --checkout                     # create + check out a branch for issue #42

# Releases (CI-safe: --verify-tag; assets take file#label and globs)
gh release create v1.4.0 './dist/*.tar.gz#Binaries' \
  --generate-notes --verify-tag --target "$GITHUB_SHA"
gh release download v1.4.0 --pattern '*.tar.gz' --dir ./artifacts

# Labels / rulesets / search
gh label create hotfix --color B60205 --description "Urgent fix"
gh ruleset check --branch main                     # which rules apply to a branch (CI guard)
gh search prs --repo cli/cli --review required --json number,title
```

`gh pr merge` strategies are `--merge`/`--squash`/`--rebase` (pick one); `--admin` bypasses
required checks (use sparingly); `--match-head-commit <SHA>` aborts if the head moved.
`gh release create --verify-tag` fails rather than silently creating a git tag in CI.

---

## GITHUB ACTIONS SURFACE — `workflow` / `run` / `secret` / `variable` / `cache`

```bash
# Trigger a workflow_dispatch (the workflow must declare on: workflow_dispatch)
gh workflow run deploy.yml --ref release -f environment=staging
echo '{"environment":"prod"}' | gh workflow run deploy.yml --json    # inputs object via stdin

# Inspect runs; gate CI on an already-finished or in-flight run
gh run list --workflow deploy.yml --branch main --json databaseId,status,conclusion
gh run watch --exit-status                          # block until done, non-zero if it failed
gh run view <run-id> --log-failed                   # logs of failed steps only
gh run view <run-id> --json jobs --jq '.jobs[] | {name, databaseId}'   # get a job's databaseId
gh run rerun <run-id> --failed                      # rerun only failed jobs + deps
gh run download <run-id> --name build-artifacts --dir ./out

# Secrets — encrypted client-side (libsodium); feed via stdin/--body/--env-file, never inline
gh secret set DEPLOY_KEY < deploy_key.pem
gh secret set NPM_TOKEN --env production
gh secret set SHARED --org acme --visibility selected --repos svc-a,svc-b
gh secret set -f .env                               # bulk-load from a dotenv file
gh secret set DEP_TOKEN --app dependabot            # target Dependabot (vs actions/codespaces)

# Variables — the PLAINTEXT counterpart (never store a secret here)
gh variable set REGION --body us-east-1 --env production
gh cache list --key deps- --json id,key,sizeInBytes # inspect Actions caches
gh cache delete --all --succeed-on-no-caches        # CI-safe cache cleanup
```

`gh run watch` cannot authenticate with a fine-grained PAT (it needs `checks:read`) — use
`GITHUB_TOKEN` for it. `gh run rerun --job` wants the **databaseId**, not the number in the
browser URL.

---

## SUPPLY CHAIN — `gh attestation verify`

```bash
# Verify an artifact's build provenance (SLSA / Sigstore) against a signed attestation
gh attestation verify ./dist/app.tar.gz --repo acme/service
gh attestation verify oci://ghcr.io/acme/service:1.4.0 --owner acme --format json

# Harden the check: require a specific signer workflow, reject self-hosted runners
gh attestation verify ./app.bin --owner acme \
  --signer-workflow acme/.github/.github/workflows/release.yml \
  --deny-self-hosted-runners

# Offline / air-gapped: verify against a downloaded bundle
gh attestation download ./app.bin --owner acme --format json > bundle.jsonl
gh attestation verify ./app.bin --owner acme --bundle bundle.jsonl
```

Requires one of `--owner` / `--repo`. Backed by Sigstore (Fulcio + Rekor). Only the
`signature.certificate` and `verifiedTimestamps` are tamper-proof; a compromised workflow can
forge `statement.predicate` — prefer verifying `--signer-workflow` / trusted reusable workflows.

---

## CI/CD POSTURE — GITHUB ACTIONS REFERENCE

```yaml
name: Comment on PR
on:
  pull_request:
    types: [opened]

permissions:
  contents: read          # every UNLISTED scope becomes no-access (except metadata, always read)
  pull-requests: write    # exactly what the gh call below needs

jobs:
  comment:
    runs-on: ubuntu-latest     # gh is preinstalled on GitHub-hosted runners
    steps:
      - env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}    # step-level env, not baked into the command
          GH_PROMPT_DISABLED: "1"
        run: |
          gh pr comment "${{ github.event.pull_request.number }}" \
            --repo "${{ github.repository }}" \
            --body "Thanks for the PR — CI is running."
```

Rules in CI:

- Authenticate by setting **`GH_TOKEN`** (the ephemeral `${{ secrets.GITHUB_TOKEN }}`) as
  step-level `env`. Use a **PAT / App token** only for what `GITHUB_TOKEN` can't do (cross-repo
  writes, triggering other workflows).
- Declare a **least-privilege `permissions:` block** — once present, every unlisted scope is
  no-access. Common: `contents: read`, `issues: write`, `pull-requests: write`, `actions: read`
  (for `gh run`/`gh workflow` reads), `attestations: write` + `id-token: write` (for
  `attest-build-provenance`).
- Disable prompts (`GH_PROMPT_DISABLED`), pass `-R "${{ github.repository }}"` (or set `GH_REPO`),
  read `--json`. Pin the CLI only inside a container image, not in the workflow.

---

## DEBUG, EXIT CODES & PROXY

```bash
GH_DEBUG=api gh pr list 2>&1 | tee gh-debug.log    # log the full HTTP request/response
gh pr list --json url --jq '.[].url' || echo "exit=$?"   # inspect the exit code
```

| Exit code | Meaning |
|-----------|---------|
| `0` | Success |
| `1` | Error (any failure) |
| `2` | The command was cancelled/interrupted |
| `4` | Authentication required |

There is **no exit code 3** in the standard table; individual commands may add their own (e.g.
`gh auth status` returns 1 when a host has auth issues). For an HTTP proxy over a Unix socket set
`gh config set http_unix_socket <path>`.

---

## MCP SURFACE — THE GITHUB MCP SERVER

The **GitHub MCP Server** (`github/github-mcp-server`) exposes GitHub operations as **structured,
typed tools to AI agents** over the Model Context Protocol — so an agent reads/writes GitHub with
validated tool calls instead of brittle shell strings. It is **complementary to `gh`, not a
replacement**; both ride a GitHub token.

- **Two deployment modes:** the **remote hosted server** at `https://api.githubcopilot.com/mcp/`
  (OAuth or PAT; nothing to run locally) and a **local server** (the `github-mcp-server` binary /
  Docker image, authenticated with a PAT via `GITHUB_PERSONAL_ACCESS_TOKEN`).
- **Toolsets** scope the exposed surface (`repos`, `issues`, `pull_requests`, `actions`,
  `code_security`, …) — enable only what the agent needs. **`--read-only`** restricts to
  non-mutating tools.
- In this repo's environment it is already wired as the `github` plugin
  (`mcp__plugin_github_github__*`) — the same server, surfaced as agent tools.

```jsonc
// MCP client config — remote hosted server (OAuth / PAT)
{
  "mcpServers": {
    "github": {
      "type": "http",
      "url": "https://api.githubcopilot.com/mcp/"
    }
  }
}
```

**MCP vs `gh` — when an agent uses which:** reach for **MCP tools** when reasoning in natural
language and you want typed inputs/outputs, toolset scoping, and a read-only guardrail without
knowing exact command syntax. **Shell out to `gh`** (or `gh api`) for exact/scriptable ops,
reproducible CI, precise `--json`/`--jq` shaping, `gh api` GraphQL, and the long tail the server
doesn't cover. Both use a GitHub token, so switching needs no re-auth.

---

## READ-ONLY TRIAGE TOOLS (`tools/`)

Three review-before-running `bash` + `gh` scripts ship with this skill. Each is **read-only**
(only `gh auth status`, `gh api` GET, `gh config get/list`, `gh <x> list/view`), never mutates,
and **never prints the token**. See `tools/AGENTS.md` for the hard invariant.

| Script | Surfaces |
|--------|----------|
| `gh-auth-check.sh` | who am I — active host/account (`gh auth status`, `gh api user`), token **source** (env vs keyring); prints no token |
| `gh-config-audit.sh` | local hygiene — `gh --version`, `gh config list`, installed extensions, env smells (`GH_TOKEN`/PAT in env), prompt/pager/protocol/telemetry |
| `gh-api-inventory.sh` | read-only estate + `--json`/`--jq` demo — `gh api /rate_limit`, `gh repo list --json …`, `gh api repos/{owner}/{repo} --jq` |

---

## ANTI-PATTERNS (flag in review)

| Anti-pattern | Why it's bad | Fix |
|--------------|--------------|-----|
| Echoing/logging `gh auth token` | it's a live credential | never print it; use `gh auth status` (redacted) |
| A classic PAT where `GITHUB_TOKEN`/a fine-grained PAT fits | broad, long-lived blast radius | ephemeral `GITHUB_TOKEN` → fine-grained PAT → classic |
| A PAT in a repo, `.env`, tfvars, or CI secret in plaintext | credential leak | secret manager; short-lived tokens |
| Parsing the human `gh pr list` table in a script | layout changes, colors, truncation | `--json <fields> --jq/--template` |
| A CI `gh` script with no `-R`/`GH_REPO` | multi-remote prompt → hang | pass `-R` or export `GH_REPO` |
| Omitting the `permissions:` block in a workflow | `GITHUB_TOKEN` keeps write-all | least-privilege `permissions:` (unlisted = no access) |
| Secret value inline: `gh secret set X --body "$Y"` in history | shell-history leak | stdin (`< file`), `--env-file`, or a masked var |
| Unpinned `gh extension install` of an untrusted repo | arbitrary code, moving target | review source; `--pin` to a tag/commit |
| `gh release create` in CI without `--verify-tag` | silently creates a git tag | `--verify-tag` (fail if the tag is absent) |
| Assuming `GH_TOKEN` authenticates a GHES host | plain token is github.com-only | `GH_HOST` + `GH_ENTERPRISE_TOKEN` |
| `gh run watch` with a fine-grained PAT | FG-PAT can't grant `checks:read` | use `GITHUB_TOKEN` for `run watch` |
| `-f value=true` expecting a JSON boolean | `-f` is always a string | use `-F value=true` (typed) |

---

## VERIFICATION CHECKLIST (pre-commit, pre-merge)

- [ ] No `gh auth token` output echoed/logged; secret values fed via stdin/`--env-file`, not inline.
- [ ] Auth uses the least-privilege credential (ephemeral `GITHUB_TOKEN` / fine-grained PAT) — no classic PAT or plaintext secret introduced.
- [ ] Scripts/CI pass `-R`/`GH_REPO` explicitly; no interactive prompt can hang (`GH_PROMPT_DISABLED`).
- [ ] Machine output uses `--json <fields>` + `--jq`/`--template`; no human table scraped.
- [ ] `gh api` calls use `-F` for typed values, `-f` for strings; GET-with-params forces `-X GET`.
- [ ] Every workflow using `gh` sets step-level `GH_TOKEN` + a least-privilege `permissions:` block.
- [ ] GHES work sets `GH_HOST` + `GH_ENTERPRISE_TOKEN` (not plain `GH_TOKEN`).
- [ ] Extensions are pinned (`--pin`) and their source reviewed.
- [ ] `gh release create` in CI carries `--verify-tag`.
- [ ] Exit-code handling accounts for 0/1/2/4 (no code 3).

---

## SUBAGENT ORCHESTRATION — signal → agent

| Goal or signal | Agent |
|---|---|
| `gh auth` login methods, token precedence (GH_TOKEN/GITHUB_TOKEN/enterprise/keyring), PAT vs GITHUB_TOKEN, `setup-git`, multi-account, GHES | `github-cli-auth-identity` |
| `gh api` (REST/GraphQL, `-f`/`-F`, pagination/slurp), `--json`/`--jq`/`--template` shaping, `gh search`, repo-context resolution | `github-cli-api-scripting` |
| `gh config` + `GH_*` env surface, aliases, extensions + supply-chain, completion, install/upgrade, proxy, exit codes | `github-cli-config-extensions` |
| `gh repo`/`pr`/`issue`/`release`/`label`/`ruleset`/`gist` porcelain automation — PRs, auto-merge, release notes | `github-cli-dev-workflow` |
| `gh workflow`/`run`/`secret`/`variable`/`cache`/`attestation` + the gh-in-Actions `GH_TOKEN` + `permissions:` pattern | `github-cli-actions-ci` |
| GitHub MCP Server setup + MCP-vs-`gh` decision, `gh <cmd> --help`/`gh reference` discovery | `github-cli-mcp-discovery` |

---

## REFERENCES (treat as source of truth — the manual is the canonical per-command reference)

- Manual home — `https://cli.github.com/manual/`
- `gh auth login` — `https://cli.github.com/manual/gh_auth_login`
- Environment variables — `https://cli.github.com/manual/gh_help_environment`
- Exit codes — `https://cli.github.com/manual/gh_help_exit-codes`
- Formatting (`--json`/`--jq`/`--template`) — `https://cli.github.com/manual/gh_help_formatting`
- `gh api` — `https://cli.github.com/manual/gh_api`
- `gh extension` — `https://cli.github.com/manual/gh_extension`
- Using `gh` in workflows / `GITHUB_TOKEN` — `https://docs.github.com/en/actions/how-tos/security-for-github-actions/security-guides/use-github_token-in-workflows`
- Source repo — `https://github.com/cli/cli`
- GitHub MCP Server — `https://github.com/github/github-mcp-server`
- jq manual — `https://jqlang.github.io/jq/manual/` · Go templates — `https://pkg.go.dev/text/template`

When in doubt, run `gh <group> <command> --help` *before* asking — the per-command reference is
the same content the CLI ships with.
