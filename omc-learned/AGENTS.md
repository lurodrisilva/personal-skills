<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-05-24 | Updated: 2026-05-24 | DEEPINIT: 2026-05-24 -->

# omc-learned

## Purpose
Holding area for **oh-my-claudecode "learned skill" expertise notes** — short, single-insight markdown files (YAML frontmatter `name` + `description` + `triggers` list, then a focused write-up) captured by `/oh-my-claudecode:learner` from live sessions. These are NOT SKILL.md files: they have no `license` / `compatibility` / `metadata` map and are not loaded by `coding/`-walker validation. They serve as the staging ground for future promotion into a full `coding/` or `platform-engineering/` SKILL.md once the insight generalizes.

## Key Files
| File | Description |
|------|-------------|
| `otel-view-tagkeys-control-customMetrics-columns-expertise.md` | OpenTelemetry .NET + Azure Monitor exporter — `MetricStreamConfiguration.TagKeys` on `AddView(...)` is the only mechanism that propagates a dimension into Application Insights `customMetrics.customDimensions`. Activity tags and Resource attributes do not become filterable columns. |
| `skill-frontmatter-yaml-colon-trap-expertise.md` | SKILL.md frontmatter `description:` block — backtick-quoted code spans containing `: ` (colon + space) still trigger YAML's mapping-key parse, surfacing as the misleading `"mapping values are not allowed in this context"` yq error. Markdown backticks do not protect from YAML grammar. |
| `webfetch-github-tree-confabulation-expertise.md` | WebFetch hallucinates plausible YAML/code content when fed a GitHub HTML tree URL because the underlying summarisation fills the gap with realistic-looking output. Always pin file lookups to `raw.githubusercontent.com` for verbatim content. |

## Subdirectories
None.

## For AI Agents

### Working In This Directory
- These files use the **`/oh-my-claudecode:learner` schema**, not the SKILL.md contract. Frontmatter is just `name`, `description`, `triggers:` (a list), and the body is a tight insight + symptom + fix write-up.
- Do **not** rename to `SKILL.md`, do **not** add `license:` / `compatibility:` / `metadata:` map to make them "look like" a full skill — that would imply they're CI-validated and auto-loaded by Claude Code / opencode skill discovery, which they aren't.
- Promote to a full skill **only** when the insight has generalized into a discipline (multiple related rules, an anti-patterns table, a verification checklist worth pre-running). At that point: create `coding/<name>/SKILL.md` or `platform-engineering/<name>/SKILL.md`, copy the insight into the body's anti-patterns section, then keep the source note here as the "origin story" reference (or delete it once the rule is fully captured).
- The `triggers:` list IS the auto-detection surface — extend it when a near-miss session would have benefited from the note firing.

### Testing Requirements
- `scripts/validate-skills.sh` does **NOT** walk this directory — its `DOMAIN_DIRS` covers `coding/` and `platform-engineering/`, not `omc-learned/`. Frontmatter correctness is enforced manually:
  1. Frontmatter is a valid YAML map containing at minimum `name` and `description`.
  2. Body after the closing `---` is non-empty.
- These files are reference material — there is no build, no render, no consumer that would catch a broken trigger list automatically.

### Common Patterns
- Frontmatter `description:` opens with the insight in one sentence — the same sentence Claude can match against the user's prompt for proactive recall.
- Body sections: **The Insight** (1 paragraph) → **Symptoms** (what the failure looks like) → **Root cause** (why) → **Fix** (the corrective pattern) → **Don't do** (the anti-pattern).
- File naming: `<short-handle>-expertise.md` — the `-expertise` suffix marks it as a learner-captured insight rather than a candidate skill.

## Dependencies

### Internal
- `../scripts/validate-skills.sh` — explicitly **does not** walk this directory.
- `../coding/` / `../platform-engineering/` — promotion targets when an insight generalizes into a discipline.

### External
None at runtime — this is documentation, not code.

<!-- MANUAL: -->
