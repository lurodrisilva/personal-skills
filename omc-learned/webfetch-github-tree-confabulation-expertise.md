---
name: webfetch-github-tree-confabulation-expertise
description: WebFetch hallucinates plausible YAML/code content when fed a GitHub HTML tree URL because the underlying summarisation model fills the gap with realistic-looking output instead of admitting the file body is not visible — always pin file lookups to raw.githubusercontent.com for verbatim content.
triggers:
  - WebFetch github tree
  - WebFetch hallucinated yaml
  - WebFetch invented field
  - github tree view yaml
  - raw.githubusercontent.com pattern
  - verbatim github file content
  - fake brokerCapacity WebFetch
  - WebFetch fabricated configuration
  - github translate.goog WebFetch
  - WebFetch returned nonexistent field
  - confabulated yaml example
---

# WebFetch + GitHub Tree URLs = Confabulated Content

## The Insight

`WebFetch` against a GitHub HTML **tree** URL (e.g. `github.com/<org>/<repo>/tree/<ref>/path`) does **not** see file bodies. The page only renders a directory listing — file contents are loaded lazily by JavaScript that WebFetch's HTML-to-markdown converter does not execute. The underlying summarisation model then fills the silence with **plausible-looking, partially-invented content** — fields that exist in similar projects, structures the model knows from training, defaults the model thinks are reasonable. The output reads like a verbatim transcription, but it isn't.

The principle: **WebFetch's "verbatim" claim is not a guarantee against hallucination — it is a request to the summariser, and the summariser will guess when it cannot see**. For file content, only raw HTTPS endpoints (`raw.githubusercontent.com/<org>/<repo>/<ref>/<path>`) are safe. For directory listings, GitHub HTML tree URLs are fine. Mixing the two — asking a tree URL for file *content* — is the trap.

## Why This Matters

Three concrete failure modes:

1. **Invented schema fields.** In one investigation, a fetch of `github.com/strimzi/strimzi-kafka-operator/tree/1.0.0/examples/cruise-control` returned a "verbatim" YAML containing a `brokerCapacity` block with `cpu / memory / disk` fields. Verifying via the raw endpoint showed `cruiseControl: {}` — **empty**. The `disk` field doesn't exist in the current `BrokerCapacity` API at all. Acting on the confabulated version would have produced an invalid CR that the operator silently rejects (or accepts, depending on version, with undefined behaviour).

2. **Plausible defaults masquerading as the upstream's choice.** WebFetch will often produce values that "look right for a Strimzi/Postgres/Kafka cluster" even when the actual upstream example uses different ones. You then propagate those numbers into a skill or a deployment, attributing them to the upstream — and they are not the upstream's. This contaminates the "Reference Examples" section of any document that claims to mirror an upstream tree.

3. **No error signal.** WebFetch doesn't say "I cannot see this file." It returns confident, plausible markdown. The only signal you have is that the fetched content disagrees with the raw endpoint when you cross-check.

## Recognition Pattern

You're inside this trap when **all** of the following are true:

- The URL is a GitHub `/tree/` path (directory listing), not a `/blob/` or raw URL.
- You asked for "verbatim" file contents in the prompt.
- The response renders a clean, well-formed YAML/code block as if quoted from the file.
- The block contains specific values (numbers, field names) that you are about to copy into a deliverable.

The strongest signal: the response is **too confident**. Real raw fetches sometimes have trailing whitespace, weird indentation, comments — the confabulated ones tend to be neat, idiomatic, and slightly idealised. If it looks like the example you would write yourself, it probably is.

Auxiliary signal: the response includes phrases like "*based on the provided content, here's the configuration with X expanded*" or "*here's the exact shape*" — language the model uses when it is interpolating, not transcribing.

## The Approach

Two-step rule for fetching files from a public Git repository host:

**Step 1 — Use the tree URL only to enumerate names.** A tree-URL fetch is reliable for the *list* of files in a directory because GitHub renders that into the HTML. Take the file inventory and stop.

**Step 2 — Fetch each file's content from the raw endpoint, one URL per file.** For GitHub:

```
https://raw.githubusercontent.com/<org>/<repo>/<ref>/<path>
```

Where `<ref>` is a branch name, tag, or commit SHA. Verify the content is actually a file (not the GitHub 404 page) by checking that the response starts with the expected YAML/code shape, not `<!DOCTYPE html>`.

Then, in the WebFetch prompt for the raw URL, use language that defeats interpolation:

> *"Reproduce the entire raw file text VERBATIM, character-for-character. Do not paraphrase. Do not 'expand'. Just copy the raw bytes inside a single fenced code block. If the file is empty or 404, say so explicitly."*

The phrase "do not 'expand'" is load-bearing — it tells the summariser that the prompt-author already noticed the confabulation tendency.

**Step 3 — When the answer matters, cross-check by sampling.** Fetch the same file twice with subtly different prompts. Confabulated content will often differ between calls in the invented details (different `cpu` values, different field ordering); verbatim content will not. A 1:1 match across two prompts is a much stronger signal than a single confident-looking response.

## Concrete Cross-Check Template

```bash
# Step 1: enumerate names from the tree URL
WebFetch tree-url -> "list every YAML file in this directory"

# Step 2: fetch each file from raw
for f in <files-from-step-1>; do
  WebFetch "https://raw.githubusercontent.com/<org>/<repo>/<ref>/<path>/$f" \
           "Reproduce the entire raw file text VERBATIM. If 404, say so."
done

# Step 3: when stakes are high, also fetch the file body from the /blob/ URL
# and diff. If they disagree, the /blob/ fetch was confabulated.
```

When the language is `https://raw.githubusercontent.com/...` returning the bytes you expect, the cycle is over. When you only have a `/tree/` URL response, you have **directory listings, not file contents** — treat the file bodies as unverified rumour.

## Generalisation Beyond GitHub

The pattern is not GitHub-specific. Any HTML page that *describes* files without rendering their bodies (GitLab tree, Bitbucket tree, package-registry browsers, doc-site index pages) will produce the same confabulation when WebFetch's summariser is asked for "the file content". The general rule:

> **WebFetch's reliability is bounded by what the URL's HTML actually contains. If the bytes you want are loaded by JavaScript or fetched on click, WebFetch cannot see them, and the summariser will guess.**

Always seek the canonical raw endpoint before claiming verbatim transcription.

## What This Is Not

This expertise is not about **WebFetch being broken**. WebFetch + a raw URL works fine. It is about the specific combination of (a) a *tree-listing* URL plus (b) a *verbatim-content* prompt — that combination is the failure mode. Avoid the combination, and the tool is reliable again.
