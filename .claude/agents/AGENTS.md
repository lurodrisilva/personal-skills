<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-28 | Updated: 2026-06-28 -->

# agents

## Purpose
Committed **Claude Code subagent definitions** — focused agents that skills in
this repo delegate phase work to. Each file is a Markdown document with YAML
frontmatter (`name`, `description`, `tools`, `model`) followed by the agent's
system prompt. The current roster is the operator-development team orchestrated by
`platform-engineering/kubernetes-operator-golang/SKILL.md` (its "Subagent
Orchestration" table maps skill phases → these agents).

## Key Files
| File | Description |
|------|-------------|
| `operator-scaffolder.md` | Phase 1 — `kubebuilder`/`operator-sdk` `init`/`create api`/`create webhook`, the PROJECT file, Makefile targets, go/v4 layout |
| `crd-api-designer.md` | Phase 2 — `*_types.go`, kubebuilder markers, OpenAPI + CEL validation, `status.conditions`, versioning + conversion (model=opus for complex schemas) |
| `reconciler-author.md` | Phases 3–7 — the Reconcile loop, finalizers, `CreateOrUpdate`, owner refs, status, requeue, watches, webhooks, manager wiring, RBAC markers (model=opus for non-trivial loops) |
| `olm-packager.md` | Phase 9 — OLM bundle, `ClusterServiceVersion`, `annotations.yaml`, `opm` File-Based Catalogs, dependency resolution, OLM v0/v1 install |
| `operator-tester.md` | Phase 8 — envtest + Ginkgo/Gomega suites, table-driven unit tests, idempotency + chaos/e2e |

## Subdirectories
None.

## For AI Agents

### Working In This Directory
- One subagent per file; the frontmatter `name` MUST match the filename stem
  (e.g. `reconciler-author.md` → `name: reconciler-author`).
- Required frontmatter: `name`, `description` (when to invoke + hand-off
  boundaries), `tools` (comma-separated allow-list), `model` (`sonnet` default;
  `crd-api-designer` and `reconciler-author` note `opus` for complex work).
- Every operator subagent's prompt **anchors to the skill** and enforces its CORE
  PRINCIPLES — it does not restate the whole skill. Keep each agent's scope to its
  phase(s) and its explicit "what you do NOT do" hand-offs so the roster stays
  composable (scaffolder → designer → reconciler → tester → packager).
- These agents are **repo-scoped** (see `../AGENTS.md`). If you add an agent, also
  add it to the skill's Subagent Orchestration table and the skill dir's
  `AGENTS.md` "Companion Subagents" section; if you rename one, update both sides.

### Testing Requirements
- Not covered by `scripts/validate-skills.sh`. After editing, manually verify:
  1. YAML frontmatter parses (`yq`) and carries `name`, `description`, `tools`, `model`.
  2. `name` equals the filename stem.
  3. `model` is a valid tier and `tools` are real tool names.

### Common Patterns
- Body shape: a one-line role statement that points at the skill, a "What you do"
  list, a "What you do NOT do" hand-off list, and a "Done when" acceptance line.

## Dependencies

### Internal
- `../../platform-engineering/kubernetes-operator-golang/SKILL.md` — the shared
  contract every agent here reads first and enforces.

### External
- Claude Code subagent runtime (loads `tools` / `model` from frontmatter).

<!-- MANUAL: -->
