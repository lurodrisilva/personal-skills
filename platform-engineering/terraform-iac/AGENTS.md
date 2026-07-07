<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-07-07 | Updated: 2026-07-07 -->

# terraform-iac

## Purpose
Skill for **Infrastructure as Code with Terraform / OpenTofu** — declarative HCL2
that provisions and manages infrastructure through a **plan → review → gated apply**
lifecycle recorded in Git. Owns the operating doctrine + the Terraform/OpenTofu
surface for **module authoring**, **state & backends**, **providers & auth**, **plan
review & policy-as-code**, **testing**, and **drift & day-2**. The client-side,
plan/apply archetype of IaC; sits in `platform-engineering/` next to `crossplane`
(the K8s-native, continuously-reconciling archetype it delegates to) and `aws-cli`
(provider-CLI mechanics it delegates to).

## Key Files
| File | Description |
|------|-------------|
| `SKILL.md` | The skill — `name: terraform-iac`, `domain: platform-engineering`, `tool: terraform`, `also: opentofu`, `discipline: infrastructure-as-code`, `language: hcl2`, `pattern: declarative-iac` |

## Subdirectories
| Directory | Purpose |
|-----------|---------|
| `tools/` | 3 read-only `terraform`/`tofu` triage scripts (`tf-plan-summary.sh`, `tf-state-inventory.sh`, `tf-drift-check.sh`) — validate/plan + state inventory + refresh-only drift; read-only is a hard invariant (see `tools/AGENTS.md`) |

## For AI Agents

### Working In This Directory
- Edit `SKILL.md` (and the read-only `tools/` scripts). Almost every change is authoring.
- **The doctrine is the spine, in order:** *plan before apply* (apply is a gated,
  human-reviewed change; read the plan, never blind-apply) → *remote state with
  locking is mandatory* (S3+DynamoDB / azurerm / gcs / Terraform Cloud — never local
  state for shared infra) → *least-privilege short-lived auth* (OIDC / assume-role /
  workload identity — never long-lived static keys) → *pin via the lockfile*
  (`required_providers` constraints resolved into a committed `.terraform.lock.hcl`)
  → *compose modules over copy-paste* → *validate/fmt/tflint/tfsec|checkov +
  policy-as-code (OPA/Sentinel/Conftest) as CI gates* → *drift is detected
  (`plan -refresh-only`) and reconciled through Git, never console clicks* →
  *destroy is guarded* (`prevent_destroy`, `-target` discipline, plan review). Keep
  those invariants intact on edits.
- **Version discipline is load-bearing:** Terraform, OpenTofu, every provider, and
  the policy/scanning tools move fast. **State behavior, pin NO tool/provider version
  in prose, and frame version constraints / resource arguments / subcommands as
  "verify against the Terraform / OpenTofu registry + docs".** The ONE correct place
  to pin is the machine-checked **`.terraform.lock.hcl`** — say the lockfile pins
  them; do not hard-pin in example prose. Same no-version-pin doctrine the
  `aws-finops` / `azure-finops` / `karpenter-operations` skills follow.
- Keep the **scope boundary** sharp:
  - **Crossplane** (K8s-native, control-plane IaC — XRDs / Compositions / Managed
    Resources) → `../crossplane/`. This skill is the client-side plan/apply
    archetype; Crossplane is the continuously-reconciling controller archetype.
  - **Helm chart authoring / packaging** → `../helm-chart-packages/`. Use the `helm`
    provider only to *install* releases; chart internals live there.
  - **Generic AWS CLI mechanics** (config, credentials, JMESPath, waiters) →
    `../aws-cli/`. This skill *uses* provider auth; it does not own CLI ergonomics.
  - **GitHub Actions CI mechanics** (workflow YAML, runners, OIDC plumbing) →
    `../github-actions/`. This skill owns *what the pipeline must gate*, not the YAML.
  - **Agentic gated-write blast-radius doctrine** → `../../operations/agentic-k8s-ops/`.
