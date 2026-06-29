<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-05-24 | Updated: 2026-05-24 | DEEPINIT: 2026-05-24 -->

# auth0-kong-authZ-authN

## Purpose
Skill that guides authoring + reviewing **authentication and authorization at a Kong API Gateway fronted by Auth0 as the OIDC Identity Provider**. Covers the Kong Gateway Enterprise `openid-connect` plugin against Auth0 tenants, the nine credential search modes, Auth0-specific quirks (`audience` parameter, trailing-slash issuer trap, RS256-only, namespaced custom claims), the four Auth0 application types (SPA / Regular Web App / Native / M2M), JWKS-not-introspection JWT verification, claim-driven authorization (`scopes_required` / `roles_required` / `groups_required` / `audience_required`), upstream header injection, session storage (cookie vs Redis), refresh-token rotation, server-side logout, and **Kong Gateway Operator (KGO)** + upstream Gateway API (`GatewayClass` / `Gateway` / `HTTPRoute` / `KongPlugin` / `KongConsumer` / `KongReferenceGrant`).

## Key Files
| File | Description |
|------|-------------|
| `SKILL.md` | Skill definition — `name: auth0-kong-authz-authn`, `domain: platform-engineering`, `pattern: edge-authn-authz`, `platform: kong-gateway + auth0`, `protocol: oidc + oauth2`, `stack: kong-enterprise + auth0 + jwks` |

## Subdirectories
None.

## For AI Agents

### Working In This Directory
- Edit `SKILL.md` only.
- The 12 non-negotiables at the top of the body are flag-first rules in any Kong/Auth0 PR review. Load-bearers: Kong terminates auth + upstream trusts edge (#1), JWKS-not-introspection (#2), `audience` per API (#3), RS256 only (#4), trailing-slash `iss` exact match (#5), secrets via vault refs (#6), claim-driven `*_required` (#7), PKCE for public clients (#8), refresh-token rotation (#9), server-side logout via Auth0 `/v2/logout` (#10), no `anonymous` on data routes (#11), tenant-per-environment (#12).
- "WHEN TO USE THIS SKILL" matrix covers both **KIC + Ingress** and **KGO + Gateway API** paths — KGO is the default forward path; the migration row keeps the Auth0 OIDC contract intact.
- The `description:` field is intentionally exhaustive (trigger surface for auto-detection). When extending coverage to new file patterns / phrases / CRDs, extend the description's trigger list to match.

### Testing Requirements
- **`scripts/validate-skills.sh` validates this directory** (its `DOMAIN_DIRS` includes `platform-engineering/`) — CI runs it on every push and PR. Run it locally before pushing; it checks:
  1. YAML frontmatter parses and contains `name`, `description`, `license`, `compatibility`, non-empty `metadata` map.
  2. Markdown body after the closing `---` is non-empty.
  3. Fenced code-block markers are even in count (an unclosed ` ``` ` fails CI).
- The skill's own snippets must satisfy its own rules — every `openid-connect` example must declare `audience`, an `*_required` claim, vault-referenced `client_secret`, RS256, and explicit `issuers_allowed` with trailing slash.

### Common Patterns
- "Non-negotiables encoded in this skill" numbered list — same authoring style as `addons-and-building-blocks`, `github-actions`, `wiremock-api-mocks`.
- "WHEN TO USE THIS SKILL" matrix opens the body.
- Anti-patterns table maps each violation to "why it breaks edge auth" (e.g. HS256 → client_secret becomes token-forging key; missing `audience` → opaque token unverifiable by Kong; `anonymous` on data route → public leak day token format changes).

## Dependencies

### Internal
- `../../README.md` — references this skill in the "Platform Engineering" table once added.
- `../../scripts/validate-skills.sh` — *currently does not validate this file*; expanding the validator is a tracked follow-up.
- `../addons-and-building-blocks/SKILL.md` — sibling skill whose layer-cake / OCI / sync-wave conventions apply when Kong itself is deployed as an addon.
- `../github-actions/SKILL.md` — sibling skill whose OIDC-federation discipline mirrors the gateway-side OIDC posture (no long-lived secrets, attested artifacts).

### External
None at runtime — this is documentation, not code.

<!-- MANUAL: -->
