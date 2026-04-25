<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-04-25 | Updated: 2026-04-25 -->

# golang-hex-clean

## Purpose
Skill that guides Go Hexagonal (Ports & Adapters) Clean Architecture work. Covers aggregates, value objects, CQRS use cases, HTTP/gRPC adapters, and infrastructure following strict hexagonal layering with dependency inversion. Synthesizes idiomatic Go style from the **Google Go Style Guide**, **Effective Go**, and **Uber Go Style Guide** — naming, error handling, interfaces, concurrency, and testing patterns.

## Key Files
| File | Description |
|------|-------------|
| `SKILL.md` | The skill definition — `name: golang-hex-clean`, `language: golang`, `pattern: hexagonal-clean-architecture` |

## Subdirectories
None.

## For AI Agents

### Working In This Directory
- Edit `SKILL.md` only.
- The package layout (`internal/domain/`, `internal/application/`, `internal/adapter/{inbound,outbound}/`, `internal/infrastructure/`, `cmd/`) and "Dependency Law" table are the load-bearing rules — do not soften "VIOLATION = AUTOMATIC FAILURE".
- "Ports are defined by their **consumer**" is a central rule — interface ownership goes to the inner layer that needs the capability, never to the implementer. Preserve this when editing port/adapter examples.

### Testing Requirements
- After editing, run `./scripts/validate-skills.sh` from the repo root.
- The skill ships many fenced Go blocks; verify even fence count.

### Common Patterns
- Layered architecture as ASCII art at the top — same convention as `dotnet-hex-clean`.
- Idiomatic-Go citations are inline: prefer attributing every rule to the source style guide (Google, Effective Go, Uber) so contributors can trace conventions.

## Dependencies

### Internal
- `../../scripts/validate-skills.sh` — enforces frontmatter + body + fenced-block contract.
- `../../README.md` — references this skill in the "Coding" table.

### External
None at runtime — this is documentation, not code.

<!-- MANUAL: -->
