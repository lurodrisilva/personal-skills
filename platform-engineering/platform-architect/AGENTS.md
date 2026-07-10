<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-07-10 | Updated: 2026-07-10 -->

# platform-architect

## Purpose
Skill for the **Distinguished Platform Engineering Architect** role — the
**capstone** of `platform-engineering/`. It owns the **strategy, reference
architecture, org design, developer-experience metrics, and governance** of an
Internal Developer Platform (IDP) — the *what and why* — and **delegates every
implementation** to the sibling skills (`terraform-iac`, `crossplane`,
`gitops-argocd`, `observability-stack`, `aws-finops`/`azure-finops`,
`kubernetes-security`, `helm-chart-packages`, `github-actions`). The organizing
idea is **platform-as-a-product**: developers are customers, adoption + DORA are
the KPIs, and a platform nobody uses is a failed platform.

## Key Files
| File | Description |
|------|-------------|
| `SKILL.md` | The skill — `name: platform-architect`, `domain: platform-engineering`, `role: distinguished-platform-architect`, `pattern: platform-as-a-product`. Six phases A–F (Strategy / Reference-architecture / Team-topologies / DevEx-metrics / Governance / Maturity), each with a decision tree + one produced-artifact example. |

## Subdirectories
| Directory | Purpose |
|-----------|---------|
| `tools/` | 3 read-only assessment scripts (`dora-metrics-report.sh`, `adr-lint.sh`, `platform-maturity-scan.sh`) — DORA proxies from git, MADR ADR/RFC lint, IDP maturity-signal scan; read-only is a hard invariant (see `tools/AGENTS.md`) |

## For AI Agents

### Working In This Directory
- Edit `SKILL.md` (and the read-only `tools/` scripts). Almost every change is authoring.
- **The doctrine is the spine, in order:** *the platform is a product; developers
  are customers* → *paved road over mandate — guardrails, not gates* → *minimise
  consumer cognitive load (Team Topologies)* → *every capability maps to an IDP
  plane AND a delegated implementer skill* → *decisions are recorded (ADR/RFC),
  reversibility sets the ceremony* → *measure outcomes (DORA + SPACE + adoption),
  not output* → *strategy/governance decisions are human-gated* → *sequence by
  maturity (CNCF model), don't skip levels*. Keep those invariants intact on edits.
- **This skill delegates, it does not implement.** The highest-value invariant to
  protect: it never re-implements infrastructure. Terraform → `../terraform-iac/`;
  Crossplane → `../crossplane/`; GitOps → `../../operations/gitops-argocd/`;
  observability → `../../operations/observability-stack/`; FinOps →
  `../aws-finops/`/`../azure-finops/`; security → `../../security/kubernetes-security/`;
  Helm → `../helm-chart-packages/`; CI → `../github-actions/`. If an edit starts
  writing HCL or manifests here, it belongs in a sibling skill.
- **Version discipline is load-bearing:** the frameworks (CNCF maturity model,
  DORA, SPACE, Team Topologies, Backstage, Thoughtworks radar) evolve. **Pin no
  product/tool version in prose; frame framework specifics as "verify against the
  canonical source".** Same no-version-pin doctrine as `terraform-iac` / the FinOps
  skills.
- Highest-value facts to keep correct: **the five IDP planes** (Developer Control /
  Integration & Delivery / Monitoring & Logging / Security / Resource); **DORA is a
  balanced four-key set** (throughput + stability, never one alone); **Team
  Topologies** interaction modes (**X-as-a-Service** is the default + destination);
  **guardrails-not-gates**; **there is NO MCP/agent that "makes a decision"** —
  decisions are human-gated (agents analyse/draft/recommend); **CNCF maturity** is
  five aspects × four levels, advance the weakest load-bearing aspect first.
- The `description:` uses a `>-` block scalar (colon/backtick-dense) — keep it and
  re-verify `yq --front-matter=extract '.description | type'` is `!!str` after edits.

### Testing Requirements
- **`scripts/validate-skills.sh` validates this directory** (`platform-engineering/`
  is in `DOMAIN_DIRS`): frontmatter (`name`/`description`/`license`/`compatibility`,
  non-empty `metadata` map), non-empty body, even fence count. Run it after edits.
- `tools/` is **not** validator-covered — verify by hand (`bash -n`, the
  mutating-verb grep, executable bit) per `tools/AGENTS.md`.

### Companion Subagents
- Ships a **6-agent Platform-Architecture team** in `../../.claude/agents/`:
  `platform-strategy-advisor` (Phase A — platform-as-a-product, build-vs-buy,
  Wardley mapping, technology radar, capability roadmap, investment thesis),
  `platform-reference-architect` (Phase B — the five IDP planes, capability map,
  golden-path/paved-road design, plane→implementer delegation),
  `team-topologies-designer` (Phase C — team types, the three interaction modes,
  cognitive-load reduction, RACI, Conway alignment), `developer-experience-lead`
  (Phase D — DORA + SPACE + adoption/NPS scorecard, feedback loops; reads
  `dora-metrics-report.sh`), `governance-standards-author` (Phase E — ADR/MADR,
  RFC, guardrails-not-gates, radar governance, off-road exceptions; owns
  `adr-lint.sh`), `platform-maturity-assessor` (Phase F — CNCF maturity
  assessment, gap analysis, roadmap sequencing; owns `platform-maturity-scan.sh`).
  The SKILL's "Subagent Orchestration" table maps concern → agent; update both on
  rename.

### Common Patterns
- Intro + mental model → the concern × artifact table → CORE PRINCIPLES →
  CAPABILITY MAP → phases A–F (Strategy / Reference-architecture / Team-topologies /
  DevEx-metrics / Governance / Maturity) each with one decision tree + one produced
  artifact → anti-patterns → checklist → REFERENCE → MCP surface → subagent
  orchestration. Same authoring shape as the sibling `terraform-iac` skill.

## Dependencies

### Internal
- `../../scripts/validate-skills.sh` — enforces the SKILL.md contract.
- `../../README.md` — references this skill in the "Platform Engineering" table and
  the CI-enforced skills-count badge; add/rename → README update.
- `../../.claude/agents/{platform-strategy-advisor,platform-reference-architect,team-topologies-designer,developer-experience-lead,governance-standards-author,platform-maturity-assessor}.md`
  — the 6 companion subagents.
- Delegated-to siblings (cross-referenced to keep the "decide vs build" boundary
  sharp): `../terraform-iac/`, `../crossplane/`, `../helm-chart-packages/`,
  `../github-actions/`, `../aws-finops/`, `../azure-finops/`,
  `../../operations/gitops-argocd/`, `../../operations/observability-stack/`,
  `../../security/kubernetes-security/`.

### External
None at runtime — documentation. Describes platform-engineering strategy and cites
the CNCF Platform Engineering Maturity Model, DORA, SPACE, Team Topologies,
Backstage, and the Thoughtworks Technology Radar. `tools/` scripts need only `git`
+ POSIX tools. No `jq`. No version pinned.

<!-- MANUAL: -->
