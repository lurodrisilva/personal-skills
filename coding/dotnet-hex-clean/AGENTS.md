<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-04-25 | Updated: 2026-04-25 -->

# dotnet-hex-clean

## Purpose
Skill that guides .NET Clean Architecture work following the **Ardalis Clean Architecture template**. Covers aggregates, value objects (Vogen), CQRS use cases (Mediator), FastEndpoints API (REPR pattern), EF Core configuration, domain events, specifications, and DI registration with strict layering and dependency inversion. Note: directory is `dotnet-hex-clean/` but the skill's `name:` frontmatter is `dotnet-clean-arch` — both are valid; the validator does not require alignment between directory and `name:`.

## Key Files
| File | Description |
|------|-------------|
| `SKILL.md` | The skill definition — `name: dotnet-clean-arch`, `framework: dotnet`, `pattern: clean-architecture`, `template: ardalis` |

## Subdirectories
None.

## For AI Agents

### Working In This Directory
- Edit `SKILL.md` only.
- The architecture diagram and "Dependency Law" table at the top are the load-bearing rules — every other section flows from them. Do not soften "VIOLATION = AUTOMATIC FAILURE" without intent.
- The Core layer's allowed-NuGet list (`SharedKernel`, `Vogen`, `GuardClauses`, `Specification`, `SmartEnum`, `Mediator.Abstractions`) is exhaustive — adding a new allowed package to Core requires a deliberate review.
- The skill follows a `MODE DETECTION` step that routes user requests to phases (NEW_AGGREGATE, NEW_USE_CASE, NEW_ENDPOINT, FULL_FEATURE). Keep that routing table accurate when editing.

### Testing Requirements
- After editing, run `./scripts/validate-skills.sh` from the repo root.
- The skill ships many fenced C# blocks; verify even fence count.

### Common Patterns
- Layered project tree (`Core → UseCases → Infrastructure → Web`) appears as ASCII art — same convention as `golang-hex-clean`.
- Tables for "MUST NEVER Reference" / "Mode Detection" are the canonical authoring style.

## Dependencies

### Internal
- `../../scripts/validate-skills.sh` — enforces frontmatter + body + fenced-block contract.
- `../../README.md` — references this skill in the "Coding" table at directory name `dotnet-hex-clean` (not the `name:` field).

### External
None at runtime — this is documentation, not code.

<!-- MANUAL: -->
