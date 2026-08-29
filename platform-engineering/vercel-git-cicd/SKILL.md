---
name: vercel-git-cicd
description: >-
  MUST USE when wiring, operating, or debugging **Git-driven CI/CD on Vercel**
  — the push→preview→production pipeline documented under vercel.com/docs/git.
  Owns the **Git provider integrations** (Vercel for GitHub / GitLab /
  Bitbucket, the Azure DevOps **Vercel Deployment Extension**, and the
  self-hosted escape hatch — GHES / Self-Managed GitLab / Bitbucket Data
  Center via pipelines), **connecting & disconnecting repositories** (provider
  permission matrices — GitHub App repo permissions, GitLab **Maintainer**
  access + API scope, Bitbucket **Admin** access; "missing Git repository" /
  "unable to find repository" triage), **who may deploy** (private-repo
  commit-author membership rules Pro vs Hobby, fork-PR deployment
  authorization + Git Fork Protection — it protects env vars and the OIDC
  token, **Require Verified Commits** — unverified commits auto-cancel),
  the **production branch resolution order** (`main` → `master` →
  [Bitbucket-only] repo production-branch setting → repo default branch;
  Branch Tracking under Environments), **preview branches & multi-phase
  previews** (staging via branch-assigned domains + branch-scoped env vars,
  custom environments with branch matching), **deploy-on-push mechanics**
  (build queueing + auto-cancellation of superseded commits,
  `github.autoJobCancelation`, deploy from a Git reference — commit SHA or
  branch — in the dashboard), **`vercel.json` / `vercel.ts` Git
  configuration** (`git.deploymentEnabled` with **minimatch** branch patterns
  and any-true-wins rule, `github.autoAlias`, deprecated `github.silent` and
  `github.enabled`), **PR/MR feedback surfaces** (Vercel bot comments +
  dashboard silencing, commit statuses + **consolidated commit status** with
  soft-fail projects for monorepos, GitHub Deployments API/checks,
  `deployment_status` webhook noise vs **`repository_dispatch`** events —
  `vercel.deployment.ready|success|error|canceled|ignored|skipped|pending|
  failed|promoted` with `client_payload.url` — and the run-e2e-after-preview
  pattern), **the Ignored Build Step** (`ignoreCommand`, **exit 0 = SKIP /
  exit 1 = BUILD**, `VERCEL_GIT_PREVIOUS_SHA`, `npx turbo-ignore`, the
  `--depth=10` shallow-clone limit, monorepo "skip unaffected projects"),
  **Git LFS**, **deploy hooks** (GET/POST, URL-is-the-credential, 5/project
  Hobby+Pro / 10 Enterprise, 60 triggers/hr, `?buildCache=false`, ignored
  when `github.enabled=false`), the **`VERCEL_GIT_*` env-var surface**
  (`VERCEL_GIT_PROVIDER`, `VERCEL_GIT_REPO_SLUG|OWNER|ID`,
  `VERCEL_GIT_COMMIT_REF|SHA|MESSAGE|AUTHOR_LOGIN|AUTHOR_NAME`,
  `VERCEL_GIT_PULL_REQUEST_ID`, `VERCEL_GIT_PREVIOUS_SHA`), the **external-CI
  bridge** (`vercel pull --environment=… → vercel build → vercel deploy
  --prebuilt` in GitHub Actions / GitLab Pipelines / Bitbucket Pipelines;
  Azure `vercel-deployment-task@3` + `vercel-azdo-pr-comment-task@3` with a
  Pull Request Threads Read&Write PAT and a required build-validation
  policy), and the **MCP wiring for the CI loop** (Vercel MCP +
  GitHub MCP, read-mostly, gated writes). Use for — "connect repo to
  vercel", "vercel git integration", "commits not triggering deployments",
  "fork PR not deploying", "vercel bot comment", "silence vercel comments",
  "consolidated commit status", "repository_dispatch vercel.deployment",
  "production branch", "staging branch on vercel", "git.deploymentEnabled",
  "ignored build step", "turbo-ignore", "VERCEL_GIT_PREVIOUS_SHA", "deploy
  hook", "verified commits", "git lfs on vercel", "GHES vercel", "gitlab
  pipelines vercel", "bitbucket pipelines vercel", "azure devops vercel",
  "vercel-deployment-task". For the rest of the platform (functions, domains,
  caching, WAF, tokens, AI Gateway) hand off to the sibling `vercel` skill.
