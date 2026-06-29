<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-28 | Updated: 2026-06-28 -->

# kubernetes-operator-golang

## Purpose
Skill that guides building **production-grade Kubernetes Operators in Go** on
**kubebuilder (go/v4) + controller-runtime**, with **Operator SDK** as the
OLM-aware wrapper. Covers the full lifecycle: project scaffolding, CRD/API design
(`*_types.go`, kubebuilder markers, OpenAPI + CEL validation, `status.conditions`,
versioning + conversion), the Reconcile loop (level-based + idempotent
convergence, finalizers, `CreateOrUpdate`, owner references, status subresource,
requeue strategy, watches/predicates), admission webhooks
(`CustomValidator`/`CustomDefaulter`), the manager entrypoint (leader election,
health probes, zap logging, metrics), least-privilege RBAC, envtest/Ginkgo
testing, and OLM packaging (bundle, `ClusterServiceVersion`, `opm` File-Based
Catalogs, dependency resolution, OLM v0 vs v1). Encodes the CNCF Operator
capability levels, the four golden signals, and the Seven Habits of Highly
Successful Operators.

## Key Files
| File | Description |
|------|-------------|
| `SKILL.md` | The skill definition — `name: kubernetes-operator-golang`, `domain: platform-engineering`, `pattern: kubernetes-operator`, `language: golang`, `stack: kubebuilder-go-v4 + controller-runtime + operator-sdk + olm` |

## Subdirectories
None.

## For AI Agents

### Working In This Directory
- Edit `SKILL.md` only.
- The **CORE PRINCIPLES (NON-NEGOTIABLE)** list at the top is the load-bearing
  review gate — do not soften it. Particular load-bearers: reconcile is
  level-based not edge-based (#1), idempotent via create-or-update not blind
  Create (#2), declarative convergence (#3), spec=intent / status=observation with
  the status subresource (#5), operator downtime ≠ operand downtime (#6),
  finalizers-before-act for external cleanup (#7), least privilege + non-root (#8).
- **Versions move fast.** Code examples target kubebuilder `go/v4` and current
  controller-runtime/apimachinery. Where an API is version-ambiguous the body
  leads with the **released** form and flags the emerging one — keep that framing
  when editing (e.g. the `CustomValidator`/`CustomDefaulter` `runtime.Object` form
  vs generic `Validator[T]`; OLM v1 `ClusterExtension` spec). Do not "upgrade"
  examples to tip APIs without a `go.mod` pin to justify it.
- Generated-file discipline is itself a rule in the body: examples must edit
  source (`*_types.go`, rbac/webhook markers) and regenerate, never hand-edit
  `zz_generated.*` / `config/crd/bases/*`.
- The go/v3→go/v4 layout note (`main.go`→`cmd/main.go`, `controllers/`→
  `internal/controller/`, `Metrics` struct) is a frequent regression source —
  keep it accurate.
- The `description:` field is intentionally exhaustive (auto-detection trigger
  surface — phrases + file patterns). When extending coverage, extend the trigger
  list to match.

### Testing Requirements
- After editing, run `./scripts/validate-skills.sh` from the repo root — the
  validator **does** walk `platform-engineering/` (the `DOMAIN_DIRS` array).
- The skill is large with many fenced `go`/`bash`/`yaml` blocks; the most likely
  regression is an **odd fence count**. Verify: `grep -cE '^\s*```' SKILL.md` must
  be even.
- The skill's own examples must satisfy its own CORE PRINCIPLES — every reconcile
  snippet should keep `client.IgnoreNotFound`, `SetControllerReference`, status
  conditions + `observedGeneration`, and idempotent `CreateOrUpdate`.

### Companion Subagents
- This skill is orchestrated by five repo-scoped Claude Code subagents in
  `../../.claude/agents/`: `operator-scaffolder`, `crd-api-designer`,
  `reconciler-author`, `olm-packager`, `operator-tester`. The "Subagent
  Orchestration" table at the end of `SKILL.md` maps phases → agents. If you
  rename a phase or agent, update both sides.

### Common Patterns
- "CORE PRINCIPLES (NON-NEGOTIABLE)" numbered list — same authoring style as
  `kafka-strimzi-operator`, `addons-and-building-blocks`, `github-actions`.
- Phase-by-phase body (scaffold → CRD → reconciler → webhooks → manager →
  observability → RBAC → testing → OLM) with concrete code, closing with an
  anti-patterns table (violation → why it breaks → do instead) and a pre-done
  verification checklist partitioned by surface.

## Dependencies

### Internal
- `../../scripts/validate-skills.sh` — enforces frontmatter + body + fenced-block
  contract; walks `platform-engineering/`.
- `../../README.md` — references this skill in the "Platform Engineering" table;
  rename → README update required.
- `../../.claude/agents/{operator-scaffolder,crd-api-designer,reconciler-author,olm-packager,operator-tester}.md`
  — the companion subagents this skill delegates to.
- `../kafka-strimzi-operator/SKILL.md` — sibling skill about **operating** a
  third-party operator (Strimzi); this skill is about **building** operators.
  Complementary, not overlapping — cross-referenced in the description.

### External
None at runtime — this is documentation, not code. The skill *describes*
kubebuilder / Operator SDK / controller-runtime / OLM / `opm` but does not depend
on them being installed.

<!-- MANUAL: -->
