<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-08-29 -->

# vercel-git-cicd

## Purpose
The `vercel-git-cicd` skill — an operator's playbook for the **Git↔Vercel
seam** documented under `vercel.com/docs/git`: connecting repositories
(GitHub / GitLab / Bitbucket / Azure DevOps), the who-may-deploy rules
(commit-author membership, fork-PR authorization, verified commits), the
push→preview→production branch flow, PR/MR feedback surfaces
(comments / commit statuses / `repository_dispatch`), build gating (Ignored
Build Step, monorepo auto-skip, deploy hooks), the `VERCEL_GIT_*` env-var
surface, and the external-CI bridges for hosts the built-in integration
cannot reach (GHES, Self-Managed GitLab, Bitbucket Data Center, Azure Repos).

It deliberately does **not** own the rest of the Vercel platform — functions,
domains, caching, tokens/REST, OIDC, observability, protection/WAF, MCP
beyond the CI loop — those hand off to the sibling `../vercel/` skill; GitHub
Actions workflow YAML beyond the Vercel steps hands off to
`../github-actions/`.

## Key Files
| File | Description |
|------|-------------|
| `SKILL.md` | The skill contract: scope boundary + version gate, CORE PRINCIPLES, capability map, Phases A–E (connect → branch flow → PR feedback → build gating → external CI), anti-patterns, checklist, REFERENCE, MCP SURFACE, subagent orchestration |
| `tools/` | Three read-only triage scripts — Git-connection audit, deployment trace by branch/SHA, local Ignored-Build-Step dry-run (see `tools/AGENTS.md`) |

## Subdirectories
| Directory | Purpose |
|-----------|---------|
| `tools/` | Read-only `curl` + `jq` scripts against `api.vercel.com`, plus one purely local git dry-run, shipped with the skill |

## For AI Agents

### Working In This Directory
- **Read `SKILL.md` first and obey its CORE PRINCIPLES.** The five that
  constrain almost every edit: every push deploys by default (the sanctioned
  off-switches are `git.deploymentEnabled` and the Ignored Build Step); the
  Ignored Build Step is **inverted** — exit 0 skips, exit 1 builds; deploy
  permission follows the **commit author**, not the pusher; a deploy-hook URL
  **is** a credential; and when the integration can't reach the Git host,
  bridge with `vercel pull → build → deploy --prebuilt` — never fake the
  integration.
- **Facts were extracted verbatim from vercel.com/docs (2026-08)** —
  `repository_dispatch` type names, `VERCEL_GIT_*` variable names, permission
  matrices, deploy-hook limits (5/10 per project, 60/hr), the `--depth=10`
  clone, the 2048-byte commit-message truncation. Do not "tidy" them from
  memory; re-fetch the doc page and quote it.
- **Keep the scope boundary with `../vercel/` sharp.** This skill owns the
  Git seam; that one owns the platform. Overlapping topics (deploy hooks,
  `ignoreCommand`, monorepo skip) are covered here in Git-pipeline depth and
  there in passing — deepen here, cross-reference there, never fork the facts.
- The five companion subagents live in **`../../.claude/agents/`**
  (repo-scoped), not here: `vercel-git-connector`,
  `vercel-branch-flow-designer`, `vercel-pr-status-engineer`,
  `vercel-build-gatekeeper`, `vercel-external-ci-operator`. Adding or
  renaming one means updating both `SKILL.md`'s orchestration table and
  `../../.claude/agents/AGENTS.md`.
- Never put a real token, deploy-hook URL, or PAT in an example — the hook
  URL is explicitly a credential.

### Testing Requirements
- Run `./scripts/validate-skills.sh` from the repo root before every push.
  `platform-engineering/` is in the validator's `DOMAIN_DIRS`, so this
  SKILL.md is CI-checked on every push and PR.
- Balanced code fences are the check that bites — count ``` markers before
  validating.
- Frontmatter must keep `name`, `description`, `license: BSD-3-Clause`,
  `compatibility: opencode`, and a non-empty `metadata` map.
- `bash -n` every script under `tools/`; keep them executable.

### Common Patterns
- `description:` opens with `MUST USE when …` and exhaustively lists
  Git-CI/CD triggers (provider names, `git.deploymentEnabled`,
  `repository_dispatch`, `vercel-deployment-task`, "commits not triggering
  deployments") that discriminate this skill from the platform-wide `vercel`
  skill.
- Body order: scope boundary + version gate → CORE PRINCIPLES → capability
  map → Phases A–E with verbatim commands/YAML → anti-patterns table →
  checklist → REFERENCE → MCP SURFACE → SUBAGENT ORCHESTRATION.
- Every phase keeps analysis read-only and gates mutations (connect,
  branch-tracking change, toggle, hook trigger, deploy) on a human.

## Dependencies

### Internal
- `../vercel/` — the platform-surface sibling this skill hands off to (and
  whose `vercel-cli-api-automator` / `vercel-mcp-ai-integrator` agents it
  reuses).
- `../github-actions/` — workflow YAML beyond the Vercel steps.
- `../github-cli/` — `gh` + GitHub MCP mechanics for the PR loop.
- `../../.claude/agents/` — the five companion subagents.

### External
- Vercel — `vercel.com/docs/git` (+ provider subpages,
  `project-configuration/git-configuration`, `git-settings`,
  `deploy-hooks`), `openapi.vercel.sh`, `api.vercel.com`.
- Azure DevOps — the Vercel Deployment Extension (Visual Studio marketplace).
- `curl`, `jq` (required by the API scripts), `git` (the local dry-run).

<!-- MANUAL: -->
