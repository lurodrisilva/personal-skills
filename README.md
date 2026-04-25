# personal-skills

[![Validate Skills](https://github.com/lurodrisilva/personal-skills/actions/workflows/validate-skills.yml/badge.svg)](https://github.com/lurodrisilva/personal-skills/actions/workflows/validate-skills.yml)

A collection of **Claude Code skills** -- comprehensive reference guides that Claude Code loads when working on projects matching specific technology patterns. Each skill encodes architectural rules, coding conventions, and framework-specific guidance for a technology stack.

## Available Skills

### Coding

| Skill | Language / Framework | Architecture | Key Technologies |
|-------|---------------------|--------------|------------------|
| [golang-hex-clean](coding/golang-hex-clean/SKILL.md) | Go | Hexagonal / Clean | GoFiber, go-redis, OpenTelemetry, DDD, CQRS |
| [dotnet-hex-clean](coding/dotnet-hex-clean/SKILL.md) | .NET | Clean Architecture (Ardalis) | FastEndpoints, EF Core, Vogen, Mediator, DDD, CQRS |
| [create-makefiles](coding/create-makefiles/SKILL.md) | Language-agnostic | Unified task-runner | GNU Make best practices, per-language templates (Go, Node, Python, .NET, C/C++) |
| [dockerfile-instructions](coding/dockerfile-instructions/SKILL.md) | Language-agnostic | Container builds | BuildKit, multi-stage builds, size + build-time optimization, multi-arch (buildx, QEMU, TARGETPLATFORM), distroless, non-root |

### Platform Engineering

| Skill | Platform | Focus | Key Technologies |
|-------|----------|-------|------------------|
| [github-actions](platform-engineering/github-actions/SKILL.md) | GitHub Actions | CI/CD governance, supply-chain security | Workflow syntax, OIDC federation, SHA-pinning, script-injection prevention, dependency caching, artifact attestations (SLSA Build L3), Sigstore policy-controller |
| [addons-and-building-blocks](platform-engineering/addons-and-building-blocks/SKILL.md) | Kubernetes / AKS | Layered platform blueprints — baseline addons + reusable building blocks | Helm library charts (`myorg.*` / `plat-net.*`), OCI chart distribution (GHCR), ArgoCD App-of-Apps with sync waves, CloudNativePG, Crossplane managed resources, wrapper-chart helm-unittest, kubeconform, Terraform + Terratest AKS foundation |
| [wiremock-api-mocks](platform-engineering/wiremock-api-mocks/SKILL.md) | Kubernetes (`testing-system` namespace) | Shared, cluster-wide HTTP API mock server — one WireMock instance, many tenants, stubs declared in consumer Helm values | WireMock (Java) Helm addon, `myorg.wiremock.syncJob` library helper, `metadata.owner=<release>` atomic replace via Admin API, URL-prefix isolation `/__mocks__/<release>/`, NetworkPolicy + consumer-namespace label gating, `WireMock.Net` for in-process .NET unit tests |

## How It Works

Skills are SKILL.md files that Claude Code can load into its context to provide domain-specific guidance. When Claude Code detects that a project matches a skill's description, it applies the encoded rules and patterns automatically.

Each skill provides:

- **Architecture rules** -- strict layering and dependency direction enforcement (where applicable)
- **Layer-by-layer implementation patterns** -- with concrete code examples
- **Naming and style conventions** -- idiomatic patterns for the target language or platform
- **Testing strategies** -- unit, integration, and architecture tests (where applicable)
- **Anti-patterns and verification checklists** -- pre-done gates the skill checks before declaring a task complete

## Repository Structure

```
coding/
  <skill-name>/
    SKILL.md          # Skill definition (YAML frontmatter + markdown content)
platform-engineering/
  <skill-name>/
    SKILL.md          # Skill definition (YAML frontmatter + markdown content)
scripts/
  validate-skills.sh  # CI validation script
.github/
  workflows/
    validate-skills.yml  # GitHub Actions workflow
```

Skills are organized by domain:

- `coding/` -- application-development skills (language, framework, or build-tooling guidance)
- `platform-engineering/` -- infrastructure / DevOps / CI-CD / supply-chain skills

## SKILL.md Format

Each skill file uses YAML frontmatter followed by markdown content:

```yaml
---
name: skill-name
description: When and why to load this skill
license: BSD-3-Clause
compatibility: opencode
metadata:
  language: golang
  pattern: hexagonal-clean-architecture
---

# Skill Title

Markdown content with architecture rules, patterns, and code examples.
```

### Required Frontmatter Fields

| Field | Purpose |
|-------|---------|
| `name` | Skill identifier |
| `description` | Describes when to activate the skill (used for auto-detection) |
| `license` | Distribution license |
| `compatibility` | Target platform (e.g., `opencode`) |
| `metadata` | Non-empty map of language/framework/pattern tags |

## Adding a New Skill

1. Pick the right domain directory:
   - `coding/` for application-development skills (language, framework, build tooling)
   - `platform-engineering/` for infrastructure, DevOps, CI/CD, or supply-chain skills
2. Create a subdirectory following the relevant naming convention:
   - `<language>-hex-clean` for hexagonal/clean architecture skills (e.g., `golang-hex-clean`)
   - `<domain>-<purpose>` for platform-engineering skills (e.g., `github-actions`)
   - A descriptive kebab-case name for cross-cutting build tooling (e.g., `create-makefiles`, `dockerfile-instructions`)
3. Add a `SKILL.md` file with valid YAML frontmatter and all required fields
4. Write the markdown body: non-negotiable rules first, then layer-by-layer patterns with code examples, closing with an anti-patterns table and a pre-done verification checklist
5. Run the validation script locally before pushing:

```bash
./scripts/validate-skills.sh
```

### Validation Checks

The CI pipeline runs on every push to `master` and every pull request:

- Every directory under `coding/` must contain a `SKILL.md`
- Frontmatter must be valid YAML with all required fields (`name`, `description`, `license`, `compatibility`, `metadata`)
- `metadata` must be a non-empty map
- Markdown body after frontmatter must be non-empty
- Fenced code blocks must be balanced (even number of ` ``` ` markers)

> **Note:** the current validator (`scripts/validate-skills.sh`) only walks `coding/`. `platform-engineering/` SKILL.md files are not yet validated by CI -- expanding the validator to cover all domain directories is a tracked follow-up.

## License

BSD-3-Clause — see [LICENSE](LICENSE).
