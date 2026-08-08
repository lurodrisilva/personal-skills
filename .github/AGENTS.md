<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-08-08 | Updated: 2026-08-08 -->

# .github

## Purpose
GitHub platform configuration for the repository. Currently this is **CI only** —
there are no issue templates, PR templates, `CODEOWNERS`, Dependabot config, or
funding files. The single workflow under `workflows/` is the gate that every push to
`master` and every pull request must pass.

## Key Files
None at this level — all content lives in `workflows/`.

## Subdirectories
| Directory | Purpose |
|-----------|---------|
| `workflows/` | GitHub Actions workflows — currently the `validate-skills.sh` CI gate (see `workflows/AGENTS.md`) |

## For AI Agents

### Working In This Directory
- **This repo has exactly one CI gate.** Anything added here changes what blocks a
  merge, so treat additions as a deliberate policy change, not a convenience.
- The repo ships a `github-actions` **skill** at
  `../platform-engineering/github-actions/SKILL.md`. Any workflow authored here should
  obey that skill's own guidance — SHA-pin third-party actions, keep
  `permissions:` least-privilege, never interpolate untrusted input directly into a
  `run:` block. Failing to follow the repo's own published advice inside the repo is a
  visible inconsistency.
- Adding a PR/issue template or `CODEOWNERS` affects human contributor flow; propose
  it rather than adding it silently.

### Testing Requirements
- Workflow changes cannot be fully validated locally. Validate the **script** the
  workflow runs (`./scripts/validate-skills.sh`, exit code = error count), then confirm
  the workflow itself on a PR — the `Validate SKILL.md files` check must pass before merge.
- A YAML syntax error here surfaces only once GitHub parses it, so keep edits small
  and watch the first PR run.

### Common Patterns
- Workflow files are `.yml` (not `.yaml`) — match the existing name style.
- The job name shown in the PR checks UI comes from `jobs.<id>.name`; changing it
  changes what branch-protection rules match on.

## Dependencies

### Internal
- `../scripts/validate-skills.sh` — the script CI executes; the workflow is a thin
  wrapper around it.
- `../platform-engineering/github-actions/SKILL.md` — the repo's own guidance on
  authoring workflows.

### External
- GitHub Actions — `actions/checkout@v4`, `mikefarah/yq@master`.

<!-- MANUAL: -->
