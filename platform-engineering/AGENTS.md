<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-04-25 | Updated: 2026-05-02 | DEEPINIT: 2026-05-02 -->

# platform-engineering

## Purpose
Infrastructure / DevOps / CI-CD / supply-chain / observability skills — Claude Code / opencode auto-loads them when a project matches their description. Each subdirectory contains a `SKILL.md` (some also ship a companion expertise note alongside). **Important:** `scripts/validate-skills.sh` does *not* currently walk this directory, so frontmatter and fenced-block correctness here are enforced manually until the validator is extended (tracked follow-up in `CLAUDE.md`).

## Key Files
None at this level — all content lives in subdirectories.

## Subdirectories
| Directory | Purpose |
|-----------|---------|
| `addons-and-building-blocks/` | Helm library charts + ArgoCD App-of-Apps + Crossplane / CNPG building blocks on AKS (see `addons-and-building-blocks/AGENTS.md`) |
| `azure-pg-flex/` | Azure Postgres Flexible Server observability playbook — metrics two-layer model, headroom-vs-raw diagnostic doctrine, REST API surface, two log surfaces (Server Logs + Diagnostic Settings categories) (see `azure-pg-flex/AGENTS.md`) |
| `github-actions/` | CI/CD governance — workflow syntax, OIDC federation, SHA-pinning, attestations / SLSA Build L3 (see `github-actions/AGENTS.md`) |
| `wiremock-api-mocks/` | Shared cluster-wide WireMock mock server in `testing-system` namespace — stubs declared in consumer Helm values, registered via Admin API at install/upgrade (see `wiremock-api-mocks/AGENTS.md`) |

## For AI Agents

### Working In This Directory
- Skills here follow the `<domain>-<purpose>` naming convention (e.g. `github-actions`, `addons-and-building-blocks`).
- The SKILL.md `description:` should be deliberately exhaustive — these skills are platform-wide and need to fire on many file patterns, tool names, and PR triggers. The two existing skills' descriptions are good reference points.
- Tone convention: every skill in this directory is framed as **"Distinguished Platform Engineer's Playbook"** — fleet-scale governance, blast-radius control, supply-chain integrity over one-off convenience.

### Testing Requirements
- **`scripts/validate-skills.sh` skips this directory.** Either run the validator with `CODING_DIR` overridden, or manually verify per file:
  1. Frontmatter parses as YAML and contains `name`, `description`, `license`, `compatibility`, non-empty `metadata` map.
  2. Markdown body after the closing `---` is non-empty.
  3. Fenced code-block markers are even in count (no unclosed ` ``` `).
- CI does NOT catch regressions here today.

### Common Patterns
- `metadata:` includes `domain: platform-engineering` plus `platform:` and `pattern:` tags that downstream skill registries can filter on.
- Body opens with a numbered "Non-negotiables" list — the rules to flag in a PR review *before anything else*.
- Each skill includes a "WHEN TO USE THIS SKILL" matrix that distinguishes triggers from look-alike but out-of-scope scenarios (e.g. "`.gitlab-ci.yml` → No, wrong platform").

## Dependencies

### Internal
- `../README.md` — references each skill in the "Platform Engineering" table; rename → README update required.
- `../scripts/validate-skills.sh` — *currently does not validate this tree*; expanding it is a tracked follow-up.

<!-- MANUAL: -->
