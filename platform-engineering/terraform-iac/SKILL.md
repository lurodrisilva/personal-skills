---
name: terraform-iac
description: >-
  MUST USE when authoring, reviewing, refactoring, testing, or operating
  **Infrastructure as Code with Terraform or OpenTofu** — declarative HCL2 that
  provisions and manages cloud/on-prem infrastructure through a **plan → review →
  gated apply** lifecycle. Covers **module authoring** (input variables +
  `validation` blocks, typed variables, `output`s, `locals`, `for_each` / `count`
  / `dynamic` blocks, `moved` refactors, module composition over copy-paste, the
  public + private **module registry** and semantic version constraints),
  **state & backends** (remote state with locking is mandatory — **S3 +
  DynamoDB**, **azurerm**, **gcs**, **Terraform Cloud / HCP** — workspaces,
  `terraform import` / `import` blocks, `terraform state list`, and the SAFETY of
  `state mv` / `state rm` as gated operations), **providers & auth**
  (`required_providers` version constraints, the committed `.terraform.lock.hcl`,
  short-lived least-privilege auth via **OIDC / assume-role / workload identity**
  — never long-lived static keys, provider `alias` for multi-region/multi-account),
  **plan review & policy-as-code** (reading `terraform plan` adds/changes/**destroys**,
  `-detailed-exitcode`, `prevent_destroy`, `-target` discipline, **OPA / Conftest /
  Sentinel** gates, the PR-gated apply), **testing** (native `terraform test` with
  `.tftest.hcl`, **terratest**, `terraform validate` / `fmt -check`, **tflint**,
  **tfsec** / **checkov** / **trivy config** as CI gates), and **drift & day-2**
  (`terraform plan -refresh-only` to detect drift, reconcile through Git not console
  clicks, provider/module upgrades, guarded `destroy`). Triggers on phrases —
  "terraform", "opentofu", "tofu", "infrastructure as code", "iac", "hcl",
  "terraform module", "terraform state", "remote state", "state backend", "s3
  backend", "dynamodb lock", "terraform cloud", "hcp terraform", "terraform
  workspace", "terraform import", "moved block", "required_providers", "provider
  version constraint", ".terraform.lock.hcl", "lock file", "terraform oidc",
  "assume role terraform", "workload identity terraform", "terraform plan",
  "terraform apply", "gated apply", "terraform destroy", "prevent_destroy",
  "-target", "policy as code", "opa terraform", "conftest", "sentinel", "terraform
  validate", "terraform fmt", "tflint", "tfsec", "checkov", "trivy config",
  "terraform test", "tftest", "terratest", "drift detection", "refresh-only",
  "terraform ci", "terraform pipeline". Triggers on surfaces — `*.tf` / `*.tfvars`
  / `*.tftest.hcl` files, `terraform { backend "s3" {} }` / `backend "azurerm"` /
  `backend "gcs"` blocks, `required_providers` / `required_version`,
  `.terraform.lock.hcl`, `terraform plan -detailed-exitcode`, `terraform plan
  -refresh-only`, `terraform state list`, `moved { }` / `import { }` blocks,
  `run "…" { }` test blocks. Scope boundary — **Crossplane** (Kubernetes-native
  control-plane IaC, XRDs/Compositions/Managed Resources) → `../crossplane/`;
  **Helm chart authoring / packaging** → `../helm-chart-packages/`; **generic AWS
  CLI mechanics** (config, credentials, JMESPath, waiters) → `../aws-cli/`;
  **GitHub Actions CI mechanics** (workflow YAML, runners, OIDC to the provider) →
  `../github-actions/`. This skill owns the **Terraform / OpenTofu HCL + state +
  plan/apply lifecycle**. Authored as an IaC practitioner's playbook — plan before
  apply, remote state with locking, least-privilege short-lived auth, pin by
  lockfile, every apply is a gated human-reviewed change. **Terraform, OpenTofu,
  providers, and the policy tooling evolve quickly: state behavior, pin no tool /
  provider version in prose, and verify version constraints, resource arguments,
  and subcommands against the Terraform / OpenTofu registry and docs before
  relying on them.**
license: BSD-3-Clause
compatibility: opencode
metadata:
  domain: platform-engineering
  tool: terraform
  also: opentofu
  discipline: infrastructure-as-code
  language: hcl2
  surfaces: modules, state-backends, providers, plan-review, policy-as-code, testing
  pattern: declarative-iac
  use_cases: module-authoring, state-management, drift-detection, gated-apply, iac-testing
---

# Terraform / OpenTofu IaC

You are an **Infrastructure-as-Code practitioner** running Terraform (or its
open-source sibling **OpenTofu / `tofu`**) as the declarative control surface for
cloud and on-prem infrastructure. IaC is a **discipline**, not a command: you
describe desired state in **HCL2**, Terraform computes the diff against recorded
**state**, and every mutation flows through a **plan → human review → gated apply**
lifecycle recorded in Git. **The goal is not "run `apply` fast" — it is a
reproducible, reviewable, least-privilege change process** where the plan is the
contract and nobody clicks in a console.

**The mental model.** Terraform reconciles three things — your **config** (HCL,
desired), the **state** (what it last recorded), and the **real world** (what the
provider reports). `plan` is the diff; `apply` is the gated write:

```
   CONFIG (HCL, desired) ──┐
                           ├──►  terraform plan  ──►  human review  ──►  apply (GATED)
   STATE (recorded) ───────┤        (the diff)         (the gate)        (the write)
                           │            ▲
   REAL WORLD (provider) ──┘            └── refresh / -refresh-only detects DRIFT
```

**The IaC lifecycle** maps to phases, each with its Terraform/OpenTofu surface:

| IaC concern | What it decides | Terraform / OpenTofu surface |
|---|---|---|
| **Modules & composition** | reusable, versioned units of infra | `variable` + `validation` · `output` · `locals` · `for_each`/`count`/`dynamic` · `moved` · module registry + version constraints |
| **State & backends** | where state lives, who can lock it | `backend "s3"`+DynamoDB / `azurerm` / `gcs` / Terraform Cloud · `workspace` · `import` · `state list` · `moved` |
| **Providers & auth** | which provider version, how it authenticates | `required_providers` version constraints · `.terraform.lock.hcl` · OIDC / assume-role / workload identity · provider `alias` |
| **Plan review & policy** | is this diff safe to apply | `plan -detailed-exitcode` · adds/changes/**destroys** · `prevent_destroy` · `-target` · OPA/Conftest/Sentinel · PR gate |
| **Testing** | does the module do what it claims | `validate` · `fmt -check` · `tflint` · `tfsec`/`checkov`/`trivy` · `terraform test` (`.tftest.hcl`) · terratest |
| **Drift & day-2** | has reality diverged from state | `plan -refresh-only` · reconcile via Git · provider/module upgrades · guarded `destroy` |

> **Scope boundary.**
> - **Crossplane** (Kubernetes-native, control-plane IaC — XRDs / Compositions /
>   Managed Resources reconciled in-cluster) → `../crossplane/`. This skill is the
>   **client-side, plan/apply** archetype; Crossplane is the **continuously
>   reconciling controller** archetype.
> - **Helm chart authoring / packaging** (templating Kubernetes manifests, chart
>   dependencies, OCI push) → `../helm-chart-packages/`. Use the `helm` provider
>   from Terraform only to *install* releases; chart internals live there.
> - **Generic AWS CLI mechanics** (config, credential resolution, JMESPath
>   `--query`, waiters, SSO) → `../aws-cli/`. Terraform *uses* provider auth; it
>   does not own CLI ergonomics.
> - **GitHub Actions CI mechanics** (workflow YAML, runners, wiring OIDC to the
>   cloud) → `../github-actions/`. This skill owns *what the pipeline must gate*
>   (fmt/validate/lint/scan/policy/plan → gated apply), not the YAML plumbing.
> This skill owns the **Terraform / OpenTofu HCL, state, and plan/apply lifecycle.**

> **Version gate (read first).** Terraform, **OpenTofu**, every provider, and the
> policy/scanning tools all move quickly. **State behavior, pin no tool or provider
> version number in prose, and verify version constraints, resource/argument names,
> backend options, and subcommands against the Terraform / OpenTofu registry and
> docs before relying on them.** The **one** correct place to pin is machine-checked
> config — `required_providers` constraints resolved into a committed
> `.terraform.lock.hcl` — not example prose.

---

## CORE PRINCIPLES (NON-NEGOTIABLE)

1. **Plan before apply — always.** `apply` is a **gated, human-reviewed change**,
   never a blind mutation. Generate a plan, **read** it (adds / changes /
   **destroys**), and apply a **saved** plan through a pipeline or PR gate. Treat a
   plan showing an unexpected `destroy` or replacement as a stop-the-line event
   until explained. Never `apply -auto-approve` interactively against shared infra.
2. **Remote state with locking is mandatory.** Shared infrastructure uses a remote
   backend with state locking — **S3 + DynamoDB**, **azurerm**, **gcs**, or
   **Terraform Cloud / HCP**. **Never local state for shared infra** (no lock → two
   applies corrupt state; no durability → a laptop loss loses the record). State
   holds secrets — encrypt at rest and lock down access.
3. **Least-privilege, short-lived provider auth.** Authenticate via **OIDC**,
   **assume-role**, or **workload identity** — short-lived, scoped credentials.
   **Never long-lived static access keys** in code, tfvars, env files, or CI
   secrets when a federated option exists. CI authenticates by exchanging an OIDC
   token for a role; humans use SSO.
4. **Pin providers and modules — via the lockfile.** Declare `required_providers`
   with version constraints, resolve them into a **committed `.terraform.lock.hcl`**
   (with multi-platform hashes), and pin module sources to a semantic version. The
   lockfile is the reproducibility contract — commit it. *(This is the ONE place
   version pinning is correct; do not hard-pin tool/provider versions in prose
   examples — say "pin to a known-good version, verified against the registry".)*
5. **Compose modules; do not copy-paste.** A reusable module with typed,
   `validation`-checked inputs and explicit outputs beats duplicated resource
   blocks. Root configs *compose* versioned modules; shared logic lives in one
   module, consumed by version.
6. **`validate` / `fmt` / `tflint` / `tfsec`|`checkov` + policy-as-code are CI
   gates.** `terraform fmt -check`, `terraform validate`, **tflint**, a security
   scanner (**tfsec** / **checkov** / **trivy config**), and **policy-as-code**
   (**OPA/Conftest** or **Sentinel**) run in CI and **block merge** on failure —
   they are gates, not advisory output.
7. **Drift is detected and reconciled through Git.** Detect drift with `terraform
   plan -refresh-only`; reconcile it by **updating HCL and re-applying via a PR** —
   **never** by clicking in the cloud console. Console changes create the drift you
   are fighting.
8. **`destroy` is guarded.** Protect stateful/critical resources with
   `prevent_destroy`, scope narrow blast radius with `-target` **discipline** (a
   surgical escape hatch, not a habit), and **review every plan for destroys /
   replacements** before applying. A `destroy` against prod is a gated, deliberate,
   double-checked action.

---

## CAPABILITY MAP — goal / signal → concern → phase → agent

| Goal or signal | IaC concern | Phase | Agent |
|---|---|---|---|
| "Make this reusable" / duplicated resource blocks | Module authoring | A | `terraform-module-author` |
| Typed inputs, validation, outputs, `for_each` | Module authoring | A | `terraform-module-author` |
| Refactor without recreate (renamed resource) | `moved` blocks | A | `terraform-module-author` |
| "Where does state live?" / local state on shared infra | State & backends | B | `terraform-state-operator` |
| State locking, workspaces, `import` existing infra | State & backends | B | `terraform-state-operator` |
| Detect drift between real infra and state | Drift (refresh-only) | B / F | `terraform-state-operator` |
| Which provider version / how does CI auth | Providers & auth | C | `terraform-provider-config` |
| OIDC / assume-role / workload identity, no static keys | Providers & auth | C | `terraform-provider-config` |
| `required_providers` + `.terraform.lock.hcl` | Providers & auth | C | `terraform-provider-config` |
| "Is this plan safe?" / plan shows destroys | Plan review | D | `terraform-plan-reviewer` |
| Policy gate (deny public S3, require tags) | Policy-as-code | D | `terraform-plan-reviewer` |
| `prevent_destroy` / `-target` / gated apply | Destroy guard | D | `terraform-plan-reviewer` |
| "Does this module work?" / no tests | Testing | E | `terraform-iac-tester` |
| `terraform test` / terratest / scanner in CI | Testing gate | E | `terraform-iac-tester` |
| Provider/module upgrade, state surgery reasoning | Day-2 | F | `terraform-state-operator` |

---

## PHASE A — Modules & composition

**Goal:** reusable, versioned, typed units of infrastructure — not copy-pasted
resource blocks.

**Decision tree — should this be a module?**

```
Is the same set of resources used in >1 place, or worth versioning independently?
├── no  → keep it inline in the root config; extract later if it repeats
└── yes → author a module:
          ├── typed `variable`s with `validation` + sensible defaults + `description`
          ├── explicit `output`s (only what consumers need)
          ├── `locals` for computed/derived values (not inputs)
          ├── many similar instances?  → `for_each` (stable keys) over `count` (index churn)
          ├── optional nested blocks?   → `dynamic` block over a variable list
          └── source it by SEMANTIC VERSION; refactor renames with `moved` (no recreate)
```

**Example — a small module with validated input, `for_each`, and `moved`:**

```hcl
# modules/bucket/variables.tf
variable "names" {
  type        = set(string)
  description = "Bucket base names; each becomes one bucket."
  validation {
    condition     = alltrue([for n in var.names : can(regex("^[a-z0-9-]{3,40}$", n))])
    error_message = "Names must be lower-case DNS-safe, 3-40 chars."
  }
}

variable "versioning" {
  type    = bool
  default = true
}

# modules/bucket/main.tf — for_each keeps a stable address per name (not count index)
resource "aws_s3_bucket" "this" {
  for_each = var.names
  bucket   = each.value
}

resource "aws_s3_bucket_versioning" "this" {
  for_each = var.versioning ? aws_s3_bucket.this : {}
  bucket   = each.value.id
  versioning_configuration { status = "Enabled" }
}

# Refactor safely: renamed the resource? tell Terraform it MOVED (no destroy+create).
moved {
  from = aws_s3_bucket.bucket
  to   = aws_s3_bucket.this
}

# modules/bucket/outputs.tf
output "bucket_ids" {
  value = { for k, b in aws_s3_bucket.this : k => b.id }
}
```

```hcl
# root: compose the module BY VERSION — registry ref pinned to a known-good tag
module "app_buckets" {
  source  = "app.terraform.io/acme/bucket/aws"   # or a git ref / registry path
  version = "~> 1.4"   # pin to a known-good version; verify latest on the registry
  names   = ["acme-logs", "acme-artifacts"]
}
```

> `for_each` addresses resources by a **stable key** — reordering the list won't
> destroy/recreate resources the way a shifting `count` index does. Prefer it for
> sets/maps. Reach for `count` only for a simple 0/1 toggle or an ordered list.

---

## PHASE B — State & backends

**Goal:** state lives in a **remote, locked, encrypted** backend; imports and
refactors are deliberate; drift is visible.

**Decision tree — backend & state operations:**

```
Shared infra (a team, CI, prod)?
├── yes → REMOTE backend with locking (mandatory):
│         ├── AWS   → S3 (versioned, encrypted) + DynamoDB lock table
│         ├── Azure → azurerm (storage account + container, blob lease lock)
│         ├── GCP   → gcs (bucket, object-generation lock)
│         └── SaaS  → Terraform Cloud / HCP (remote state + runs + locking)
└── no (throwaway local experiment) → local state is tolerable, never for shared infra

Bringing existing (console-created) infra under management?
└── `import` block (config-driven, plannable) — preferred — or `terraform import <addr> <id>`

Renamed/moved a resource or module?          → `moved` block (no destroy+create)
Reshaping state itself (split/merge/rename)?  → `state mv` / `state rm` are GATED,
                                                 back up state first, never routine
```

**Example — S3 + DynamoDB backend, workspaces, config-driven import, refresh-only drift:**

```hcl
# backend.tf — remote state with locking (S3 + DynamoDB). Values are backend-only;
# run `terraform init` (human step) to configure — a tool does NOT init a new backend.
terraform {
  backend "s3" {
    bucket         = "acme-tfstate"
    key            = "prod/network/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "acme-tf-locks"   # state locking — REQUIRED for shared infra
    encrypt        = true              # SSE at rest; state can contain secrets
  }
}

# Config-driven import — plannable, reviewable (preferred over the imperative CLI):
import {
  to = aws_s3_bucket.legacy
  id = "acme-legacy-bucket"
}
```

```bash
# READ-ONLY state & drift inspection (never mutates state):
terraform workspace list                     # which workspaces exist (* = current)
terraform state list                          # every managed address
terraform plan -refresh-only -detailed-exitcode -no-color   # exit 2 == DRIFT detected
# GATED, deliberate, backup-first (NOT routine — reasoned, then run by a human):
#   terraform state mv <src> <dst>            # re-address within state
#   terraform state rm <addr>                 # forget without destroying the resource
```

> `state mv` / `state rm` / `state push` / `force-unlock` rewrite the source of
> truth with **no plan and no undo**. Back up state (`terraform state pull >
> backup.tfstate`), reason about the exact effect, and run them as a gated,
> logged operation — never as a reflex to "fix" a plan.

---

## PHASE C — Providers & auth

**Goal:** every provider is version-constrained + lock-pinned, and authenticates
with **short-lived, least-privilege** credentials — never long-lived static keys.

**Decision tree — provider auth:**

```
Where does Terraform run?
├── CI/CD pipeline → OIDC: CI mints a short-lived OIDC token, exchanges it for a
│                   scoped cloud role (AWS AssumeRoleWithWebIdentity / Azure
│                   workload-identity federation / GCP Workload Identity Federation).
│                   NO static keys in secrets.
├── Human, local  → SSO / federated login (aws sso, az login, gcloud auth) — short-lived.
└── Long-lived static access key in code/tfvars/env?  → NO. Remove it; federate instead.

Multiple regions/accounts/subscriptions in one config?  → provider `alias` + `provider =`
```

**Example — version constraints, lockfile, OIDC role assumption, provider alias:**

```hcl
# versions.tf — constrain the provider; the LOCKFILE pins the exact resolved version.
terraform {
  required_version = ">= <known-good>"     # verify a supported floor on the registry
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> <known-good-major.minor>"   # pin to a verified line; lockfile pins exact
    }
  }
}

# Provider auth via assumed role — NO static keys. CI supplies short-lived OIDC creds
# (AssumeRoleWithWebIdentity) out-of-band; this just names the role to assume.
provider "aws" {
  region = "us-east-1"
  assume_role { role_arn = "arn:aws:iam::123456789012:role/terraform-ci" }
}

# Second region via an ALIAS — reference with `provider = aws.euw1` on a resource/module.
provider "aws" {
  alias  = "euw1"
  region = "eu-west-1"
  assume_role { role_arn = "arn:aws:iam::123456789012:role/terraform-ci" }
}
```

```bash
# Resolve constraints into a COMMITTED, multi-platform lockfile (run by a human on init):
terraform providers lock -platform=linux_amd64 -platform=darwin_arm64
git add .terraform.lock.hcl        # the reproducibility contract — commit it
terraform providers               # READ-ONLY: show the provider dependency tree
```

> OpenTofu reads the same `required_providers` / `.terraform.lock.hcl` and (from
> the OpenTofu registry) the same providers. Keep the lockfile committed for both.
> Never commit a static access key; if you find one, treat it as a leaked secret.

---

## PHASE D — Plan review & policy-as-code (the gated apply)

**Goal:** no diff reaches infrastructure without being **read**, **policy-checked**,
and **applied through a gate**.

**Decision tree — is this plan safe to apply?**

```
Run `terraform plan -detailed-exitcode -out plan.bin`  (exit: 0=no-change, 1=error, 2=changes)
├── exit 1 → error; fix config, do not proceed
├── exit 0 → nothing to do; done
└── exit 2 → READ the plan:
             ├── any `destroy` / `-/+ replace` on a stateful/prod resource?
             │      → STOP. Explain why. `prevent_destroy` should have caught it.
             ├── policy-as-code gate (OPA/Conftest on `plan -json`, or Sentinel) → must PASS
             ├── blast radius too broad?  → scope with `-target` (surgical, documented)
             └── all clear → apply the SAVED plan through the PR/pipeline gate (human approves)
```

**Example — save a plan, machine-read it, gate it with Conftest/OPA, `prevent_destroy`:**

```hcl
# Guard stateful resources so a stray plan can't destroy them:
resource "aws_db_instance" "prod" {
  # ...
  lifecycle { prevent_destroy = true }
}
```

```bash
# 1) Produce and READ a saved plan (read-only until the gated apply step):
terraform plan -detailed-exitcode -out plan.bin        # exit 2 == changes present
terraform show -json plan.bin > plan.json              # machine-readable diff

# 2) Policy-as-code gate — deny the merge if a rule fails (OPA/Conftest example):
conftest test plan.json --policy policy/               # e.g. no public S3, tags required
#    (Terraform Cloud/Enterprise users gate with Sentinel instead.)

# 3) GATED apply — only the reviewed, saved plan; a human/PR approves this step:
terraform apply plan.bin        # applies exactly what was reviewed — no re-plan surprise
```

> The saved plan (`-out`) is the contract: `apply plan.bin` executes **exactly**
> what review saw — no drift between "what I reviewed" and "what ran". Never
> `apply -auto-approve` on shared infra; the approval *is* the gate.

---

## PHASE E — Testing & the CI gate

**Goal:** modules are validated, linted, security-scanned, and behavior-tested —
in CI, blocking merge.

**Decision tree — what test for what?**

```
What are you checking?
├── Formatting / syntax / internal consistency → `terraform fmt -check` + `terraform validate`
├── Lint (deprecations, provider best-practice, naming) → `tflint`
├── Security / misconfig (public buckets, open SGs)     → `tfsec` | `checkov` | `trivy config`
├── Module behavior WITHOUT real infra (assertions on plan) → `terraform test` (`.tftest.hcl`, command = plan)
├── Module behavior WITH real ephemeral infra (apply+verify+destroy) → `terraform test` (command = apply) or terratest (Go)
└── Wire ALL of the above into CI as a MERGE-BLOCKING gate before any apply
```

**Example — native `terraform test` (`.tftest.hcl`) + the CI gate order:**

```hcl
# tests/bucket.tftest.hcl — native testing; `plan` runs are fast and need no real infra.
run "names_are_validated" {
  command = plan
  variables { names = ["acme-logs"] }
  assert {
    condition     = length(aws_s3_bucket.this) == 1
    error_message = "Expected exactly one bucket for a single name."
  }
}

run "rejects_bad_name" {
  command         = plan
  variables       { names = ["Bad_Name"] }   # violates the validation regex
  expect_failures = [var.names]
}
```

```bash
# CI gate — each step BLOCKS merge; run before the gated apply job:
terraform fmt -check -recursive          # style (no writes)
terraform init -backend=false            # init modules/providers WITHOUT touching backend
terraform validate                       # config is internally consistent
tflint                                   # lint + provider best-practice
tfsec .        || checkov -d .           # security/misconfig scan (pick one, or trivy config)
terraform test                           # native .tftest.hcl behavior tests
# terratest (Go) for full apply→verify→destroy integration when ephemeral infra is warranted.
```

> `terraform test` with `command = plan` gives fast, infra-free assertions; use
> `command = apply` (or terratest) only when you need to stand up real ephemeral
> infra and verify it, tearing it down after. OpenTofu ships the same `tofu test`.

---

## PHASE F — Drift & day-2

**Goal:** reality is reconciled to code through Git; upgrades and state surgery are
deliberate, gated operations.

- **Drift detection:** run `terraform plan -refresh-only` on a schedule; exit code
  `2` means state no longer matches the real world. **Reconcile by updating HCL and
  re-applying via a PR** — never by editing in the console (that *is* the drift).
- **Provider / module upgrades:** bump the constraint, run `terraform init
  -upgrade`, **re-run `terraform providers lock` for all platforms**, re-plan, and
  review the diff. Read provider upgrade notes; a major bump can force replacements.
- **State-op reasoning (gated):** `state mv` (re-address after a refactor `moved`
  can't express), `state rm` (stop managing without destroying), `import` (adopt
  existing infra) — each is reasoned, backup-first, and logged. `state rm` +
  re-`import` is the safe pattern to re-home a resource across configurations.
- **Guarded `destroy`:** `prevent_destroy` on the resource, `-target` to scope a
  partial teardown, and **plan-review the destroy** before running it. Tear down
  ephemeral/preprod freely; prod destroys are a deliberate, double-checked change.

```bash
# Scheduled drift check (read-only; surfaces console changes as a diff to reconcile):
terraform plan -refresh-only -detailed-exitcode -no-color   # exit 2 == drift; open a PR to reconcile
```

---

## ANTI-PATTERNS (each one bites)

| Anti-pattern | Why it breaks | Do instead |
|---|---|---|
| `terraform apply -auto-approve` on shared infra | applies an unread diff; a stray destroy ships silently | save a plan, read it, apply the saved plan through a PR/pipeline gate |
| Local state for a shared/team/prod config | no lock (concurrent applies corrupt it); no durability | remote backend with locking (S3+DynamoDB / azurerm / gcs / TFC) |
| Long-lived static access keys in code / tfvars / CI secrets | leaked, long-blast-radius credentials | OIDC / assume-role / workload identity — short-lived, scoped |
| No `.terraform.lock.hcl` committed | non-reproducible provider versions across machines/CI | commit the lockfile; `terraform providers lock` for all platforms |
| Hard-pinning tool/provider versions in copied prose | rots instantly; misleads readers | pin in the lockfile; say "verify a known-good version on the registry" |
| Copy-pasting resource blocks across configs | drift between copies; fixes miss some | author one versioned module; compose it |
| Fixing drift by clicking in the console | recreates the drift you're detecting | update HCL, re-apply via PR; console is read-only for managed infra |
| `count` for a set of named things | index shift destroys/recreates the wrong resources | `for_each` with stable keys |
| `state mv` / `state rm` as a reflex to "fix" a plan | rewrites the source of truth with no plan, no undo | reason first, back up state, run as a gated logged op |
| Skipping `validate`/lint/scan/policy in CI | misconfigs + policy violations reach apply | fmt/validate/tflint/tfsec+checkov/OPA as merge-blocking gates |
| No `prevent_destroy` on stateful resources | a bad plan drops a prod DB | `prevent_destroy` + review every plan for destroys/replaces |
| Committing to infra before testing the module | broken module ships everywhere it's consumed | `terraform test` / terratest before publishing a module version |

---

## PRE-DONE VERIFICATION CHECKLIST

**Modules**
- [ ] Reusable logic is a **versioned module** with typed `variable`s + `validation` + explicit `output`s; root configs compose it.
- [ ] `for_each` (stable keys) over `count` for named sets; renames expressed with `moved` (no recreate).

**State & auth**
- [ ] **Remote backend with locking** for all shared infra (S3+DynamoDB / azurerm / gcs / TFC) — no local state.
- [ ] Auth is **OIDC / assume-role / workload identity** — no long-lived static keys anywhere.
- [ ] `required_providers` constraints resolved into a **committed `.terraform.lock.hcl`** (multi-platform hashes).

**Plan / policy / test**
- [ ] Apply runs a **saved, reviewed plan** through a PR/pipeline gate; no `-auto-approve` on shared infra.
- [ ] Plan **read for destroys/replacements**; stateful resources carry `prevent_destroy`.
- [ ] CI gate blocks merge: `fmt -check` + `validate` + `tflint` + `tfsec`|`checkov`|`trivy` + **policy-as-code** (OPA/Conftest/Sentinel) + `terraform test`.

**Day-2**
- [ ] Drift checked via `plan -refresh-only`; reconciled through Git, not console clicks.
- [ ] Upgrades re-lock all platforms and re-plan; `state mv`/`rm`/`import` are gated, backup-first.

**Doctrine**
- [ ] No tool/provider version pinned in prose; behavior verified against the Terraform/OpenTofu registry + docs.
- [ ] Every apply and every destroy is a gated, reversible-where-possible, human-approved change.

---

## REFERENCE

### `terraform plan -detailed-exitcode`
`0` = success, **no** changes · `1` = **error** · `2` = success, **changes present**.
Use `2` to gate CI ("changes need review/apply") and, with `-refresh-only`, to flag
**drift**. OpenTofu mirrors these codes.

### State-op safety ladder (least → most dangerous)
`state list` / `state show` (read) · `plan -refresh-only` (read, detects drift) ·
`import` / `moved` (additive, plannable) · **`state mv` / `state rm`** (rewrites state,
gated, backup-first) · **`state push` / `force-unlock`** (last-resort, break-glass).
Back up with `terraform state pull > backup.tfstate` before any write.

### CI gate order (fail fast, block merge)
`fmt -check` → `init -backend=false` → `validate` → `tflint` → `tfsec`|`checkov`|`trivy
config` → **policy-as-code** (OPA/Conftest or Sentinel on `plan -json`) → `terraform
test` → **gated apply** (saved plan, human approve). Terraform *and* OpenTofu.

### Backend + lock map (one line)
**S3 + DynamoDB** (AWS: versioned/encrypted bucket + lock table) · **azurerm** (blob
lease) · **gcs** (object generation) · **Terraform Cloud / HCP** (remote runs +
state + locking). Never local for shared infra.

### Read-only triage scripts (`tools/`)
`tf-plan-summary.sh` (`validate` + `plan -detailed-exitcode`, summarize
add/change/destroy — plan does not apply) · `tf-state-inventory.sh` (`version` /
`providers` / `workspace list` / `state list` / optional `output` — no mutation) ·
`tf-drift-check.sh` (`plan -refresh-only -detailed-exitcode` — surface drift, no
write).

---

## MCP SURFACE (read-only)

There is **no guardrailed MCP server that runs `terraform apply`** — and you should
not wire a fabricated one. **Apply stays a human-gated CI/PR action.** The available,
real servers are **read-only lookups** and the **PR gate**:

| Server | Use | Guardrail |
|---|---|---|
| **`terraform-mcp-server`** (HashiCorp) | **Registry docs lookup only** — search/read **modules + providers + their documentation** from the public Terraform Registry. Answers "what arguments does this resource take / which module / what version". | Read-only against the public registry. It is a **docs/registry** tool — it does **not** run `plan` or `apply`. |
| **GitHub MCP server** (`--toolsets`, read-only default) | Drive the **PR-gated apply flow** — open/read the PR that carries the reviewed plan; the merge is the approval gate. | Read-only toolsets by default; scoped token; the PR *is* the human gate. |

Default-deny writes. **Reading the registry, summarizing a plan, and inspecting
state are read-only; `apply`, `destroy`, and `state mv`/`rm`/`push` are gated,
human-approved changes** run in CI/PR — never an autonomous agent mutation. This
mirrors the **read-mostly / gated-write blast-radius doctrine** in
`../../operations/agentic-k8s-ops/`: analyze freely, put a human on every write.

---

## SUBAGENT ORCHESTRATION

This skill drives a **5-agent Terraform/OpenTofu IaC team** in `.claude/agents/`:

| Agent | Owns |
|---|---|
| `terraform-module-author` | Phase A — reusable module design (typed `variable`s + `validation` + `output`s + `locals`), composition, module registry + version constraints, `for_each`/`count`/`dynamic`, `moved` refactors |
| `terraform-state-operator` | Phase B/F — remote backends (S3+DynamoDB / azurerm / gcs / TFC-HCP), workspaces, state locking, `import`/`moved` reasoning, **gated** `state mv`/`rm`, drift via `plan -refresh-only`; owns `tf-state-inventory.sh` + `tf-drift-check.sh` |
| `terraform-provider-config` | Phase C — `required_providers` + version constraints, committed `.terraform.lock.hcl`, provider auth (OIDC / assume-role / workload identity — never long-lived keys), provider `alias`, OIDC-in-CI |
| `terraform-plan-reviewer` | Phase D — reading `plan` (adds/changes/**destroys**), review discipline, policy-as-code (OPA/Conftest/Sentinel), `prevent_destroy` + `-target` guard, the gated apply; owns `tf-plan-summary.sh` |
| `terraform-iac-tester` | Phase E — `validate` / `fmt -check`, `tflint`, `tfsec`/`checkov`/`trivy config`, native `terraform test` (`.tftest.hcl`), terratest, CI-gate wiring |

**Handoffs:** Crossplane (K8s-native control-plane IaC) → `../crossplane/`; Helm
chart authoring/packaging → `../helm-chart-packages/`; generic AWS CLI mechanics →
`../aws-cli/`; GitHub Actions CI plumbing → `../github-actions/`; agentic gated-write
blast-radius doctrine → `../../operations/agentic-k8s-ops/`.
