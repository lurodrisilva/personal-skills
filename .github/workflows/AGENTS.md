<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-08-08 | Updated: 2026-08-08 -->

# workflows

## Purpose
GitHub Actions workflows for the repository. There is exactly one: the **skill
validation gate**. It runs `scripts/validate-skills.sh` on every push to `master` and
on every pull request, and it is the only automated check standing between a malformed
`SKILL.md` and `master`.

## Key Files
| File | Description |
|------|-------------|
| `validate-skills.yml` | `name: Validate Skills`; triggers on `push` to `master` and all `pull_request`s. Job `validate` (`name: Validate SKILL.md files`) on `ubuntu-latest`: checkout → install `yq` → run `./scripts/validate-skills.sh`. Declares `permissions: contents: read` |

## Subdirectories
None.

## For AI Agents

### Working In This Directory
- **The workflow is deliberately a thin wrapper.** All validation logic lives in
  `../../scripts/validate-skills.sh` so it runs identically locally and in CI. Put new
  checks in the **script**, not in workflow steps — a check that only exists in CI
  can't be run before pushing.
- `permissions: contents: read` is intentional least-privilege. This workflow only
  reads the repo; it needs nothing else. **Do not broaden it** without a concrete
  requirement.
- The job name `Validate SKILL.md files` is what appears in the PR checks UI and what
  any branch-protection rule matches on. Renaming it can silently detach a required
  check.
- `mikefarah/yq@master` is **not SHA-pinned** — a deviation from the repo's own
  `github-actions` skill guidance, tolerated here because the workflow has read-only
  permissions and no secrets. If this workflow ever gains write permissions or secret
  access, pin it to a SHA first.
- `pull_request` has no branch filter, so the gate runs for PRs targeting any branch;
  `push` is scoped to `master` only.

### Testing Requirements
- Run `./scripts/validate-skills.sh` locally first — it is the same command CI runs.
  Exit code = number of errors; `0` means all checks passed.
- The workflow needs `yq` (Mike Farah's Go implementation). Locally, install the same
  binary so local and CI results agree.
- After changing this file, confirm the run on the PR (`gh pr checks <n> --watch`)
  before merging.

### Common Patterns
- Steps are named in imperative form ("Checkout repository", "Install yq", "Run skill
  validation").
- The script is invoked by path (`./scripts/validate-skills.sh`), relying on its
  executable bit — keep that bit set when editing the script.

## Dependencies

### Internal
- `../../scripts/validate-skills.sh` — the validation logic; its `DOMAIN_DIRS` array
  determines which domains CI actually walks.

### External
- `actions/checkout@v4` — repository checkout.
- `mikefarah/yq@master` — YAML frontmatter parsing used by the validator.

<!-- MANUAL: -->
