<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-05-24 | Updated: 2026-05-24 | DEEPINIT: 2026-05-24 -->

# helm-chart-packages

## Purpose
Skill that guides authoring + reviewing **Helm chart artifacts** end-to-end — `Chart.yaml`, `values.yaml`, `values.schema.json`, `templates/*.yaml`, `templates/_*.tpl`, `templates/NOTES.txt`, `templates/tests/*`, `crds/*`, `charts/*`, `.helmignore`, `*.tgz`, `*.tgz.prov`, `Chart.lock`. Synthesizes the official Helm reference (Chart.yaml v2 contract, SemVer 2 versioning + appVersion split, Go template + Sprig idioms, named templates, standard `app.kubernetes.io/*` + `helm.sh/chart` labels, subcharts + globals + import-values, library charts, chart hooks + test hooks, `crds/` lifecycle) with the supply-chain track (PGP `.prov` provenance signing, OCI registry distribution, immutable `oci://...@sha256:` digest pinning, `helm verify`, lint + dry-run + `helm get manifest`) into one playbook.

## Key Files
| File | Description |
|------|-------------|
| `SKILL.md` | Skill definition — `name: helm-chart-packages`, `domain: platform-engineering`, `pattern: kubernetes-package-management`, `platform: helm`, `artifact: chart` |

## Subdirectories
None.

## For AI Agents

### Working In This Directory
- Edit `SKILL.md` only.
- The 12 non-negotiables at the top of the body are flag-first PR rules. Load-bearers: `apiVersion: v2` (#1), SemVer 2 + `version` bump on every change (#2), one chart = one purpose (#3), deterministic render (no `randAlphaNum`/`now`/`uuidv4` in field values) (#4), standard labels everywhere + immutable selector subset (#5), `values.schema.json` for fail-fast inputs (#6), CRDs in `crds/` (installed once, never upgraded/deleted) (#7), no secrets in `values.yaml` (#8), pinned + locked dependencies (#9), `--sign` packaged charts + `oci://...@sha256:` digest pinning in production (#10), lint + dry-run + template not optional (#11), hooks own their lifecycle via `hook-delete-policy` (#12).
- This skill **sister-references** `addons-and-building-blocks` — that skill's library-chart + OCI-distribution + four-tier validation rules layer on top of this one. Where they overlap (OCI push, lint gates), keep the wording aligned.
- The `description:` field exhaustively lists triggering file patterns and phrases — extend when introducing new template idioms or registry workflows.

### Testing Requirements
- **`scripts/validate-skills.sh` does NOT walk this directory.** After editing, manually verify:
  1. YAML frontmatter parses and contains `name`, `description`, `license`, `compatibility`, non-empty `metadata` map.
  2. Markdown body after the closing `---` is non-empty.
  3. Fenced code-block markers are even in count.
- Every example `Chart.yaml` / `values.yaml` / template snippet must satisfy the skill's own non-negotiables — `apiVersion: v2`, standard labels, no inline secrets, no non-deterministic render, hooks carry `hook-delete-policy`.

### Common Patterns
- "Non-negotiable rules" numbered list under `## 0` — same authoring style as other platform-engineering skills.
- Chart skeleton tree near the top, then layer-by-layer patterns (`Chart.yaml` → `values.yaml` → `values.schema.json` → labels → subcharts → hooks → tests → packaging → signing → OCI distribution).
- Anti-patterns table maps each violation to "what breaks in upgrade / rollback / supply chain".

## Dependencies

### Internal
- `../../README.md` — references this skill in the "Platform Engineering" table once added.
- `../../scripts/validate-skills.sh` — *currently does not validate this file*; expanding the validator is a tracked follow-up.
- `../addons-and-building-blocks/SKILL.md` — sibling skill whose Helm library-chart + ArgoCD App-of-Apps + four-tier validation rules sit one layer up.
- `../wiremock-api-mocks/SKILL.md` — sibling addon-chart consumer of the same Helm packaging rules.

### External
None at runtime — this is documentation, not code.

<!-- MANUAL: -->