license: BSD-3-Clause
compatibility: opencode
metadata:
  platform: vercel
  domain: ci-cd
  pattern: git-driven-delivery
  providers: github-gitlab-bitbucket-azure-devops
---

# Vercel Git CI/CD — push → preview → production

Operator's playbook for the **Git-driven delivery pipeline on Vercel**: how a
commit becomes a preview, how a merge becomes production, which knobs govern
that flow, and what to do when the built-in integration cannot reach your Git
host. Grounded in `vercel.com/docs/git` and its provider/configuration
subpages (extracted 2026-08).

## Scope boundary & version gate

- This skill owns the **Git↔Vercel seam**: provider integrations, deploy
  triggers, branch semantics, PR feedback, build skipping, deploy hooks, and
  external-CI bridges.
- It does **not** own the rest of the platform. Hand off to the sibling
  `platform-engineering/vercel/` skill for: functions/Fluid, domains/DNS,
  caching/ISR, env-var mechanics beyond Git metadata, tokens/REST/SDK, OIDC
  federation, observability, Deployment Protection/WAF, MCP beyond the CI
  loop, AI Gateway. Workflow YAML beyond the Vercel steps belongs to
  `github-actions`.
- **Version gate**: Vercel ships weekly. Endpoint versions, limits, and
  dashboard paths move. Before asserting a number or path not in this file,
  verify against `vercel.com/docs` / `openapi.vercel.sh`.

## CORE PRINCIPLES

1. **Every push deploys by default.** All four built-in integrations deploy
   each push to every branch. The sanctioned off-switches are
   `git.deploymentEnabled` (per-branch, minimatch) and the Ignored Build Step
   — not deleting the webhook, not disconnecting the repo.
2. **The Ignored Build Step is inverted**: `ignoreCommand` **exit 0 = skip
   the build, exit 1 = build**. Confusing this ships nothing (or everything).
3. **Deploy permission follows the commit author, not the pusher.** On
   private org/group/workspace repos the commit author must be a member of
   the Vercel team (Pro) or the Hobby-team owner. Fork PRs require explicit
   authorization unless the author is already a team member — this protects
   env vars and the `VERCEL_OIDC_TOKEN`.
4. **Production branch is resolved, not assumed**: `main` → `master` →
   [Bitbucket only] the repo's production-branch setting → the repo default
   branch. Change it under **Project Settings → Environments → Production →
   Branch Tracking**, never by renaming branches and hoping.
5. **Feedback surfaces are independent**: bot comment, commit status,
   `deployment_status` webhook, `repository_dispatch` event. Silence comments
   in the **dashboard Git settings** (`github.silent` is deprecated); trigger
   CI from **`repository_dispatch`**, not `deployment_status`.
6. **A deploy-hook URL is a credential.** No auth header is required — anyone
   holding the URL can deploy your project. Store it like a token; revoke on
   suspicion.
7. **Reads are free, mutations are gated.** Connecting/disconnecting a repo,
   changing branch tracking, toggling comments/statuses, creating or firing a
   deploy hook, and every deployment are human-approved actions.
8. **When the integration can't reach your host, bridge — don't fake.** GHES,
   Self-Managed GitLab, Bitbucket Data Center, and Azure Repos use the CLI
   sequence (`vercel pull → vercel build → vercel deploy --prebuilt`) or the
   Azure extension, from a project with **no** Git integration attached.

## Capability map

| Phase | Question it answers | Owner agent |
|---|---|---|
| A — Connect | Which provider, which permissions, who may deploy? | `vercel-git-connector` |
| B — Branch flow | What does a push to branch X produce, and where? | `vercel-branch-flow-designer` |
| C — PR feedback | What lands on the PR/commit, and what triggers CI? | `vercel-pr-status-engineer` |
| D — Build gating | Which pushes build, which skip, which get hooked? | `vercel-build-gatekeeper` |
| E — External CI | How do we ship when the integration can't? | `vercel-external-ci-operator` |

## Phase A — Connect the repository

**Supported for the built-in integration**: GitHub Free/Team/Enterprise
Cloud; GitLab Free/Premium/Ultimate/Enterprise (gitlab.com); Bitbucket
Free/Standard/Premium; Azure DevOps via the marketplace extension.
**Self-hosted** (GHES, Self-Managed GitLab, Bitbucket Data Center) → Phase E.
GitHub Enterprise Cloud with **Data Residency** (unique subdomain) also needs
the Phase E GitHub Actions path.

