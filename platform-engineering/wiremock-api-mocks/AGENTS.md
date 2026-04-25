<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-04-25 | Updated: 2026-04-25 -->

# wiremock-api-mocks

## Purpose
Skill that guides packaging and operating **WireMock as a shared, cluster-wide HTTP API mock server** delivered as a baseline addon (`addon_charts/wiremock/`) under the `addons-and-building-blocks` platform blueprint. Covers chart structure, `testing-system` namespace placement, single-replica `Recreate` rollout, NetworkPolicy gating by consumer label, and per-release stub registration via the WireMock Admin API. Defines the consumer-app surface — `mocks.wiremock.enabled` + `mocks.wiremock.stubs` in Helm values, three-line include of the `myorg.wiremock.*` library helpers — plus the `metadata.owner=<release>` tagging contract that makes atomic per-release replace work on a shared instance. Treats `WireMock.Net` as a separate, in-process tool for `dotnet test` only — never as the cluster image.

## Key Files
| File | Description |
|------|-------------|
| `SKILL.md` | The skill definition — `name: wiremock-api-mocks`, `domain: platform-engineering`, `pattern: shared-mock-server-addon`, `depends_on: addons-and-building-blocks` |

## Subdirectories
None.

## For AI Agents

### Working In This Directory
- Edit `SKILL.md` only.
- This skill is a **specialization** of `addons-and-building-blocks` — it must never contradict that skill. If a non-negotiable here conflicts with the parent, fix this skill, not the parent.
- The 12 non-negotiables at the top of the body are flag-first rules in PR review. Particular load-bearers: shared-not-sidecar (#1), Java-WireMock-not-WireMock.Net for the cluster image (#2), `metadata.owner=<release>` tagging for atomic replace (#4), URL-prefix isolation `/__mocks__/<release>/` (#5), production gating (#8), NetworkPolicy as the only realistic auth boundary (#9).
- The library-helper names (`myorg.wiremock.adminUrl`, `myorg.wiremock.stubsConfigMap`, `myorg.wiremock.syncJob`, `myorg.wiremock.cleanupJob`) live in `plat-eng-commons-package` per the parent skill's "one library per prefix" rule. Do not introduce a competing prefix.
- Sync wave 5 is a default suggestion in the body — adjust if your repo's existing waves clash. Filename `{NN}-wiremock.yaml` MUST equal `argocd.argoproj.io/sync-wave`.
- The `description:` field is intentionally exhaustive (auto-detection trigger surface). When extending coverage to new file patterns or workflows, extend the description's trigger list to match.

### Testing Requirements
- **`scripts/validate-skills.sh` does NOT walk this directory** (the validator is hardcoded to `coding/`). After editing, manually verify per the parent skill's three checks:
  1. YAML frontmatter parses and contains `name`, `description`, `license`, `compatibility`, non-empty `metadata` map.
  2. Markdown body after the closing `---` is non-empty.
  3. Fenced code-block markers are even in count.
- The skill's own examples must satisfy its own non-negotiables — every YAML/Helm snippet should have `enabled: false` defaults, `Recreate` strategy, NetworkPolicy gating, `metadata.owner` tagging.

### Common Patterns
- "Non-negotiables encoded in this skill" numbered list — same authoring style as `addons-and-building-blocks` and `github-actions`.
- "WHEN TO USE THIS SKILL" matrix opens the body.
- Anti-patterns table near the end maps each violation to "why it breaks the platform" — keep this format when extending.
- Pre-done verification checklist is partitioned by surface (addon chart / base chart / library helpers / consumer chart / .NET tests / validation) — one box per surface, every box must check before declaring done.

## Dependencies

### Internal
- `../../README.md` — references this skill in the "Platform Engineering" table.
- `../../scripts/validate-skills.sh` — *currently does not validate this file*; expanding the validator is a tracked follow-up.
- `../addons-and-building-blocks/SKILL.md` — parent skill whose layer-cake / OCI / four-tier-gate rules this skill inherits and never contradicts.

### External
None at runtime — this is documentation, not code.

<!-- MANUAL: -->
