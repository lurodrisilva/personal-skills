---
name: skill-frontmatter-yaml-colon-trap-expertise
description: SKILL.md frontmatter descriptions break yq parsing when a backtick-quoted code span embeds a colon followed by a space — backticks are markdown, not YAML, so the colon still triggers a mapping-key parse and yq returns the misleading "mapping values are not allowed in this context" error.
triggers:
  - mapping values are not allowed in this context
  - yq error frontmatter SKILL.md
  - yaml frontmatter parse error
  - SKILL.md description fails validation
  - frontmatter description code span colon
  - personal-skills validate-skills.sh fails
  - description block scalar SKILL.md
  - bad file frontmatter yq
---

# SKILL.md Frontmatter — The Backtick-Code-Span-Colon Trap

## The Insight

YAML and Markdown are not the same parser. When a SKILL.md frontmatter `description:` is a long plain (unquoted) scalar that **embeds backtick-quoted code spans**, those backticks make the text *look* like protected code to a human eye. They are not protected to YAML. A code span like `` `brokers: [Integer]` `` or `` `entityOperator: { topicOperator, userOperator }` `` contains `: ` (colon followed by space), and YAML's plain-scalar grammar treats *any* `: ` as a key/value boundary — regardless of surrounding backticks. The parse fails with the misleading message **"mapping values are not allowed in this context"** at a column number deep inside the description.

The principle: **backticks belong to the rendering layer, not the YAML grammar layer.** Inside a YAML plain scalar, only YAML's escape rules count. `: ` and ` #` and leading `-`/`?`/`@`/`%`/`!`/`>`/`|` are all dangerous in plain scalars; backticks neutralise none of them.

## Why This Matters

Three things go wrong when you don't know this:

1. **The error message points to the wrong layer.** "mapping values are not allowed" at column 1141 sounds like a YAML structure problem — you'll go hunt for a stray indented colon, an unclosed brace, a double-quoted block. The real cause is one phrase deep inside a 3000-character description string that *looks fine in markdown*.

2. **The trap re-emerges on every long description.** Skills in `personal-skills/` and `~/.claude/skills/` use deliberately exhaustive descriptions (hundreds of trigger phrases, often with code-shaped examples). Every new skill is one re-spelling of `entityOperator: { ... }` away from breaking the validator.

3. **CI may not catch it.** `personal-skills/scripts/validate-skills.sh` walks `coding/` only — not `platform-engineering/`. A broken `platform-engineering/<skill>/SKILL.md` ships green and only fails when something downstream actually parses the frontmatter (skill loader, opencode auto-detection).

## Recognition Pattern

You're inside this trap when:

- `yq` reports `bad file '...': yaml: line N, column M: mapping values are not allowed in this context`
- The error column points deep inside the `description:` line (often 1000+ characters in)
- The description includes code-shaped phrases like `` `key: value` ``, `` `field: { ... }` ``, `` `name: [Type]` ``
- The frontmatter looks fine to a human — backticks make it look "quoted"
- Validation worked on a similar earlier skill, only this one breaks

To find the offending phrases programmatically:

```bash
awk '/^---$/{n++; next} n==1{print}' SKILL.md > /tmp/fm.yaml
python3 -c "
import re
desc = open('/tmp/fm.yaml').read().split('\n')[1]
for m in re.finditer(r'\`[^\`]*: [^\`]*\`', desc):
    print(f'col {m.start():4d}: {m.group()}')"
```

Every match is a YAML landmine.

## The Approach

Two viable fixes — pick by impact:

**Option 1 — Reword the phrase (preferred for one or two offenders).**

Plain English alternatives that preserve meaning without the colon-space:

| Broken | Fixed |
|--------|-------|
| `` `brokers: [Integer]` `` | `` `brokers` as `List<Integer>` `` |
| `` `entityOperator: { topicOperator, userOperator }` `` | `` `entityOperator` block carrying `topicOperator` and `userOperator` `` |
| `` `acks: all` `` | `` `acks=all` `` (use `=` instead of `:`) |
| `` `replicas: 3` `` | `` `replicas=3` `` |

`=` is grammatically natural for "field set to value" anyway, and YAML doesn't care about `=`.

**Option 2 — Convert the description to a folded block scalar (use when more than three phrases collide or when you don't want to reword).**

```yaml
description: >-
  MUST USE when ... full text, including `brokers: [Integer]`
  and `entityOperator: { topicOperator, userOperator }` without
  any further escaping needed because folded scalars don't parse
  inner content as YAML structure.
```

`>-` (folded, strip-trailing-newlines) is the right form for descriptions: lines join with single spaces, the `-` strips the implicit trailing newline that would otherwise break some readers. **Do not** use `>` (no `-`) — the trailing newline lands inside the scalar value. Do not use `|` (literal block scalar) — newlines are preserved verbatim and will look ugly when echoed.

The price of Option 2: every line of the description must be indented under the `description:` key. The reward: every future colon-bearing code span is harmless.

## The Decision Heuristic

- One or two offenders → reword (faster, no indentation reflow)
- Three or more offenders → convert to `>-` block scalar
- Description is being authored from scratch and you know it'll be long → start with `>-`
- Existing skill being touched for an unrelated reason → reword only the offender, leave the rest alone (don't churn the file)

## Example — The Diagnostic Snippet

When a SKILL.md fails validation, run this exact sequence:

```bash
SKILL=path/to/SKILL.md
awk '/^---$/{n++; next} n==1{print}' "$SKILL" > /tmp/fm.yaml
yq '.name' /tmp/fm.yaml      # confirm it's a frontmatter parse, not a body parse
python3 -c "
import re
desc = open('/tmp/fm.yaml').read().split('\n')[1]
print(f'description length: {len(desc)}')
for m in re.finditer(r'\`[^\`]*: [^\`]*\`', desc):
    print(f'col {m.start():4d}: {m.group()}')
"
```

If the script lists offenders, the trap is in play. Reword or convert.

## What This Is Not

This expertise is **not** about general YAML quoting rules — those are well-documented and Googleable. It's about the specific intersection of:

1. SKILL.md authoring conventions (long, deliberately exhaustive plain-scalar descriptions)
2. The temptation to write code-shaped examples inside markdown backticks
3. A misleading error message that points at YAML structure when the cause is a markdown idiom

The first time you hit it, you waste 15 minutes hunting for the wrong thing. The second time, you spot it in 30 seconds. This file exists so the second time happens before the first.