Connecting = dashboard **New Project** → pick repo → configure name /
framework preset / root directory / build settings / env vars → Deploy. To
change or disconnect: **Project Settings → Git → Connected Git Repository**.

**Permission matrix — "missing Git repository" triage**:

| Provider | Requirement to import/connect |
|---|---|
| GitHub personal repo | You are the repository **Owner** (a Collaborator cannot) |
| GitHub org repo | Org **Owner**, or org **Member with a repository access role** (an Outside Collaborator cannot) |
| GitLab | **Maintainer** access to the repository — and to the group, if group-owned |
| Bitbucket | **Admin** access to the repository |

The GitHub App's repository permissions (read+write unless noted):
Administration, Checks, Contents, Deployments, Pull Requests, Issues,
Metadata (read), Web Hooks, Commit Statuses; org Members (read); user Email
addresses (read). GitLab asks for full **API** scope. Bitbucket asks for Web
Hooks (read), Issues, Pull requests (read+write), Team + Account (read).

**Who may deploy**:
- Private repos, **Pro team**: commit author must resolve (via Login
  Connections) to a member of the team; non-members may be auto-added or
  require approval per collaboration settings.
- Private repos, **Hobby**: only the Hobby-team owner's own commits; org- or
  group-owned private repos cannot deploy to Hobby at all.
- **Fork PRs** on public repos: deployment waits for authorization from a
  team member (link posted as a PR comment); skipped if the author is already
  a member. Toggle: Project Settings → Security → **Git Fork Protection**.
- **Require Verified Commits** (GitHub only, Project Settings → Git):
  unverified commits get their deployments auto-canceled.

**Git LFS**: enable in project settings; redeploy afterward for LFS objects
to be pulled.

## Phase B — Branch flow: what a push produces

- Push to the **production branch** → production deployment; custom domains
  re-point on success; reverting a commit re-points to the previous
  production deployment instantly (rollback is routing, not rebuild).
- Push to **any other branch** → preview deployment on a generated URL
  (`<project>-git-<branch>-<team>.vercel.app`); every PR/MR gets the latest
  push's URL in a comment.
- **Queueing**: while a commit is building, newer pushes on the same branch
  queue; when the build finishes, the newest queued commit builds and the
  rest are canceled. Disable per project with
  `{"github": {"autoJobCancelation": false}}` to build strictly in sequence.
- **Deploy from a Git reference** (dashboard → Deployments → Create
  Deployment): give a commit SHA (targeted) or a full branch name
  (branch-based). If the SHA exists on several branches, Vercel asks which
  branch's configuration (env vars!) to apply.

**Selective deploys — `vercel.json` / `vercel.ts`**:

```json
{
  "$schema": "https://openapi.vercel.sh/vercel.json",
  "git": {
    "deploymentEnabled": {
      "internal-*": false,
      "*-dev": true
    }
  }
}
```

Minimatch patterns; unspecified branches default to `true`; if a branch
matches multiple rules, **any `true` wins** — in the example above,
`internal-my-branch-dev` matches both rules and still deploys because
`"*-dev": true` wins.
`"deploymentEnabled": false` turns off all automatic deployments — the
CLI-only posture of Phase E. Legacy: `github.enabled` (deprecated → use
`git.deploymentEnabled`), `github.autoAlias: false` (previews on merge —
prefer the staged-production promote flow instead), `github.silent`
(deprecated → dashboard toggles).

**Multi-phase previews (staging)**: create a long-lived `staging` branch,
assign a domain (`staging.example.com`) to that branch, scope env vars to it,
push to update; keep the branch after merging. Pro+ teams should prefer
**custom environments** with branch matching and an attached domain.

## Phase C — PR feedback: comments, statuses, events

Four independent surfaces per commit/PR:

1. **Bot comment** — preview URL on every PR/MR (all providers). Silence per
   project: Settings → Git → Connected Git Repository toggles. Cannot be
   silenced per branch. `github.silent` in `vercel.json` is deprecated;
   existing values are migrated to the dashboard setting.
