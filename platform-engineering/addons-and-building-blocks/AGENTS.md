<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-04-25 | Updated: 2026-04-25 -->

# addons-and-building-blocks

## Purpose
Skill that guides authoring + reviewing **layered Kubernetes platform blueprints**: baseline cluster addons (ArgoCD App-of-Apps with `base_chart/` + `addon_charts/*`), shared Helm library charts (`myorg.*` / `plat-net.*` helpers), and application-level building blocks (databases on CloudNativePG, caches via Crossplane `RedisCache`, …). Covers OCI chart distribution (`oci://ghcr.io/<org>/helm-charts`), ArgoCD `Application` templates with sync waves + `ServerSideApply` + `ignoreDifferences`, the wrapper-chart `tests/chart/` helm-unittest pattern, the four-tier validation gate (`yamllint` → `helm lint` → `helm-unittest` → `kubeconform`), and the Terraform + Terratest AKS foundation that bootstraps ArgoCD.

## Key Files
| File | Description |
|------|-------------|
| `SKILL.md` | The skill definition — `name: addons-and-building-blocks`, `domain: platform-engineering`, `pattern: helm-addons-and-building-blocks`, `platform: kubernetes`, `cloud: azure-aks` |

## Subdirectories
None.

## For AI Agents

### Working In This Directory
- Edit `SKILL.md` only.
- The "layer cake" mental model (AKS foundation → baseline addons → commons library → building blocks → product charts) is the central abstraction — every other rule depends on the one-way downward dependency flow. Do not edit it without intent.
- The skill encodes nine non-negotiable rules at the top (layer cake, one library per prefix, OCI-only deps in production, `| trunc 63 | trimSuffix "-"`, quote every Crossplane string, camelCase Helm values + snake_case ArgoCD values, wrapper-chart testing, `make all` parity with CI + Helm pinned to v3.20.0, never push to `master`). Treat them as load-bearing — flag PR violations against them before anything else.
- The `description:` field is unusually long because this skill must trigger on many file patterns and PR-level signals. When extending coverage, extend the description's trigger list to match.

### Testing Requirements
- **`scripts/validate-skills.sh` does NOT walk this directory.** After editing:
  1. Manually verify the YAML frontmatter parses and contains `name`, `description`, `license`, `compatibility`, non-empty `metadata` map.
  2. Verify body after closing `---` is non-empty.
  3. Verify fenced code-block markers are even in count.
- One option: run a copy of `validate-skills.sh` with `CODING_DIR` pointed at this directory's parent.

### Common Patterns
- "Non-negotiables encoded in this skill" numbered list — same authoring style as the `github-actions` skill.
- "WHEN TO USE THIS SKILL" matrix opens both platform-engineering skills.
- Long, exhaustive `description:` trigger lists are the convention here (vs the more focused descriptions in `coding/`).

## Dependencies

### Internal
- `../../README.md` — references this skill in the "Platform Engineering" table.
- `../../scripts/validate-skills.sh` — *currently does not validate this file*; expanding the validator is a tracked follow-up.

### External
None at runtime — this is documentation, not code.

<!-- MANUAL: -->
