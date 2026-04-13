# personal-skills

[![Validate Skills](https://github.com/lurodrisilva/personal-skills/actions/workflows/validate-skills.yml/badge.svg)](https://github.com/lurodrisilva/personal-skills/actions/workflows/validate-skills.yml)

A collection of **Claude Code skills** -- comprehensive reference guides that Claude Code loads when working on projects matching specific technology patterns. Each skill encodes architectural rules, coding conventions, and framework-specific guidance for a technology stack.

## Available Skills

| Skill | Language / Framework | Architecture | Key Technologies |
|-------|---------------------|--------------|------------------|
| [golang-hex-clean](coding/golang-hex-clean/SKILL.md) | Go | Hexagonal / Clean | GoFiber, go-redis, OpenTelemetry, DDD, CQRS |
| [dotnet-hex-clean](coding/dotnet-hex-clean/SKILL.md) | .NET | Clean Architecture (Ardalis) | FastEndpoints, EF Core, Vogen, Mediator, DDD, CQRS |

## How It Works

Skills are SKILL.md files that Claude Code can load into its context to provide domain-specific guidance. When Claude Code detects that a project matches a skill's description, it applies the encoded rules and patterns automatically.

Each skill provides:

- **Architecture rules** -- strict layering and dependency direction enforcement
- **Layer-by-layer implementation patterns** -- with concrete code examples
- **Naming and style conventions** -- idiomatic patterns for the target language
- **Testing strategies** -- unit, integration, and architecture tests

## Repository Structure

```
coding/
  <skill-name>/
    SKILL.md          # Skill definition (YAML frontmatter + markdown content)
scripts/
  validate-skills.sh  # CI validation script
.github/
  workflows/
    validate-skills.yml  # GitHub Actions workflow
```

## SKILL.md Format

Each skill file uses YAML frontmatter followed by markdown content:

```yaml
---
name: skill-name
description: When and why to load this skill
license: MIT
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

1. Create a directory under `coding/` following the `<language>-hex-clean` naming pattern (for hexagonal/clean architecture skills)
2. Add a `SKILL.md` file with valid YAML frontmatter and all required fields
3. Write the markdown body: architecture rules first, then layer-by-layer implementation patterns with code examples
4. Run the validation script locally before pushing:

```bash
./scripts/validate-skills.sh
```

### Validation Checks

The CI pipeline validates every SKILL.md on push to `master` and on pull requests touching `coding/**`:

- Every directory under `coding/` must contain a `SKILL.md`
- Frontmatter must be valid YAML with all required fields (`name`, `description`, `license`, `compatibility`, `metadata`)
- `metadata` must be a non-empty map
- Markdown body after frontmatter must be non-empty
- Fenced code blocks must be balanced (even number of ` ``` ` markers)

## License

MIT