- Highest-value facts to keep correct: **apply is always gated** (there is **no** MCP
  server that runs `terraform apply` — apply stays a human-gated CI/PR action);
  **`plan -detailed-exitcode`** codes (0=no-change / 1=error / 2=changes) gate CI and,
  with `-refresh-only`, flag **drift**; **remote state + locking** is mandatory for
  shared infra; **`for_each`** (stable keys) over `count` (index churn); **`moved`**
  refactors avoid destroy+recreate; **`state mv`/`rm`/`push`/`force-unlock`** are
  gated, backup-first, no-undo operations; the **CI gate order** is
  fmt→validate→tflint→tfsec|checkov|trivy→policy-as-code→`terraform test`→gated apply.
- The `description:` uses a `>-` block scalar (colon/backtick-dense) — keep it and
  re-verify `yq --front-matter=extract '.description | type'` is `!!str` after edits.

### Testing Requirements
- **`scripts/validate-skills.sh` validates this directory** (`platform-engineering/`
  is in `DOMAIN_DIRS`): frontmatter (`name`/`description`/`license`/`compatibility`,
  non-empty `metadata` map), non-empty body, even fence count. Run it after edits.
- `tools/` is **not** validator-covered — verify by hand (`bash -n`, the two
  mutating-verb greps, executable bit) per `tools/AGENTS.md`.

### Companion Subagents
- Ships a **5-agent Terraform/OpenTofu IaC team** in `../../.claude/agents/`:
  `terraform-module-author` (Phase A — reusable module design: typed `variable`s +
  `validation` + `output`s + `locals`, composition, module registry + version
  constraints, `for_each`/`count`/`dynamic`, `moved` refactors),
  `terraform-state-operator` (Phase B/F — remote backends S3+DynamoDB/azurerm/gcs/
  TFC-HCP, workspaces, state locking, `import`/`moved`, **gated** `state mv`/`rm`,
  drift via `plan -refresh-only` — owns `tools/tf-state-inventory.sh` +
  `tools/tf-drift-check.sh`), `terraform-provider-config` (Phase C —
  `required_providers` + version constraints, committed `.terraform.lock.hcl`,
  provider auth OIDC/assume-role/workload-identity, provider `alias`),
  `terraform-plan-reviewer` (Phase D — reading `plan` adds/changes/**destroys**,
  policy-as-code OPA/Conftest/Sentinel, `prevent_destroy`/`-target` guard, gated
  apply — owns `tools/tf-plan-summary.sh`), `terraform-iac-tester` (Phase E —
  `validate`/`fmt -check`, tflint, tfsec/checkov/trivy config, native `terraform
  test`/`.tftest.hcl`, terratest, CI-gate wiring). The SKILL's "Subagent
  Orchestration" table maps concern → agent; update both on rename.

### Common Patterns
- Intro + mental model → the IaC-concern × Terraform-surface table → CORE PRINCIPLES
  → CAPABILITY MAP → phases A–F (Modules / State / Providers / Plan-review / Testing
  / Drift) each with one decision tree + one runnable HCL/CLI example → anti-patterns
  → checklist → reference → MCP surface → subagent orchestration. Same authoring
  shape as the sibling `aws-finops` skill.

## Dependencies

### Internal
- `../../scripts/validate-skills.sh` — enforces the SKILL.md contract.
- `../../README.md` — references this skill in the "Platform Engineering" table; rename → README update.
- `../../.claude/agents/terraform-*.md` — the 5 companion subagents.
- `../crossplane/SKILL.md` (K8s-native control-plane IaC), `../helm-chart-packages/SKILL.md`
  (Helm chart authoring), `../aws-cli/SKILL.md` (CLI mechanics),
  `../github-actions/SKILL.md` (CI plumbing),
  `../../operations/agentic-k8s-ops/SKILL.md` (agentic blast-radius) — cross-referenced
  to keep boundaries sharp.

### External
None at runtime — documentation. Describes Terraform / OpenTofu IaC; cites the
Terraform + OpenTofu registries and docs. `tools/` scripts need only `terraform`
(or `tofu`) + POSIX tools, run after a human `terraform init`. No `jq`. No version
pinned.

<!-- MANUAL: -->