2. **Commit status** — one per project deployed by the commit
   (success/failure/skipped). Monorepos: enable **consolidated commit
   status** to collapse per-project noise; projects inside it can be marked
   **soft failures** so a temporarily broken project doesn't block merges.
3. **GitHub Deployments API / checks** — deployments page in GitHub, the
   deployment URL handed to checks (e.g. an e2e suite), Slack GitHub app
   surfacing. `deployment_status` webhook events can be disabled per project
   (Settings → Git → `deployment_status` Events toggle) — but only after
   migrating workflows off them.
4. **`repository_dispatch`** (GitHub, the preferred CI trigger) — Vercel
   dispatches on deployment state changes:

```yaml
on:
  repository_dispatch:
    types:
      - 'vercel.deployment.success'   # also: ready, error, canceled,
                                      # ignored (ignored build step),
                                      # skipped (monorepo auto-skip),
                                      # pending, failed, promoted
jobs:
  run-e2es:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
      - run: npm ci && npx playwright install --with-deps
      - run: npx playwright test
        env:
          BASE_URL: ${{ github.event.client_payload.url }}
```

The payload carries deployment `url` and `environment` in
`client_payload` (schema: `vercel/repository-dispatch`). Caveat: the
workflow file must exist on the **default branch** to be triggered; add
`workflow_dispatch` while iterating.

## Phase D — Build gating: skip, queue, hook

**Ignored Build Step** (Project Settings → Git, or `ignoreCommand` in
`vercel.json`): runs before the build with the new code checked out.
**Exit 0 = skip (canceled as `vercel.deployment.ignored`), exit 1 = build.**
`VERCEL_GIT_PREVIOUS_SHA` (SHA of the last successful deployment for the
branch) is exposed **only** when an Ignored Build Step is configured.
Canonical commands:

```bash
git diff HEAD^ HEAD --quiet -- ./apps/web    # skip when nothing changed here
npx turbo-ignore                             # Turborepo-aware, uses the graph
```

Caveat: Vercel clones with `git clone --depth=10` — history-walking
heuristics beyond ten commits will lie.

**Monorepo auto-skip**: "Skip deployment" switch under Root Directory skips
projects unaffected by a commit (surfaces as `vercel.deployment.skipped`).
GitHub-only, workspace-aware.

**Deploy hooks** (Settings → Git → Deploy Hooks; project must be
Git-connected): a per-project, per-branch URL under
`https://api.vercel.com/v1/integrations/deploy/<project>/<id>` that accepts
GET or POST, no auth, no payload — returns `{"job": {"id", "state":
"PENDING", "createdAt"}}`. Uses the branch's latest commit and the build
cache (`?buildCache=false` opts out). Duplicate triggers for the same
version cancel earlier builds. Limits: **5 hooks/project (Hobby+Pro), 10
(Enterprise); 60 triggers/hr/project across all hooks**. Not triggered while
`github.enabled = false`. Use one hook per branch; typical drivers are
headless-CMS publish webhooks and third-party cron redeploys.

**`VERCEL_GIT_*` surface** (build+runtime unless noted): `VERCEL_GIT_PROVIDER`,
`VERCEL_GIT_REPO_SLUG`, `VERCEL_GIT_REPO_OWNER`, `VERCEL_GIT_REPO_ID`,
`VERCEL_GIT_COMMIT_REF`, `VERCEL_GIT_COMMIT_SHA`, `VERCEL_GIT_COMMIT_MESSAGE`
(truncated at 2048 bytes), `VERCEL_GIT_COMMIT_AUTHOR_LOGIN`,
`VERCEL_GIT_COMMIT_AUTHOR_NAME`, `VERCEL_GIT_PULL_REQUEST_ID` (empty before a
PR exists), `VERCEL_GIT_PREVIOUS_SHA` (build-time, ignored-build-step only).
Plus `CI=1` at build time and `VERCEL_ENV` / `VERCEL_TARGET_ENV` to branch
behavior per environment.

## Phase E — External CI: when the integration can't reach your host

Applies to GitHub Enterprise Server, GitHub Enterprise Cloud with Data
Residency, Self-Managed GitLab, Bitbucket Data Center — and to anyone who
wants build isolation (source never uploaded to Vercel).

**The bridge sequence** (any CI): project has **no Git integration** (or
`git.deploymentEnabled: false`), CI holds `VERCEL_TOKEN` +
`VERCEL_ORG_ID` + `VERCEL_PROJECT_ID`:

