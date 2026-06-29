<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-05-24 | Updated: 2026-05-24 | DEEPINIT: 2026-05-24 -->

# aws-cli

## Purpose
Skill that guides authoring + reviewing **AWS CLI v2** usage — interactive ops, Makefile glue, CI pipelines, EKS bootstraps, S3 sync jobs, CloudFormation deploys, Lambda invocations, IAM/STS surgery. Covers the **command-structure contract** (positional `aws <global-options> <command> <subcommand>`, last-value-wins exclusive parameters), the **two-file config model** (`~/.aws/credentials` vs `~/.aws/config` — `[profilename]` vs `[profile profilename]` syntax, `[default]` in both), the **credential resolution order** (CLI args → env vars → web-identity → SSO → process → shared files → container → IMDSv2), the **environment + global flag surface**, **JMESPath `--query`**, the `file://` vs `fileb://` text-vs-binary split, **pagination** (`--max-items` truncation re-emits `NextToken`, `--page-size` per-call, `--no-paginate`), **waiters** (`aws … wait`) over `sleep` loops, the `aws s3` (high-level) vs `aws s3api` (raw API) split, the SSO / IRSA / OIDC identity surface, retry modes, endpoint overrides, and CI hardening (`--no-cli-pager`, `--output json`).

## Key Files
| File | Description |
|------|-------------|
| `SKILL.md` | Skill definition — `name: aws-cli`, `domain: platform-engineering`, `pattern: aws-cli-usage-and-automation`, `platform: aws`, `stack: aws-cli-v2 + sigv4 + jmespath + odata-shorthand`, `cloud: aws-commercial (also GovCloud + China with --region overrides)` |

## Subdirectories
None.

## For AI Agents

### Working In This Directory
- Edit `SKILL.md` only.
- The 12 non-negotiables at the top are flag-first PR rules. Load-bearers: positional command structure + last-value-wins (#1), credentials-vs-config syntax split (#2), credential resolution order (#3), **no long-lived `aws_access_key_id`** — SSO / IRSA / OIDC instead (#4), JMESPath competency (#5), `--output json` (never parse `text`) (#6), `file://` vs `fileb://` correctness (#7), `--no-cli-pager` in CI (#8), pagination + waiter literacy (#9 + #11), `s3` vs `s3api` split (#10), `--debug` leaks signed headers — never paste publicly (#12).
- Sister-skill cross-references in the description (`addons-and-building-blocks`, `github-actions`, `azure-retail-prices`) — extend the description's trigger list when adding new CI-runner / build-tool / cloud-API integrations.

### Testing Requirements
- **`scripts/validate-skills.sh` validates this directory** (its `DOMAIN_DIRS` includes `platform-engineering/`) — CI runs it on every push and PR. Run it locally before pushing; it checks:
  1. YAML frontmatter parses and contains `name`, `description`, `license`, `compatibility`, non-empty `metadata` map.
  2. Markdown body after the closing `---` is non-empty.
  3. Fenced code-block markers are even in count.
- Every example shell snippet must satisfy the skill's own rules: `--output json` in pipelines, `--no-cli-pager` in CI, OIDC / SSO / IRSA over long-lived keys, JMESPath instead of `grep`/`awk` scraping.

### Common Patterns
- "Non-negotiables encoded in this skill" numbered list — same authoring style as other platform-engineering skills.
- "WHEN TO USE THIS SKILL" matrix opens the body; explicitly excludes `boto3` (Python SDK) and Terraform `aws_*` resources — both have their own skills.
- Exit-code conventions documented in the description (0 success / 1 service error / 2 usage error / 130 user-interrupt / 252 not-found / 253 invalid-arg / 254 unrecognised-resource / 255 unhandled) — keep aligned with AWS CLI v2 upstream when bumping versions.

## Dependencies

### Internal
- `../../README.md` — references this skill in the "Platform Engineering" table.
- `../../scripts/validate-skills.sh` — validates this file (its `DOMAIN_DIRS` includes `platform-engineering/`); CI runs it on every push and PR.
- `../addons-and-building-blocks/SKILL.md` — sibling whose AKS bootstrap pattern is analogous to `aws eks update-kubeconfig`.
- `../github-actions/SKILL.md` — sibling whose OIDC-federation rules align with `aws-actions/configure-aws-credentials@v4`.
- `../azure-retail-prices/SKILL.md` — sibling for analogous public-API discipline on a different cloud.

### External
None at runtime — this is documentation, not code.

<!-- MANUAL: -->
