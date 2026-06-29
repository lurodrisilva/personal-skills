<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-29 | Updated: 2026-06-29 -->

# crossplane

## Purpose
Skill that guides **building and operating a Crossplane control plane** —
extending the Kubernetes API into a self-service platform API. Covers the full
authoring surface: installing Crossplane, Providers + ProviderConfig credentials
(Secret / IRSA / GKE & AKS workload identity), Managed Resources and their
lifecycle (`managementPolicies`, `deletionPolicy`, importing existing cloud
resources), CompositeResourceDefinitions (XRDs) as versioned platform APIs,
Compositions (function `Pipeline`), Composition Functions
(`function-patch-and-transform`, `function-auto-ready`,
`function-environment-configs`, …), packages (Providers/Configurations/Functions,
`crossplane.yaml`, `xpkg build/push`, ImageConfig + Cosign), GitOps delivery
(ArgoCD/Flux), testing (`crossplane render`/`validate`/`beta trace`), and day-2
Operations. **Crossplane v2-first** (current GA): namespaced XRs, Claims removed,
namespaced Managed Resources, functions-only composition — with v1 differences and
migration flagged inline.

## Key Files
| File | Description |
|------|-------------|
| `SKILL.md` | The skill definition — `name: crossplane`, `domain: platform-engineering`, `pattern: kubernetes-control-plane`, `stack: crossplane-v2 + compositions + functions + packages`, `version: crossplane-v2-first-v1-flagged` |

## Subdirectories
None.

## For AI Agents

### Working In This Directory
- Edit `SKILL.md` only.
- The **CORE PRINCIPLES (NON-NEGOTIABLE)** and the **VERSION MAP** at the top are
  the load-bearing review gate — do not soften them. Highest-blast-radius facts to
  keep accurate:
  - **XRD is `apiextensions.crossplane.io/v2` but `Composition` STAYS `…/v1`.** This
    is counterintuitive; the body carries an explicit "do NOT bump" note. Two
    independent research sources corroborated it — keep it.
  - v2 removed **Claims** (`claimNames` deprecated), native patch-and-transform
    (→ `function-patch-and-transform`), and `ControllerConfig`
    (→ `DeploymentRuntimeConfig`); XRs and Managed Resources are **namespaced**
    (the `.m.` API-group infix), with `ProviderConfig` + `ClusterProviderConfig`.
  - **Namespaced MRs are provider-dependent** (AWS GA at v2; Azure/GCP/others were
    migrating) — keep the per-provider caveat.
  - **MRD/MRAP and Operations are alpha** (`…v1alpha1`) — keep them flagged alpha.
  - CLI subcommand promotion is **in flux** (`render` vs `composition render`,
    `validate` vs `beta validate`) — keep the "check `crossplane --help`" caveat.
- Don't hardcode a patch version (`v2.3.3`) in the body — say "v2.x, pin to your
  installed version". Quote string-typed `forProvider` fields in every MR example.
- The `description:` uses a `>-` YAML block scalar **on purpose** — it is
  colon-dense (`scope:`, `mode:`, `XRD:`), and a plain scalar would mis-parse as a
  map under `yq`. Keep the block scalar and re-verify with `yq` after editing.

### Testing Requirements
- **`scripts/validate-skills.sh` validates this directory** (its `DOMAIN_DIRS`
  includes `platform-engineering/`) — CI runs it on every push and PR. Run it
  locally before pushing; it checks:
  1. YAML frontmatter parses and contains `name`, `description`, `license`, `compatibility`, non-empty `metadata` map.
  2. Markdown body after the closing `---` is non-empty.
  3. Fenced code-block markers are even in count — this skill is YAML-dense; an unclosed fence is the most likely regression. `grep -c '^```' SKILL.md` must be even.
- After editing the frontmatter, confirm `.description` still parses as a **string**, not a map: `yq '.description | type'` should print `!!str`.

### Companion Subagents
- Orchestrated by five repo-scoped subagents in `../../.claude/agents/`:
  `crossplane-control-plane-operator`, `crossplane-managed-resource-author`,
  `crossplane-composition-author`, `crossplane-package-publisher`,
  `crossplane-tester`. The "Subagent Orchestration" table at the end of `SKILL.md`
  maps phases → agents. Rename a phase or agent → update both sides.

### Common Patterns
- "CORE PRINCIPLES (NON-NEGOTIABLE)" numbered list + a phase-by-phase body
  (install → providers → managed resources → composition → functions → packages →
  gitops → testing → day-2), closing with an anti-patterns table (violation → why
  it breaks → do instead) and a pre-done verification checklist partitioned by
  surface — same authoring shape as `kubernetes-operator-golang`,
  `kafka-strimzi-operator`, `addons-and-building-blocks`.

## Dependencies

### Internal
- `../../scripts/validate-skills.sh` — enforces the frontmatter + body + fenced-block contract.
- `../../README.md` — references this skill in the "Platform Engineering" table; rename → README update required.
- `../../.claude/agents/crossplane-*.md` — the five companion subagents this skill delegates to.
- `../addons-and-building-blocks/SKILL.md` — sibling skill about **consuming**
  provider-shipped Managed Resources inside Helm building blocks + ArgoCD. This
  skill is about **building** the control plane (MRs, XRDs, Compositions,
  functions, packages). Complementary, not overlapping — cross-referenced both ways.

### External
None at runtime — this is documentation, not code. The skill *describes*
Crossplane v2 / the `crossplane` CLI / Upbound providers + functions but does not
depend on them being installed in this repo.

<!-- MANUAL: -->