```bash
# preview (non-production branches / PRs)
vercel pull --yes --environment=preview --token=$VERCEL_TOKEN
vercel build
vercel deploy --prebuilt --token=$VERCEL_TOKEN

# production (pushes to the production branch)
vercel pull --yes --environment=production --token=$VERCEL_TOKEN
vercel build --prod
vercel deploy --prebuilt --prod --token=$VERCEL_TOKEN
```

Two workflows/pipelines: preview on non-main pushes, production on main.
GitLab-specific trap: merge pipelines can fail while branch pipelines pass
(GitLab issue) — deploy via the CLI path to avoid merging on red.

**Azure DevOps** — the Vercel Deployment Extension (Visual Studio
marketplace) against a Vercel project **with no Git integration**
(`vercel project add <name>` or disconnect after dashboard creation):

```yaml
trigger: [main]
pool: { vmImage: ubuntu-latest }
variables:
  isMain: $[eq(variables['Build.SourceBranch'], 'refs/heads/main')]
  isPR: $[eq(variables['Build.Reason'], 'PullRequest')]
steps:
  - task: vercel-deployment-task@3
    name: 'Deploy'
    condition: or(eq(variables.isMain, true), eq(variables.isPR, true))
    inputs:
      vercelProjectId: 'prj_…'
      vercelTeamId: 'team_…'
      vercelToken: $(VERCEL_TOKEN)      # secret variable
      production: $(isMain)
  - task: vercel-azdo-pr-comment-task@3
    condition: eq(variables.isPR, true)
    inputs:
      azureToken: $(AZURE_TOKEN)        # PAT: Pull Request Threads Read & Write
                                        # (task reference calls it PullRequestContribute)
      deploymentTaskMessage: $(Deploy.deploymentTaskMessage)
```

`vercel-deployment-task@3` inputs also include `target` (custom
environments), `archive` (`--archive=tgz`), `env`/`buildEnv`, `debug`,
`logs`, `vercelCWD`; outputs `deploymentTaskMessage`, `deploymentURL`,
`originalDeploymentURL`. PR previews additionally require a **build
validation policy** (Required) on the target branch so PRs trigger the
pipeline and direct pushes to `main` are prevented.

## Anti-patterns

| Anti-pattern | Why it bites | Instead |
|---|---|---|
| `ignoreCommand` exits 1 to "ignore" | Exit 1 means **build** — semantics are inverted | Exit 0 to skip, 1 to build |
| Triggering CI from `deployment_status` | Noisy, costs extra runs, payload lacks context | `repository_dispatch` `vercel.deployment.*` + `client_payload.url` |
| `github.silent: true` in new configs | Deprecated; dashboard toggles are the control | Project Settings → Git toggles |
| Renaming `master`→`main` to move production | Production branch is a project setting, not a convention | Environments → Production → Branch Tracking |
| Deploy-hook URL in a repo/CI log | URL **is** the credential — anyone can deploy | Secret store; revoke + recreate on leak |
| Git integration **and** CLI deploys on the same branch | Double deployments, racing statuses | `git.deploymentEnabled: false` (or no Git connection) for CLI-driven projects |
| Diffing >10 commits back in `ignoreCommand` | Shallow clone (`--depth=10`) — ancestors missing | `VERCEL_GIT_PREVIOUS_SHA` / `turbo-ignore` |
| Debugging "commits don't deploy" at the webhook | Usual cause is commit-author membership, fork protection, verified-commits, or `deploymentEnabled` | Walk the Phase A "who may deploy" rules first |
| Hobby team + private org repo | Unsupported combination — deploys are blocked | Make repo public or move to Pro |
| Expecting rollback/revert to rebuild | Domain re-points to the prior deployment instantly | Treat prod recovery as re-pointing, then fix forward |

## Pre-done checklist

- [ ] Production branch confirmed in Branch Tracking (not assumed from repo default)
- [ ] `git.deploymentEnabled` reviewed — no branch silently excluded, no double CLI+integration path
- [ ] Ignored Build Step verified on a throwaway commit: skip exits 0, build exits 1
- [ ] Fork protection + verified-commits posture decided and recorded
- [ ] PR feedback tuned: comments toggle, consolidated status (+ soft-fails) for monorepos
- [ ] CI triggers use `repository_dispatch`, workflow file present on the default branch
- [ ] Deploy-hook URLs stored as secrets; count within 5 (10 Enterprise), usage under 60/hr
- [ ] External-CI projects have **no** Git integration attached (no double deploys)
- [ ] Secrets (`VERCEL_TOKEN`, `AZURE_TOKEN`) held as CI secret variables, never in YAML
- [ ] The skill's read-only `tools/` scripts run clean against the project

## REFERENCE — fact sheet

- Production branch order: `main` → `master` → [Bitbucket] repo setting → default branch.
- `repository_dispatch` types: `vercel.deployment.ready`, `.success`, `.error`, `.canceled`, `.ignored`, `.skipped`, `.pending`, `.failed`, `.promoted`.
- Deploy hooks: GET/POST, `{"job":{"id","state":"PENDING","createdAt"}}`, `?buildCache=false`, 5/10 per project, 60/hr, pre-2021-05-11 hooks default to no cache.
- Clone: `git clone --depth=10` (ten commits of history at build time).
- `VERCEL_GIT_COMMIT_MESSAGE` truncated at 2048 bytes; `VERCEL_GIT_PULL_REQUEST_ID` empty pre-PR.
- GitLab: Maintainer on repo (and group); full API scope. Bitbucket: Admin on repo. GitHub personal: Owner only.
- Consolidated commit status + soft failures: GitHub, monorepo-oriented, Settings → Git.
- Verified commits: GitHub only; unverified ⇒ deployment auto-canceled.
- Azure tasks: `vercel-deployment-task@3` (outputs `deploymentTaskMessage`, `deploymentURL`, `originalDeploymentURL`), `vercel-azdo-pr-comment-task@3` (needs PAT with Pull Request Threads Read & Write).

## MCP SURFACE — driving this loop from an agent

- **Vercel MCP** (`https://mcp.vercel.com`, OAuth): read the loop with
  `list_deployments` / `get_deployment` / `get_deployment_build_logs` /
  `get_runtime_logs`; `deploy_to_vercel` is a **mutating, human-gated** tool.
  Deep wiring (clients, budgets, `buy_*` quote gates) → the `vercel` skill's
  `vercel-mcp-ai-integrator` agent.
- **GitHub MCP** (`github/github-mcp-server`): scope toolsets to
  `pull_requests`, `actions`, `repos`; prefer `--read-only` for triage of PR
  comments/statuses/dispatch runs. Mechanics → `github-cli` skill
  (`github-cli-mcp-discovery`).
- Blast-radius doctrine: read-mostly toolsets, least-privilege tokens, every
  deploy/hook trigger through a human gate (see
  `operations/agentic-k8s-ops` for the pattern).

## Tools (read-only, in `tools/`)

| Script | What it answers |
|---|---|
| `vercel-git-connection-audit.sh` | Which repo/provider/production branch is this project wired to, and are auto-deploys on? |
| `vercel-git-deployment-trace.sh` | Which deployment did branch/SHA X produce, in which state and target? |
| `vercel-ignore-step-doctor.sh` | Would the Ignored Build Step skip or build this commit? (local git only) |

All three are GET-only (or purely local); tokens come from `VERCEL_TOKEN` in
the environment and are never printed.

## SUBAGENT ORCHESTRATION

| Agent | Phase | Hand it |
|---|---|---|
| `vercel-git-connector` | A | Provider choice, permissions, missing-repo triage, who-may-deploy rules, fork protection, verified commits, LFS |
| `vercel-branch-flow-designer` | B | Production-branch tracking, preview/staging phases, custom environments, `git.deploymentEnabled`, deploy-from-ref |
| `vercel-pr-status-engineer` | C | Comments/silencing, commit statuses (consolidated + soft-fail), `deployment_status` vs `repository_dispatch`, e2e-after-preview |
| `vercel-build-gatekeeper` | D | Ignored Build Step, `turbo-ignore`, monorepo auto-skip, queue/cancel, deploy hooks, `VERCEL_GIT_*` |
| `vercel-external-ci-operator` | E | GHES / Self-Managed GitLab / Bitbucket DC pipelines, Azure DevOps extension, CLI-only posture |

Cross-skill handoffs: platform surface → `vercel` team (six agents);
workflow YAML → `github-actions`; `gh` mechanics → `github-cli` team.
