---
name: auth0-kong-authz-authn
description: 'MUST USE when authoring, reviewing, debugging, or migrating **authentication and authorization at a Kong API Gateway fronted by Auth0 as the OIDC Identity Provider** — covers the Kong Gateway Enterprise `openid-connect` plugin against Auth0 tenants, the nine credential search modes (`session`, `bearer`, `introspection`, `userinfo`, `kong_oauth2`, `refresh_token`, `password`, `client_credentials`, `authorization_code`), Auth0-specific quirks (the `audience` parameter on `/authorize` and `/oauth/token` to mint API-scoped JWTs instead of opaque tokens, the `https://<tenant>.<region>.auth0.com/` issuer trailing-slash trap, custom domains for first-party auth, the M2M client-credentials grant vs the interactive Universal Login flow, RS256-only signing for production, Auth0 Actions/Rules adding custom claims under a namespaced URI), the four Auth0 application types (SPA, Regular Web App, Native, Machine-to-Machine), Auth0 APIs (Resource Server identifiers used as `audience`), Auth0 connections (database, social, enterprise SAML/OIDC, passwordless) and how they are surfaced to Kong via the `acr`/`amr`/`connection` claims, scopes (`openid profile email` plus API permissions), RBAC via Auth0 roles/permissions claims, JWKS discovery (`/.well-known/jwks.json`), token introspection caveats (Auth0 does NOT implement RFC 7662 for JWTs — use signature verification via JWKS instead), refresh-token rotation, RFC 6750 bearer header, logout via `/v2/logout?client_id=&returnTo=`, mapping Auth0 `sub` / `email` / `azp` / custom claims to Kong Consumers (`consumer_claims`, `consumer_by`, `credential_claim`), `anonymous` fallback consumers for tiered access, claim-based authorization (`scopes_required`, `groups_required`, `roles_required`, `audience_required`, `issuers_allowed`), upstream header injection (`upstream_access_token_header`, `upstream_headers_claims`) so backend services receive the verified identity, session storage choices (cookie vs Redis cluster for HA), PKCE enforcement, mTLS client auth for FAPI, KongPlugin CRD via Kong Ingress Controller, declarative `kong.yaml` via decK, Konnect control-plane config, and Terraform via the `kong/konnect` provider, AND **Kong Gateway Operator (KGO)** with upstream **Gateway API** resources (`GatewayClass`, `Gateway`, `HTTPRoute`, `GRPCRoute`, `ReferenceGrant`) — the operator-managed `GatewayConfiguration`, `DataPlane`, `ControlPlane`, `KonnectExtension`, `KonnectAPIAuthConfiguration`, `KongPlugin`, `KongClusterPlugin`, `KongConsumer`, `KongPluginBinding`, `KongReferenceGrant`, `KongLicense`, `KongVault` CRDs, the `konghq.com/plugins` annotation as the HTTPRoute→KongPlugin binding mechanism, plugin scope precedence (Gateway → Service → HTTPRoute → Consumer), the migration path from KIC + `Ingress` to KGO + `HTTPRoute`, cross-namespace plugin / consumer references via `KongReferenceGrant`. Triggers on phrases — "kong auth0", "kong openid-connect plugin", "secure my api with auth0", "authenticate at the gateway", "machine-to-machine auth0", "m2m kong", "auth0 audience kong", "auth0 jwks kong", "auth0 universal login behind kong", "auth0 to kong consumer mapping", "auth0 rbac kong", "kong oidc anonymous", "kong oidc bearer", "kong oidc client_credentials", "kong oidc authorization_code", "auth0 custom domain kong", "auth0 logout kong", "refresh token rotation kong", "auth0 actions custom claim kong". Triggers on file patterns — `kong.yaml` / `kong.yml` containing `plugin: openid-connect`, `kind: KongPlugin` with `plugin: openid-connect`, Helm values keys `kong.plugins`, Auth0 Deploy CLI manifests under `tenant/` (`applications/*.json`, `resource-servers/*.json`, `actions/*.js`, `rules/*.js`, `roles/*.json`), Terraform files using `auth0_client`, `auth0_resource_server`, `auth0_connection`, `kong_plugin` / `konnect_gateway_plugin`. Authored by a distinguished Platform Engineer — emphasizes **gateway-enforced identity, zero trust upstream, JWKS-not-introspection for JWTs, audience-pinned per-API tokens, fail-closed at the edge**, never upstream auth as the only line of defense, never long-lived static secrets, never HS256 in production.'
license: BSD-3-Clause
compatibility: opencode
metadata:
  domain: platform-engineering
  pattern: edge-authn-authz
  platform: kong-gateway + auth0
  protocol: oidc + oauth2
  stack: kong-enterprise + auth0 + jwks
---

# Auth0 + Kong AuthN/AuthZ — Distinguished Platform Engineer's Playbook

You are a Platform Engineer responsible for the **single edge** where every request hits the corporate API estate. Authentication (who?) and authorization (what may they do?) are enforced **once, at Kong**, against **Auth0** as the OIDC Identity Provider. Upstream services receive a verified identity in a signed header and trust the edge — they never re-validate the user's password, never call Auth0 directly on the hot path, never see a cookie. This skill encodes the rules that make that contract safe at fleet scale.

**Non-negotiables encoded in this skill:**

1. **Kong terminates auth, upstream trusts the edge.** Backend services receive `X-Userinfo` / `X-Access-Token` / claim-derived headers (`X-User-Id`, `X-User-Email`, `X-User-Roles`) added by Kong **after** signature + audience + issuer + expiry verification. Upstream services NEVER call Auth0 directly on the request path. They MAY validate the propagated JWT a second time as defense-in-depth, but the gateway is the policy enforcement point.
2. **Verify JWTs by JWKS signature, not by introspection.** Auth0 issues signed JWT access tokens when an `audience` is specified. Kong fetches `https://<tenant>/.well-known/jwks.json` once, caches keys, and verifies locally. **Do not** call Auth0's `/userinfo` or any introspection endpoint per request — Auth0 does not implement RFC 7662 for JWTs (only for opaque tokens), and `/userinfo` is rate-limited and adds 50–200 ms of edge latency per request.
3. **Every API has an `audience` (Auth0 Resource Server identifier).** Without `audience` on the `/authorize` and `/oauth/token` requests, Auth0 issues an **opaque access token** that is only valid against Auth0's own `/userinfo` — not against your APIs. The audience pins the token to a specific API and lets Kong's `audience_required` reject tokens minted for another API.
4. **RS256 signing only.** `enable_hs_signatures: false` (the default) MUST stay false in production. HS256 turns the client_secret into a token-forging key for any party who knows it; RS256 keeps signing private to Auth0 and verification public via JWKS.
5. **Issuer claim is verified exact-match including the trailing slash.** Auth0's `iss` is `https://<tenant>.<region>.auth0.com/` (with trailing `/`) or your custom domain with trailing `/`. `issuers_allowed` MUST match byte-for-byte. A copy-paste that drops the slash silently rejects every token.
6. **Client secrets and signing keys are referenceable from Kong's vault, never inlined in YAML.** Use `client_secret: ${vault://env/AUTH0_CLIENT_SECRET}` (env vault) or AWS/HashiCorp/GCP vault references. Inline secrets in `kong.yaml` end up in git, in CI logs, in error messages.
7. **Authorization is claim-driven, fail-closed.** Every protected route declares `scopes_required` OR `roles_required` OR `groups_required` OR `audience_required` — at least one. A route with the plugin attached but no `*_required` field authenticates but does not authorize, which means any valid Auth0 token (including a token minted for a different application in the same tenant) gets through.
8. **PKCE is required for every public client (SPA, native, mobile).** `require_proof_key_for_code_exchange: true` on routes that serve the Universal Login redirect. Plain authorization-code flow without PKCE is deprecated by OAuth 2.1 and Auth0 will warn — but Kong must enforce it, not trust the client.
9. **Refresh-token rotation is on.** Auth0 application setting: "Refresh Token Rotation = Rotating". Kong's `refresh_tokens: true` (default) re-uses the rotated value. A leaked refresh token without rotation = unbounded session lifetime.
10. **Logout is a server-side action, not a cookie wipe.** `logout_methods: ["GET", "POST"]` + `logout_uri_suffix: "/logout"` + `logout_revoke: true` so Kong both clears its session AND revokes the Auth0 refresh token AND redirects to `https://<tenant>/v2/logout?client_id=<id>&returnTo=<url>` to clear Auth0's SSO cookie. Client-side `document.cookie = ""` leaves the Auth0 SSO session alive — next login auto-re-authenticates silently.
11. **No `anonymous` consumer on routes carrying real data.** `anonymous` maps auth failures to a fallback consumer for rate-limit / public-tier patterns ONLY. A route returning customer records with `anonymous: <consumer-id>` is a public-customer-data leak the day a token format changes.
12. **Production tenants are separate from non-prod.** One Auth0 tenant per environment (`<org>-dev`, `<org>-staging`, `<org>-prod`). Never one tenant with three apps named "dev / staging / prod" — a misconfigured connection on prod-the-app stays scoped to the prod tenant, not bleeding into staging.

If a Kong route, plugin, or Auth0 tenant violates any of these, flag them before anything else.

---

## WHEN TO USE THIS SKILL

| Scenario | Use this skill? |
|----------|-----------------|
| Authoring or reviewing a `KongPlugin` of `plugin: openid-connect` pointed at Auth0 | **Yes** |
| Adding Auth0 to a Kong Gateway (OSS or Enterprise) deployment | **Yes** |
| Wiring Auth0 M2M client credentials for a service-to-service call through Kong | **Yes** |
| Front-ending an internal SPA with Auth0 Universal Login behind Kong | **Yes** |
| Migrating from Kong's `jwt` / `oauth2` plugins to `openid-connect` against Auth0 | **Yes** |
| Mapping Auth0 `sub` or `email` to a Kong Consumer for plugin chaining (ACL, rate-limit-by-consumer) | **Yes** |
| Enabling RBAC at the edge using Auth0 roles/permissions claims | **Yes** |
| Setting up tenant-per-environment Auth0 infrastructure (Deploy CLI / Terraform) | **Yes** |
| Debugging "401 Unauthorized" from Kong with a valid-looking Auth0 token | **Yes** |
| Choosing between Kong's `jwt` plugin vs `openid-connect` plugin for Auth0 tokens | **Yes** — answer below is almost always `openid-connect` |
| Implementing FAPI-grade flows (mTLS, DPoP, PAR, JAR) | **Yes** |
| Installing Kong via **Kong Gateway Operator** with Gateway API (`Gateway`, `HTTPRoute`) | **Yes** |
| Greenfield Kubernetes cluster choosing between KIC + Ingress vs KGO + Gateway API | **Yes** — KGO is the default forward path |
| Migrating from KIC + `Ingress` to KGO + `HTTPRoute` while keeping Auth0 OIDC contract intact | **Yes** |
| Cross-namespace `KongPlugin` attachment to product-team `HTTPRoute` via `KongReferenceGrant` | **Yes** |
| Auth0 standalone (no gateway) — direct SDK integration in the backend | **No** — different scope, no edge enforcement |
| Non-Auth0 IdP (Okta, Keycloak, Azure AD, Cognito) on Kong | **Partial** — plugin config translates, but Auth0-specific quirks (audience, /v2/logout, namespaced custom claims) do not |
| Non-Kong gateway (Envoy / Apigee / AWS API Gateway) with Auth0 | **No** — wrong gateway |
| Workforce SSO into developer tools (not API protection) | **No** — Auth0 supports it but Kong is not in the path |

---

## ARCHITECTURE — WHERE EACH PIECE LIVES

```
                ┌─────────────────────────────────────────────────────┐
                │ Auth0 Tenant: <org>-prod.<region>.auth0.com         │
                │                                                     │
                │  Applications        Resource Servers (APIs)        │
                │  ┌────────────┐      ┌─────────────────────────┐    │
                │  │ Web (PKCE) │─────▶│ identifier=             │    │
                │  │ Native     │      │   https://api.example   │    │
                │  │ M2M (CC)   │      │ signing_alg=RS256       │    │
                │  └────────────┘      │ rbac=enabled            │    │
                │                      │ permissions[]           │    │
                │  Connections         └─────────────────────────┘    │
                │  ┌────────────┐                                     │
                │  │ DB         │      Actions (post-login):          │
                │  │ Social     │        adds custom claims under     │
                │  │ Enterprise │        https://api.example/claims/* │
                │  │ Passwordl. │                                     │
                │  └────────────┘      JWKS: /.well-known/jwks.json   │
                └────────────────┬────────────────────────────────────┘
                                 │ (1) /authorize?audience=...&scope=... (interactive)
                                 │     /oauth/token (CC / refresh / code)
                                 │     /.well-known/jwks.json (Kong cache, 1h)
                                 ▼
┌─────────┐  Bearer JWT   ┌───────────────────────────────────────────┐  X-Userinfo  ┌──────────┐
│ Client  │──────────────▶│ Kong Gateway (Enterprise)                 │─────────────▶│ Upstream │
│ (SPA /  │   in Header   │  - openid-connect plugin                  │  injected     │ service  │
│  M2M /  │               │  - issuers_allowed                        │  headers      │ (zero    │
│  mobile)│               │  - audience_required                      │               │  Auth0   │
└─────────┘               │  - scopes_required / roles_required       │               │  knowl-  │
                          │  - JWKS signature verify (local)          │               │  edge)   │
                          │  - consumer_claims → Kong Consumer        │               └──────────┘
                          │  - upstream_headers_claims → X-* headers  │
                          │  - rate-limit-advanced by consumer        │
                          │  - ACL by group claim                     │
                          └───────────────────────────────────────────┘
```

**Dataflow invariants:**

- **Discovery is one-time-then-cached.** Kong hits `https://<issuer>/.well-known/openid-configuration` once (per worker, per `rediscovery_lifetime`), caches every endpoint URL + JWKS keys. Set `rediscovery_lifetime: 86400` (24h) for production stability; key rotation via Auth0 happens manually and is rare.
- **The hot path makes no outbound calls** for JWT bearer flows. JWKS keys live in shared dict; signature verification is in-process. Latency budget: 1–3 ms per request.
- **`/userinfo` is a cold-path tool** for opaque tokens or for backfilling missing claims (`search_user_info: true`). Never the default for JWTs.

---

## AUTH0 SIDE — WHAT YOU CONFIGURE BEFORE TOUCHING KONG

### 1. Tenant per environment

| Tenant | Purpose | Naming |
|--------|---------|--------|
| `<org>-dev.<region>.auth0.com` | Developers' sandbox; loose connection lists | `<org>-dev` |
| `<org>-staging.<region>.auth0.com` | Pre-prod parity with prod connection set | `<org>-staging` |
| `<org>-prod.<region>.auth0.com` | Production; only the connections you need; MFA required | `<org>-prod` |

Manage with **Auth0 Deploy CLI** (`auth0-deploy-cli`) or the **Auth0 Terraform provider**:

```hcl
resource "auth0_resource_server" "api" {
  name        = "Example API"
  identifier  = "https://api.example.com"   # this becomes the `audience`
  signing_alg = "RS256"
  enforce_policies = true                    # turns on Auth0 RBAC
  token_dialect    = "access_token_authz"    # includes permissions[] in JWT
  skip_consent_for_verifiable_first_party_clients = true
}

resource "auth0_client" "web" {
  name             = "Web App"
  app_type         = "regular_web"
  callbacks        = ["https://app.example.com/callback"]
  allowed_logout_urls = ["https://app.example.com/"]
  grant_types      = ["authorization_code", "refresh_token"]
  oidc_conformant  = true
  jwt_configuration {
    alg = "RS256"
    lifetime_in_seconds = 36000
  }
  refresh_token {
    rotation_type = "rotating"
    expiration_type = "expiring"
    token_lifetime = 2592000          # 30 days absolute
    idle_token_lifetime = 1296000     # 15 days idle
  }
}

resource "auth0_client" "m2m" {
  name      = "Service A → Service B"
  app_type  = "non_interactive"
  grant_types = ["client_credentials"]
}

resource "auth0_client_grant" "m2m_to_api" {
  client_id  = auth0_client.m2m.id
  audience   = auth0_resource_server.api.identifier
  scope      = ["read:orders", "write:orders"]
}
```

### 2. The four application types — pick correctly

| `app_type` | When | Auth flow | PKCE | Client secret | Auth0 SDK |
|-----------|------|-----------|------|----------------|-----------|
| `regular_web` | Server-rendered web apps (Rails, Django, Next.js with API routes) | Authorization Code + Refresh | optional | yes (server keeps it) | `auth0-server-side` |
| `spa` | Browser-only, no server (React, Vue) | Authorization Code + PKCE | **required** | **no** | `@auth0/auth0-spa-js`, `@auth0/auth0-react` |
| `native` | iOS, Android, Electron, CLI | Authorization Code + PKCE | **required** | **no** | `@auth0/auth0-react-native`, `Auth0.swift` |
| `non_interactive` | Service-to-service, batch jobs, cron | Client Credentials | n/a | **yes** | direct `/oauth/token` POST |

**The decision rule:** if the secret can be inspected by an end user (browser DevTools, mobile binary), use `spa` or `native` with PKCE and no secret. Otherwise `regular_web` or `non_interactive`.

### 3. Auth0 APIs (Resource Servers) — the `audience`

Every protected backend API is an Auth0 **Resource Server** with a unique `identifier` (the `audience` value). Conventions:

- Use the **public URL** of the API as the identifier (`https://api.example.com`) — it's globally unique and self-documenting. Auth0 never calls it; the string is just an opaque key.
- One Resource Server per **distinct API surface**, NOT per microservice. If five microservices behind Kong all expose `/v1/orders/*`, `/v1/customers/*`, `/v1/payments/*` under `api.example.com`, that's **one** Resource Server. Fine-grained authorization is `permissions:` / scopes, not separate audiences.
- Turn on **RBAC** and **"Add Permissions in the Access Token"** so the `permissions: [...]` claim arrives in the JWT. Without this, `scopes_required` on Kong matches against `scope: "openid profile email"` (login scopes) instead of API permissions.

### 4. Auth0 Actions — custom claims under a namespaced URI

Auth0 reserves all top-level claim names except an explicit allow-list. **Any custom claim MUST be namespaced** as a URL prefix, e.g. `https://api.example.com/claims/tenant_id`. The post-login Action:

```javascript
exports.onExecutePostLogin = async (event, api) => {
  const namespace = 'https://api.example.com/claims';

  if (event.user.app_metadata?.tenant_id) {
    api.accessToken.setCustomClaim(`${namespace}/tenant_id`, event.user.app_metadata.tenant_id);
  }
  if (event.user.app_metadata?.feature_flags) {
    api.accessToken.setCustomClaim(`${namespace}/flags`, event.user.app_metadata.feature_flags);
  }
  if (event.authorization?.roles) {
    api.accessToken.setCustomClaim(`${namespace}/roles`, event.authorization.roles);
  }
};
```

Kong reads these via `consumer_claims`, `groups_claim`, `roles_claim`, `upstream_headers_claims` — using the namespaced key verbatim.

### 5. Connections — pick the minimum set

| Connection | Use | Notes for Kong |
|-----------|-----|----------------|
| Database (Username-Password-Authentication) | First-party users; password reset via Auth0 | `connection_strategy=auth0` lands in the JWT |
| Social (Google, GitHub, Microsoft, Apple, Facebook) | Consumer-grade onboarding | `connection_strategy=google-oauth2` etc.; Auth0 issues the JWT, no IdP-specific config on Kong |
| Enterprise (SAML, OIDC, Azure AD, Google Workspace, Okta Workforce, ADFS, PingFederate, LDAP) | B2B; partner IdPs | Auth0 normalizes claims; Kong stays IdP-agnostic |
| Passwordless (SMS, Email) | Magic-link / OTP login | Same JWT contract — Kong does not care |

**Connection-aware authorization** at Kong is rarely the right place. If you want "only B2B users via Enterprise SAML can hit `/v1/admin/*`," put the gate at the API in Auth0 (deny in a post-login Action) OR at Kong via a custom claim (`https://api.example.com/claims/tier=enterprise`) — NOT by matching `connection: "samlp"` directly. The latter ties Kong policy to Auth0's internal naming.

### 6. Custom domain (recommended for production)

Auth0 issues tokens with `iss: https://<tenant>.<region>.auth0.com/` by default. For first-party UX (login on `auth.example.com` instead of `<tenant>.auth0.com`) AND to keep the issuer stable across tenant migrations, configure an Auth0 **Custom Domain** (`auth.example.com`). Then:

- The `iss` claim becomes `https://auth.example.com/` — Kong's `issuers_allowed` MUST be updated together with the custom-domain rollout.
- The `audience` value is unchanged (it's tied to the Resource Server identifier, not the tenant URL).
- `/.well-known/openid-configuration` and `/.well-known/jwks.json` are served from the custom domain.

---

## KONG SIDE — THE `openid-connect` PLUGIN

Kong **Enterprise** ships `openid-connect`. Kong OSS does not — on OSS you'd compose `jwt` + `key-auth` + custom Lua, which loses claim-based authorization, session management, and refresh-token handling. **Use Kong Enterprise (or Konnect, which is Enterprise) for Auth0.** Migrating from `jwt` to `openid-connect` is the most common "we outgrew OSS" inflection.

### Minimum viable plugin — JWT bearer (M2M) protecting one API

```yaml
# kong.yaml (decK declarative)
_format_version: "3.0"

services:
  - name: orders-api
    url: http://orders.default.svc.cluster.local:8080
    routes:
      - name: orders
        paths: ["/v1/orders"]
        strip_path: false
        plugins:
          - name: openid-connect
            config:
              issuer: https://example-prod.us.auth0.com/.well-known/openid-configuration
              client_id:
                - ${{ env "AUTH0_CLIENT_ID" }}
              client_secret:
                - ${{ env "AUTH0_CLIENT_SECRET" }}
              auth_methods:
                - bearer
              audience_required:
                - https://api.example.com
              issuers_allowed:
                - https://example-prod.us.auth0.com/
              scopes_required:
                - read:orders
              ssl_verify: true
              rediscovery_lifetime: 86400
              hide_credentials: true
              upstream_access_token_header: authorization:bearer
              upstream_headers_claims:
                - sub
                - email
                - https://api.example.com/claims/tenant_id
              upstream_headers_names:
                - X-User-Id
                - X-User-Email
                - X-Tenant-Id
              cache_ttl: 3600
              run_on_preflight: false
```

**Three lines that determine the whole security posture:**

1. `auth_methods: [bearer]` — only RFC 6750 `Authorization: Bearer <jwt>` is accepted. No session cookies, no fallthrough to `/userinfo`, no implicit `password` grant. **Always restrict `auth_methods` to the minimum**; the default is *all nine* and exposes attack surface.
2. `audience_required` — rejects tokens minted for a different Resource Server. **This is the difference between a real boundary and a tenant-wide free-for-all.**
3. `issuers_allowed` — pins to the exact issuer. Trailing slash, custom domain, all matter. **Without this, any Auth0 tenant in the world that minted a token with your `audience` would be trusted** (unlikely but a defense-in-depth nightmare on shared multi-tenant setups).

### Interactive flow (Universal Login) protecting a web app behind Kong

```yaml
services:
  - name: portal
    url: http://portal.default.svc.cluster.local:8080
    routes:
      - name: portal-app
        paths: ["/"]
        plugins:
          - name: openid-connect
            config:
              issuer: https://example-prod.us.auth0.com/.well-known/openid-configuration
              client_id:
                - ${{ env "AUTH0_WEB_CLIENT_ID" }}
              client_secret:
                - ${{ env "AUTH0_WEB_CLIENT_SECRET" }}
              auth_methods:
                - session
                - authorization_code
              scopes:
                - openid
                - profile
                - email
                - offline_access            # mints refresh token
              audience:
                - https://api.example.com   # downstream APIs reuse this token
              redirect_uri:
                - https://portal.example.com/cb
              login_redirect_uri:
                - https://portal.example.com/
              login_redirect_mode: query
              logout_methods: ["GET", "POST"]
              logout_uri_suffix: /logout
              logout_redirect_uri:
                - https://example-prod.us.auth0.com/v2/logout?client_id=${AUTH0_WEB_CLIENT_ID}&returnTo=https%3A%2F%2Fportal.example.com%2F
              logout_revoke: true
              logout_revoke_access_token: true
              logout_revoke_refresh_token: true
              issuers_allowed:
                - https://example-prod.us.auth0.com/
              audience_required:
                - https://api.example.com
              require_proof_key_for_code_exchange: true
              refresh_tokens: true
              session_storage: redis
              session_cookie_secure: true
              session_cookie_http_only: true
              session_cookie_same_site: Lax
              session_rolling_timeout: 3600
              session_idling_timeout: 900
              session_absolute_timeout: 28800
              redis:
                host: redis.kong.svc.cluster.local
                port: 6379
                ssl: false
                cluster_nodes: []
              upstream_headers_claims:
                - sub
                - email
                - https://api.example.com/claims/roles
              upstream_headers_names:
                - X-User-Id
                - X-User-Email
                - X-User-Roles
```

**Why `session_storage: redis` and not the default `cookie`:**

- Cookie-stored sessions are limited to ~4 KB. Auth0 JWTs with custom claims + permissions easily exceed this.
- Cookie storage **cannot** be revoked server-side — `logout_revoke` works only on the Auth0 side, but the local session cookie remains valid until the client discards it.
- Multi-replica Kong proxies serving the same session cookie need a shared store regardless of size — Redis is the realistic default.

### M2M (client credentials) — service-to-service through Kong

Two patterns, pick based on **where you mint the token**:

**Pattern A: Client mints, Kong verifies.** The calling service calls Auth0's `/oauth/token` itself, then sends the JWT to Kong. Kong is pure verification.

```bash
# Calling service mints once, reuses until expiry
curl -fsS https://example-prod.us.auth0.com/oauth/token \
  -H "Content-Type: application/json" \
  -d '{
    "grant_type": "client_credentials",
    "client_id": "'"$AUTH0_M2M_CLIENT_ID"'",
    "client_secret": "'"$AUTH0_M2M_CLIENT_SECRET"'",
    "audience": "https://api.example.com"
  }'
# → {"access_token":"eyJhbGc...","expires_in":86400,"token_type":"Bearer"}

# Subsequent calls
curl -fsS https://api.example.com/v1/orders -H "Authorization: Bearer eyJhbGc..."
```

Kong plugin: same as the "Minimum viable" block above (`auth_methods: [bearer]`).

**Pattern B: Kong mints on behalf of the client.** The calling service hands Kong its own credentials, Kong exchanges them with Auth0 and forwards a bearer token upstream. Useful for legacy clients that can't speak OAuth.

```yaml
plugins:
  - name: openid-connect
    config:
      auth_methods:
        - client_credentials
      audience:
        - https://api.example.com
      client_credentials_param_type:
        - header           # accepts client_id/secret in Authorization Basic or X-Authorization
      cache_tokens: true   # cache the minted token; refresh just before expiry
```

**Default to Pattern A.** Pattern B makes Kong a privilege-escalating intermediary and complicates audit ("which service got which scope?" — every call routes through one Kong vault'd secret).

### Public / anonymous tier — read-only, rate-limited differently

```yaml
plugins:
  - name: openid-connect
    config:
      auth_methods: [bearer, session]
      audience_required: [https://api.example.com]
      issuers_allowed: [https://example-prod.us.auth0.com/]
      anonymous: 11111111-1111-1111-1111-111111111111   # UUID of a pre-created "anonymous" Consumer
  - name: rate-limiting-advanced
    config:
      identifier: consumer
      limit: [60]
      window_size: [60]
```

Auth0 token present and valid → authenticated consumer, real rate limit.
No token or invalid token → `anonymous` consumer, separately rate-limited (e.g. 10/min). The route MUST be safe to serve to a public unauthenticated client; if it isn't, `anonymous` is a vulnerability not a feature.

---

## CONSUMER MAPPING — FROM AUTH0 CLAIMS TO KONG IDENTITY

Kong's Consumer is the canonical handle for "this principal" — referenced by ACL, rate-limit-advanced, request-transformer, and audit logging. Mapping is **eager** (resolved on every request, cached) and **fail-closed by default**.

### Configuration

```yaml
plugins:
  - name: openid-connect
    config:
      consumer_claims:
        - email           # primary
        - sub             # fallback
      consumer_by:
        - username        # match by Consumer.username
        - custom_id       # then by Consumer.custom_id
      consumer_optional: false     # 401 if no matching Consumer exists
      by_username_ignore_case: true
      credential_claim:
        - sub             # what to put in `kong.authenticated_credential.id`
```

### Pre-creating Consumers

For first-party employees you usually mint the Consumer at provisioning time (HR sync, Terraform):

```yaml
consumers:
  - username: alice@example.com
    custom_id: auth0|65a3f1...
    tags: ["employees", "tier:gold"]
```

For SaaS-style "any signed-up user" you turn on `consumer_optional: true` (or use the `anonymous` fallback) and rely on claims for authorization instead of an ACL plugin tied to Consumers.

### Anti-pattern — matching by `sub` then expecting human-readable logs

`sub` in Auth0 is `auth0|<id>` / `google-oauth2|<id>` / `samlp|<provider>|<id>` etc. — opaque IDs. If you map Consumers by `sub`, your access logs say `auth0|65a3f1...` instead of `alice@example.com`. Map by `email` primarily, fall back to `sub` only when email is absent (machine clients, social logins without verified email).

---

## AUTHORIZATION — CLAIM-BASED, NEVER ROLE-IN-CONFIG

### Four orthogonal checks (combine freely)

| Check | Claim source | Auth0 mechanism |
|-------|--------------|-----------------|
| `scopes_required: [read:orders, write:orders]` | `scope` claim (space-separated) | OAuth scope grant on the client; whitelisted at the API |
| `roles_required: [admin, support]` | `roles_claim: [roles]` or namespaced custom claim | Auth0 RBAC + post-login Action emits `roles` |
| `groups_required: [eng-team, prod-on-call]` | `groups_claim: [groups]` or namespaced custom claim | Enterprise connection (SAML group attribute) or app_metadata mapped by Action |
| `audience_required: [https://api.example.com]` | `aud` claim (always present) | Resource Server identifier — non-negotiable |

ALL listed values in each `*_required` array must be present in the token for the request to pass (logical AND inside the array; logical AND across arrays).

### Reading namespaced custom claims

```yaml
roles_claim:
  - "https://api.example.com/claims/roles"   # nested path: dot-walk if it's a nested object
roles_required:
  - admin
```

For nested claims, use a multi-element array as a JSON path:

```yaml
groups_claim:
  - "https://api.example.com/claims/membership"
  - groups
```

This reads `token.https://api.example.com/claims/membership.groups`.

### When to push authorization to upstream vs enforce at Kong

| Decision | Enforce at Kong | Enforce upstream |
|----------|-----------------|------------------|
| Resource-existence / per-row ACL ("can Alice read invoice #42?") | **No** | **Yes** — only the upstream knows ownership |
| Coarse "can call this endpoint at all" | **Yes** — `scopes_required` | also OK as defense-in-depth |
| Tier gating ("free vs paid") | **Yes** — `groups_required` + rate-limit-advanced by group | redundant |
| Tenant isolation (multi-tenant SaaS) | **Yes** — propagate `X-Tenant-Id`, **and** enforce in upstream's DB queries | **Both** — Kong protects against header forgery only after this skill's non-negotiables are met |

---

## SESSION VS BEARER — WHICH `auth_methods` TO ENABLE

```yaml
auth_methods:
  # Pick the minimum subset that matches the client kinds hitting this route.
  - session              # Cookie set by Kong after authorization_code login. Browser apps.
  - authorization_code   # The /authorize redirect leg. Without this, session can't be established.
  - bearer               # Authorization: Bearer <JWT>. APIs, mobile, M2M.
  - refresh_token        # Kong auto-refreshes the access_token using a stored refresh_token. Sessionful flows.
  - client_credentials   # Kong itself mints a token from upstream-provided client creds. M2M Pattern B only.
  # AVOID by default:
  - password             # ROPC — legacy, deprecated by OAuth 2.1, lands user password at Kong.
  - introspection        # Use only for OPAQUE tokens. JWTs verify via JWKS — don't pay the round-trip.
  - userinfo             # Slow, rate-limited. Use search_user_info: true only to backfill missing claims.
  - kong_oauth2          # Tokens from Kong's deprecated oauth2 plugin — only during migration.
```

**The rule:** every additional method in `auth_methods` widens the gate. A bearer-only API endpoint should NOT also accept `session` "in case someone calls it from a browser" — the session was minted on a different route with different `audience_required`. Cross-method ambiguity defeats audience pinning.

---

## DEPLOYMENT TOPOLOGIES

### KongPlugin via Kong Ingress Controller (KIC)

```yaml
apiVersion: configuration.konghq.com/v1
kind: KongPlugin
metadata:
  name: oidc-orders-api
  namespace: default
config:
  issuer: https://example-prod.us.auth0.com/.well-known/openid-configuration
  client_id:
    - ${vault://env/auth0_client_id}
  client_secret:
    - ${vault://env/auth0_client_secret}
  auth_methods: [bearer]
  audience_required: [https://api.example.com]
  issuers_allowed: [https://example-prod.us.auth0.com/]
  scopes_required: [read:orders]
plugin: openid-connect
```

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: orders
  annotations:
    konghq.com/plugins: oidc-orders-api
spec:
  ingressClassName: kong
  rules:
    - host: api.example.com
      http:
        paths:
          - path: /v1/orders
            pathType: Prefix
            backend:
              service:
                name: orders
                port:
                  number: 8080
```

### Konnect declarative via Terraform

```hcl
resource "konnect_gateway_plugin_openid_connect" "orders" {
  control_plane_id = var.konnect_control_plane
  route = {
    id = konnect_gateway_route.orders.id
  }
  config = {
    issuer            = "https://example-prod.us.auth0.com/.well-known/openid-configuration"
    client_id         = [var.auth0_client_id]
    client_secret     = [var.auth0_client_secret]
    auth_methods      = ["bearer"]
    audience_required = ["https://api.example.com"]
    issuers_allowed   = ["https://example-prod.us.auth0.com/"]
    scopes_required   = ["read:orders"]
  }
}
```

### Kong Gateway Operator (KGO) + Gateway API

**Kong Gateway Operator** is the Kubernetes-native controller for running Kong Gateway (DataPlane + ControlPlane) declaratively. It supersedes the classic Kong Ingress Controller + Helm chart split on greenfield clusters and is the **only** path that consumes upstream **Gateway API** (`gateway.networking.k8s.io/v1`) resources natively — `GatewayClass`, `Gateway`, `HTTPRoute`, `GRPCRoute`, `ReferenceGrant` — instead of legacy `Ingress` + Kong-specific annotations.

**When KGO is the right choice for the Auth0 integration:**

| Trigger | Use KGO + Gateway API |
|---------|----------------------|
| Greenfield K8s cluster, no existing Kong | **Yes** — start here; don't adopt KIC if you'll migrate later anyway |
| Konnect-managed control plane, K8s-deployed data plane | **Yes** — KGO is the supported Konnect-on-K8s installer |
| Multi-team mesh where each team owns its own `HTTPRoute` / `KongPlugin` | **Yes** — Gateway API's `ReferenceGrant` model maps cleanly onto team boundaries |
| Existing KIC + `Ingress` deployment, no Gateway API in roadmap | **No** — keep KIC; KGO does NOT consume `Ingress` resources directly |
| OSS Kong without Enterprise license | **Partial** — KGO installs OSS Gateway, but the `openid-connect` plugin still requires Enterprise/Konnect |

#### 1. Install (cluster-level, one-time)

```bash
# Gateway API CRDs — KGO does NOT bundle them; install from upstream first.
kubectl apply --server-side -f \
  https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.1/standard-install.yaml

# Kong Operator Helm chart
helm repo add kong https://charts.konghq.com
helm repo update

# On-prem / self-hosted
helm upgrade --install kong-operator kong/kong-operator -n kong-system \
  --create-namespace \
  --set image.tag=2.1

# Konnect-managed control plane
helm upgrade --install kong-operator kong/kong-operator -n kong-system \
  --create-namespace \
  --set image.tag=2.1 \
  --set env.ENABLE_CONTROLLER_KONNECT=true

kubectl -n kong-system wait --for=condition=Available=true --timeout=120s \
  deployment/kong-operator-kong-operator-controller-manager
```

> **Pin the Gateway API release** (`v1.4.1` above) and the operator image tag. Floating tags on a controller that owns the entire edge is a fleet-wide outage waiting for a bad upstream release.

#### 2. Configure the DataPlane image (Auth0 needs the Enterprise gateway image)

```yaml
# kong/00-gatewayconfiguration.yaml
apiVersion: gateway-operator.konghq.com/v2beta1
kind: GatewayConfiguration
metadata:
  name: kong-configuration
  namespace: kong
spec:
  # On-prem (Enterprise license required for openid-connect plugin)
  dataPlaneOptions:
    deployment:
      podTemplateSpec:
        spec:
          containers:
            - name: proxy
              image: kong/kong-gateway:3.9
              env:
                - name: KONG_LICENSE_DATA
                  valueFrom:
                    secretKeyRef:
                      name: kong-enterprise-license
                      key: license
  # OR — Konnect-managed control plane
  # konnect:
  #   authRef:
  #     name: konnect-api-auth
```

```yaml
# kong/10-gatewayclass.yaml
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: kong
spec:
  controllerName: konghq.com/gateway-operator
  parametersRef:
    group: gateway-operator.konghq.com
    kind: GatewayConfiguration
    name: kong-configuration
    namespace: kong
```

```yaml
# kong/20-gateway.yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: kong
  namespace: kong
spec:
  gatewayClassName: kong
  listeners:
    - name: https
      protocol: HTTPS
      port: 443
      tls:
        mode: Terminate
        certificateRefs:
          - kind: Secret
            name: api-example-com-tls
```

Verify the operator reconciled and the DataPlane Deployment is up:

```bash
kubectl get -n kong gateway kong \
  -o=jsonpath='{.status.conditions[?(@.type=="Programmed")]}' | jq
# {"observedGeneration":1,"reason":"Programmed","status":"True","type":"Programmed"}

kubectl get -n kong dataplane,deployment,svc
```

#### 3. Attach the Auth0 `openid-connect` plugin to an HTTPRoute

The `KongPlugin` CR is unchanged from the KIC era — what changes is the **attachment point**. With Gateway API, the plugin binds to an `HTTPRoute` (or `Gateway`, or `Service`) via the `konghq.com/plugins` annotation:

```yaml
# kong/30-kongplugin-oidc-orders.yaml
apiVersion: configuration.konghq.com/v1
kind: KongPlugin
metadata:
  name: oidc-orders-api
  namespace: kong
config:
  issuer: https://example-prod.us.auth0.com/.well-known/openid-configuration
  client_id:
    - ${vault://env/auth0_client_id}
  client_secret:
    - ${vault://env/auth0_client_secret}
  auth_methods: [bearer]
  audience_required: [https://api.example.com]
  issuers_allowed: [https://example-prod.us.auth0.com/]
  scopes_required: [read:orders]
  upstream_headers_claims: [sub, email]
  upstream_headers_names: [X-User-Id, X-User-Email]
plugin: openid-connect
```

```yaml
# kong/40-httproute-orders.yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: orders
  namespace: kong
  annotations:
    konghq.com/plugins: oidc-orders-api    # binds the KongPlugin above to this route
spec:
  parentRefs:
    - group: gateway.networking.k8s.io
      kind: Gateway
      name: kong
  hostnames:
    - api.example.com
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /v1/orders
      backendRefs:
        - name: orders
          port: 8080
```

> **Plugin scope precedence**, lowest-to-highest specificity: `Gateway` → `Service` → `HTTPRoute` → `consumer`. Attach the OIDC plugin at the **HTTPRoute** layer for per-API audience/scope pinning; attach a *global* fallback (rate-limit-advanced, request-id, log) on the `Gateway`. Do NOT attach `openid-connect` at the `Gateway` level with `audience_required` set — different routes have different audiences.

#### 4. Cross-namespace plugins — `ReferenceGrant` and `KongReferenceGrant`

If the `HTTPRoute` and `KongPlugin` live in different namespaces (e.g. centralized platform-eng namespace owns the OIDC config, product team owns the route), you need a `ReferenceGrant` (Gateway API native, for backend Services) and / or `KongReferenceGrant` (Kong CRD, for KongPlugin / KongConsumer cross-namespace bindings).

```yaml
apiVersion: configuration.konghq.com/v1alpha1
kind: KongReferenceGrant
metadata:
  name: allow-product-routes-to-platform-plugins
  namespace: kong
spec:
  from:
    - group: gateway.networking.k8s.io
      kind: HTTPRoute
      namespace: product-team
  to:
    - group: configuration.konghq.com
      kind: KongPlugin
```

Without the grant, the route's `konghq.com/plugins` annotation silently refuses to resolve a cross-namespace `KongPlugin` — symptom: requests reach upstream **unauthenticated**, which is the worst possible failure mode for this skill. **Verify cross-namespace bindings in CI with a unit test that asserts the plugin is attached.**

#### 5. Custom Resource inventory (only the ones that matter for Auth0)

| Group / Kind | apiVersion | Scope | Purpose in this skill |
|--------------|------------|-------|------------------------|
| `gateway-operator.konghq.com/GatewayConfiguration` | `v2beta1` | Namespaced | DataPlane image, env, license, Konnect ref. Where `kong-enterprise-license` is mounted. |
| `gateway-operator.konghq.com/DataPlane` | `v1beta1` | Namespaced | The actual proxy Deployment (managed by the operator from GatewayConfiguration). Read for status; do NOT edit directly. |
| `gateway-operator.konghq.com/ControlPlane` | `v1beta1` | Namespaced | The control plane Deployment (KIC-equivalent). |
| `gateway-operator.konghq.com/KonnectExtension` | `v1alpha1` | Namespaced | Binds a DataPlane to a Konnect control plane. |
| `konnect.konghq.com/KonnectAPIAuthConfiguration` | `v1alpha1` | Namespaced | Konnect API token reference. Treat as a secret; vault it. |
| `gateway.networking.k8s.io/GatewayClass` | `v1` | Cluster | One per "kong" controller; references a `GatewayConfiguration` via `parametersRef`. |
| `gateway.networking.k8s.io/Gateway` | `v1` | Namespaced | Listener config (ports, TLS, hostname). Plugin attachment point for global plugins. |
| `gateway.networking.k8s.io/HTTPRoute` | `v1` | Namespaced | Path / host routing rules. **Primary attachment point for `openid-connect` plugin.** |
| `gateway.networking.k8s.io/GRPCRoute` | `v1` | Namespaced | Same model as HTTPRoute for gRPC services; same plugin attachment pattern. |
| `gateway.networking.k8s.io/ReferenceGrant` | `v1beta1` | Namespaced | Allow cross-namespace `backendRefs` from HTTPRoute to Service. |
| `configuration.konghq.com/KongPlugin` | `v1` | Namespaced | **The Auth0 OIDC config lives here.** Reference via `konghq.com/plugins` annotation. |
| `configuration.konghq.com/KongClusterPlugin` | `v1` | Cluster | Same shape as KongPlugin but cluster-scoped. Use ONLY for truly global concerns (request-id, prometheus); do NOT put the Auth0 OIDC config here — it's audience-specific. |
| `configuration.konghq.com/KongConsumer` | `v1` | Namespaced | Pre-created Auth0-mapped consumers (see Consumer Mapping section). |
| `configuration.konghq.com/v1alpha1/KongPluginBinding` | `v1alpha1` | Namespaced | Alternative to the annotation: explicit binding object (cleaner for GitOps reviews; preview-stage). |
| `configuration.konghq.com/v1alpha1/KongReferenceGrant` | `v1alpha1` | Namespaced | Cross-namespace KongPlugin / KongConsumer references. |
| `configuration.konghq.com/v1alpha1/KongLicense` | `v1alpha1` | Namespaced | Declarative Enterprise license; replaces the env-var-from-Secret pattern. |
| `configuration.konghq.com/v1alpha1/KongVault` | `v1alpha1` | Namespaced | Declarative vault backend (env, aws, hcv, gcp) — what `${vault://...}` references resolve through. |

> All `v1alpha1` resources are **subject to schema change**. Pin the operator version and validate the chart against the **exact** version in your cluster before bumping. Treat `v1alpha1` like a beta API surface — fine in production, but operator upgrade is a planned change with a smoke-test gate.

#### 6. Migration from KIC + Ingress to KGO + Gateway API

Run both controllers side-by-side during the cut-over:

1. Install KGO in `kong-system` namespace; existing KIC stays in `kong` namespace.
2. Stand up a parallel `Gateway` (different `Service` IP / hostname, e.g. `api-next.example.com`).
3. Mirror each `Ingress` as an `HTTPRoute`; mirror each KIC annotation-bound `KongPlugin` as an HTTPRoute-annotation-bound `KongPlugin` (the `KongPlugin` CR itself is identical — only the attachment changes).
4. Run end-to-end Auth0 tests (the same negative-test matrix from the TESTING section) against `api-next.example.com`.
5. Flip DNS to the new Gateway's Service IP / LoadBalancer.
6. Decommission KIC + Ingress.

**Do NOT** try to bind one `KongPlugin` to both an `Ingress` (KIC-watched) and an `HTTPRoute` (KGO-watched) simultaneously — two controllers reconciling the same upstream Kong is an unsupported topology and conflicts manifest as intermittent 401s.

#### 7. KGO + Auth0-specific operational tips

- **DataPlane restarts wipe in-memory JWKS cache.** Set `rediscovery_lifetime` high enough (≥1h) but don't rely on it surviving a DataPlane rollout — expect a few seconds of `/userinfo` fetches per worker after restart. Stagger DataPlane rollouts (`maxSurge: 1, maxUnavailable: 0` on the underlying Deployment via `podTemplateSpec`).
- **Operator-managed Service vs custom LB.** KGO creates the proxy `Service` automatically. To pin a static IP (Auth0 callback URLs reference the public hostname, not the IP, but TLS cert SANs do not auto-rotate), set `serviceOptions` on the GatewayConfiguration with a fixed `loadBalancerIP`.
- **Vault references resolve in the DataPlane pod, not the operator.** The operator copies the literal `${vault://env/...}` string into the DataPlane env; the gateway resolves it at request time. So the **DataPlane Deployment** (managed by the operator from `GatewayConfiguration.spec.dataPlaneOptions.deployment.podTemplateSpec.spec.containers`) needs the env vars / Secret mounts — not the operator pod.
- **`konghq.com/plugins` annotation accepts a comma-separated list.** Chain plugins on one route deterministically: `konghq.com/plugins: oidc-orders-api,rate-limit-by-consumer,request-transformer-userinfo`. Order in the annotation does NOT determine execution order — Kong's `PRIORITY` constant on each plugin does (`openid-connect = 1000`, runs early).

### Vault references — never inline secrets

Kong vault syntax:

```yaml
client_secret:
  - ${vault://env/AUTH0_CLIENT_SECRET}        # env vault
  - ${vault://aws/auth0/prod/client_secret}   # AWS Secrets Manager
  - ${vault://hcv/secret/auth0/prod}          # HashiCorp Vault KV
  - ${vault://gcp/projects/x/secrets/y}       # GCP Secret Manager
session_secret:
  - ${vault://env/KONG_SESSION_SECRET}        # 32 random bytes, rotate yearly
```

Bootstrap the env vault on Kong startup:

```bash
export AUTH0_CLIENT_ID=...
export AUTH0_CLIENT_SECRET=...
export KONG_SESSION_SECRET="$(openssl rand -base64 32)"
kong start
```

In Kubernetes, source from Secret + `envFrom:` on the Kong proxy Deployment.

---

## OBSERVABILITY — WHAT TO INSTRUMENT

| Signal | Where | Why |
|--------|-------|-----|
| `kong.openid-connect.success` / `failure` counter | Kong Prometheus exporter | Catches mass-auth failures (token revocation, key rotation) |
| `kong.upstream_latency_ms` segmented by `consumer` | Kong access log | Per-tenant SLO tracking |
| Auth0 tenant log stream → SIEM | Auth0 → Datadog / Splunk → SIEM | Failed logins, suspicious-IP signals, brute-force detection |
| 401/403 rate by route | Grafana via Prometheus | Anomalous spike = misconfigured client OR active credential-stuffing |
| `expires_in` distribution on minted M2M tokens | Auth0 logs | Catches a client over-minting (poor caching) |
| JWKS fetch count | Kong metrics | Should be near zero per worker per `rediscovery_lifetime` — high rate = key-rotation event OR cache eviction storm |

### Access-log claim propagation

```yaml
plugins:
  - name: file-log              # or http-log / kafka-log
    config:
      path: /var/log/kong/access.json
  - name: openid-connect
    config:
      upstream_headers_claims:
        - sub
        - email
      upstream_headers_names:
        - X-User-Id
        - X-User-Email
```

Kong's log includes the headers it forwarded — so the log line shows `sub` and `email` AFTER signature/audience/issuer verification. Don't read raw `Authorization` headers in logs; they're either too long or rotate frequently.

---

## TESTING — HOW TO PROVE IT WORKS

### 1. Local — Kong + Auth0 dev tenant

```bash
# Mint an M2M token against the dev tenant
ACCESS_TOKEN=$(curl -fsS https://example-dev.us.auth0.com/oauth/token \
  -H "Content-Type: application/json" \
  -d "{
    \"grant_type\":\"client_credentials\",
    \"client_id\":\"$AUTH0_DEV_M2M_ID\",
    \"client_secret\":\"$AUTH0_DEV_M2M_SECRET\",
    \"audience\":\"https://api.example.com\"
  }" | jq -r .access_token)

# Decode to verify claims (no signature check — just curiosity)
echo "$ACCESS_TOKEN" | cut -d. -f2 | base64 -d 2>/dev/null | jq .

# Call through Kong
curl -fsS http://localhost:8000/v1/orders -H "Authorization: Bearer $ACCESS_TOKEN" -i

# Negative tests
curl -fsS http://localhost:8000/v1/orders -i                                       # 401 (no token)
curl -fsS http://localhost:8000/v1/orders -H "Authorization: Bearer notajwt" -i    # 401 (malformed)
curl -fsS http://localhost:8000/v1/orders -H "Authorization: Bearer $WRONG_AUD" -i # 401 (audience mismatch)
curl -fsS http://localhost:8000/v1/orders -H "Authorization: Bearer $EXPIRED" -i   # 401 (exp)
```

### 2. Integration — assertion checklist

Every newly added `openid-connect` plugin gets these test cases in CI:

| Test | Expected |
|------|----------|
| GET `/v1/orders` with no auth | 401, `WWW-Authenticate: Bearer realm=...` |
| GET with invalid JWT | 401 |
| GET with valid JWT, wrong `aud` | 401 |
| GET with valid JWT, wrong `iss` | 401 |
| GET with valid JWT, expired | 401 |
| GET with valid JWT, missing `read:orders` scope | 403 |
| GET with valid JWT, all claims OK | 200, upstream sees `X-User-Email` |
| OPTIONS preflight | 200 (no auth, `run_on_preflight: false`) |
| Token signed with HS256 (forged) | 401 (RS256 enforced) |
| Token from a DIFFERENT Auth0 tenant with same `aud` | 401 (issuers_allowed) |

### 3. Load test — make sure JWKS isn't being re-fetched

```bash
# Hammer with one token; JWKS should be fetched once and cached.
hey -n 10000 -c 50 -H "Authorization: Bearer $ACCESS_TOKEN" http://localhost:8000/v1/orders

# Check Kong's outbound calls to Auth0:
kubectl exec -it deploy/kong -- tcpdump -n -i any host example-prod.us.auth0.com
# Expectation: 1 hit on /.well-known/openid-configuration + 1 hit on /jwks.json per worker, then silence.
```

If you see per-request hits to Auth0, `auth_methods` includes `introspection` or `userinfo`, or `rediscovery_lifetime` is too low. Fix before pushing to prod.

---

## COMMON BUGS & THEIR FIX

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| All requests return 401, valid Auth0 token | `iss` mismatch — trailing slash dropped in `issuers_allowed` | Use `https://<tenant>.<region>.auth0.com/` (with `/`) |
| All requests return 401, valid Auth0 token, issuer matches | Token is **opaque**, not a JWT — `audience` was not specified on `/authorize` | Add `audience=<resource-server-id>` to the auth request; verify the token starts with `eyJ` |
| 401 on M2M only, interactive works | M2M client lacks a `client_grant` to the Resource Server | `auth0_client_grant` resource granting the M2M client the API audience + scopes |
| 403 with valid token | `scopes_required` / `roles_required` / `audience_required` not satisfied | Decode token, check claim presence; for RBAC ensure Auth0 API has "Add Permissions in Access Token" enabled |
| Custom claim missing from token | Claim not namespaced (Auth0 silently drops non-namespaced custom claims) | Prefix with `https://<your-domain>/claims/...` in the Action |
| `groups`/`roles` empty despite Auth0 Role assignments | Auth0 only emits `permissions[]` by default — not `roles[]` | Post-login Action: `api.accessToken.setCustomClaim('https://.../roles', event.authorization.roles)` |
| Refresh token works once then 401 | Rotation is on but Kong's session storage is `cookie` (not shared) — second Kong worker doesn't see the rotated token | Switch `session_storage: redis` |
| `/v2/logout` doesn't actually log out — next visit auto-signs-in | Auth0 SSO cookie still alive; `logout_redirect_uri` not pointing at Auth0's logout endpoint | Set `logout_redirect_uri: https://<tenant>/v2/logout?client_id=...&returnTo=...`; URL-encode `returnTo` |
| Some requests slow (>200 ms at Kong layer) | `userinfo` in `auth_methods` triggering on every request | Remove `userinfo` from `auth_methods`; use `bearer` only for APIs |
| Multi-replica Kong: session lost on second hit | `session_storage: cookie` (default) with stateful flows | Redis-backed sessions |
| `Authorization` header missing upstream | `hide_credentials: true` (default) strips it | Either set `hide_credentials: false`, OR rely on `upstream_access_token_header` to re-inject |
| HS256 tokens unexpectedly accepted | `enable_hs_signatures: true` somewhere | Remove; ensure default `false` |
| New deployment, JWKS fetches storm Auth0 | `rediscovery_lifetime: 30` (default 30s) with many workers | Set to `86400` in prod |

---

## SECURITY HARDENING — BEYOND THE NON-NEGOTIABLES

- **PKCE everywhere a browser is involved.** `require_proof_key_for_code_exchange: true` on `authorization_code` routes. Auth0 dashboard: per-application setting "Application Properties → OIDC Conformant" must be on, and PKCE is required for SPA/native apps by default — Kong enforces it at the gateway regardless.
- **DPoP / mTLS for FAPI tier.** `proof_of_possession_dpop: strict` binds the access token to a client-held key (rfc 9449). Auth0 supports DPoP via the `dpop_jkt` parameter. Use for high-value APIs (payments, PHI).
- **Short access-token lifetime.** Auth0 Resource Server "Token Expiration" = 3600s (1h) max for production. Refresh-token rotation handles continuity.
- **`session_remember: false` unless you really want 30-day persistence.** Don't accidentally turn employees into permanent walking sessions.
- **`session_cookie_same_site: Strict`** for first-party web apps that never cross-navigate from third-party origins. `Lax` for typical public-facing.
- **`unauthorized_redirect_uri` for browser routes, NOT for APIs.** APIs return 401; browser-flow routes redirect to `/login`. Mixing them serves an HTML login page to a JSON client.
- **Rotate `session_secret` yearly.** Bumping invalidates all sessions (forces re-login) — schedule on the same cadence as TLS cert rotation.
- **Block direct upstream access.** NetworkPolicy / Service Mesh — upstream services accept connections ONLY from Kong's namespace. Otherwise the entire auth gate is "guards on the front door, back door wide open."
- **Audit Auth0 Actions in code review.** Anything in `event.user.app_metadata` is mutable by any user with `update:current_user_metadata` — never trust it for authorization without a server-only write path.

---

## ANTI-PATTERNS

| Anti-pattern | Why it breaks |
|--------------|---------------|
| Using Kong's `jwt` plugin instead of `openid-connect` for Auth0 | No claim-based authz, no JWKS auto-refresh, must manually maintain public keys on every rotation |
| `audience: []` (omitted) on `/authorize` requests | Auth0 issues an opaque token; Kong rejects it because there's nothing to verify; or worse, accepts it via `userinfo` and adds 200 ms latency per call |
| Same `audience` for prod and staging APIs | A staging token works in prod; a misrouted bug request hits real customer data |
| `auth_methods` left at default (all 9) | Surface area explosion; some methods (password, introspection) make outbound calls per request |
| `enable_hs_signatures: true` | client_secret becomes a token-minting key; anyone who reads it forges admin tokens |
| Hardcoding client_secret in `kong.yaml` checked into git | Secret appears in commit history, CI logs, error pages; rotating requires a deploy across every environment |
| Mapping Consumer by `sub` then assuming logs are human-readable | Logs show `auth0|65a3f1...`; debugging a customer issue requires Auth0 dashboard lookups |
| `consumer_optional: true` on a route that does ACL-by-consumer | ACL plugin sees no consumer; allows anyone in or blocks everyone depending on default |
| `anonymous: <uuid>` on a sensitive route | Auth failure silently downgrades to the anonymous consumer — looks fine in tests, leaks data in prod |
| Calling `/userinfo` per request to "get fresh user data" | Auth0 rate-limits this; turn on Actions + custom claims and read from the JWT instead |
| `rediscovery_lifetime: 30` (default) in prod | Stampeding-herd JWKS fetches; under load Auth0 throttles you and every request 401s |
| Same Auth0 tenant for dev + staging + prod | One connection toggle in dev affects prod traffic; blast radius = tenant, not environment |
| Logout that only clears Kong's session | Auth0 SSO cookie auto-re-authenticates on next visit — looks like "user never logged out" |
| `session_storage: cookie` with stateful refresh-token rotation | Multi-pod Kong: pod A rotates, pod B still sees the old token → second-request 401 |
| Trusting `app_metadata` for authorization without an Action-side allow-list | Users with `update:current_user_metadata` scope grant themselves admin |
| Issuing tokens with `algorithms: ["none"]` enabled in any Auth0 client | Never an option in Auth0 normal config, but custom Lua + `enable_hs_signatures` combined have shipped real CVE-class bugs |
| One Resource Server identifier per microservice | Operationally unmanageable; granularity belongs to scopes, not audiences |
| Attaching `openid-connect` at the `Gateway` level (KGO) with `audience_required` set | Different `HTTPRoute`s have different audiences; gateway-wide pinning rejects valid traffic for sibling APIs. Attach per-`HTTPRoute` instead |
| Putting Auth0 OIDC config in a `KongClusterPlugin` | Cluster-scoped = one audience for the whole cluster; defeats per-API audience pinning. Use `KongPlugin` per route |
| Cross-namespace `konghq.com/plugins` annotation without `KongReferenceGrant` | Binding silently fails; requests reach upstream **unauthenticated** — the worst failure mode for this skill |
| Running KIC + KGO in parallel against the same upstream Kong gateway | Two reconcilers fight over the same admin state; manifests as intermittent 401s. Cut over, then decommission |
| Skipping Gateway API CRD install before KGO | KGO refuses to start; misleading "CRD not found" errors that look like RBAC problems |
| Floating `kong/kong-operator` image tag | Controller owning the edge gets a silent upstream bump = fleet-wide outage. Pin the version |
| Custom claim without namespace prefix | Auth0 strips it silently; Kong's `groups_required` always fails |
| `pull_request_target` (GHA) deploying Kong config from a fork PR | Out of scope for this skill but commonly co-located — see the `github-actions` skill |

---

## PRE-DONE VERIFICATION CHECKLIST

Run through every box before declaring an Auth0+Kong integration complete.

### Auth0 tenant

- [ ] Separate tenant per environment (`<org>-dev`, `<org>-staging`, `<org>-prod`).
- [ ] Resource Server for the API exists with `signing_alg: RS256`, `enforce_policies: true`, `token_dialect: access_token_authz`.
- [ ] Resource Server identifier is the public API URL (e.g. `https://api.example.com`) — stable, globally unique.
- [ ] Application(s) registered with correct `app_type` (`regular_web`, `spa`, `native`, `non_interactive`).
- [ ] M2M applications have explicit `client_grant`s to each Resource Server with minimum scopes.
- [ ] Refresh-token rotation enabled (Rotating, with absolute + idle lifetimes set).
- [ ] Custom domain configured for prod (`auth.example.com`).
- [ ] Custom claims emitted by post-login Action are namespaced (`https://<api-url>/claims/...`).
- [ ] MFA enforced for prod tenant admin logins.
- [ ] Auth0 tenant log stream wired to SIEM.

### Kong `openid-connect` plugin

- [ ] `issuer` points to `.well-known/openid-configuration` URL.
- [ ] `issuers_allowed` includes the exact issuer with trailing slash.
- [ ] `audience_required` matches the API's Resource Server identifier.
- [ ] `auth_methods` is the **minimum** subset (typically `[bearer]` for APIs, `[session, authorization_code]` for browser flows).
- [ ] `client_id` / `client_secret` / `session_secret` reference a Kong vault — never inlined.
- [ ] `enable_hs_signatures: false` (default; explicit confirmation).
- [ ] `ssl_verify: true`.
- [ ] `rediscovery_lifetime: 86400` (or org-standard ≥1 hour).
- [ ] `hide_credentials: true` upstream; `upstream_access_token_header` set if upstream needs the JWT.
- [ ] `upstream_headers_claims` + `upstream_headers_names` propagate identity (`X-User-Id`, `X-User-Email`, at minimum).
- [ ] At least one of `scopes_required` / `roles_required` / `groups_required` is set for every non-anonymous route.
- [ ] PKCE required on `authorization_code` routes (`require_proof_key_for_code_exchange: true`).
- [ ] Refresh-token handling on (`refresh_tokens: true`).
- [ ] Logout: `logout_methods`, `logout_uri_suffix`, `logout_redirect_uri` pointing at Auth0 `/v2/logout`, `logout_revoke: true`.
- [ ] Session storage = `redis` if any flow is sessionful AND Kong has >1 replica.
- [ ] `anonymous` is **unset** (or set only on demonstrably public-tier routes).
- [ ] `run_on_preflight: false` for CORS-fronted APIs (so OPTIONS isn't auth-checked).

### Consumer & authorization model

- [ ] Consumer mapping: `consumer_claims: [email, sub]`, `consumer_by: [username, custom_id]`, `consumer_optional: false` (or `true` if claim-based authz alone is the gate).
- [ ] ACL / rate-limiting-advanced / request-transformer plugins reference the resolved Consumer, not raw token fields.
- [ ] Authorization decisions in upstream services use the propagated `X-User-*` headers (or re-verified JWT), never the original `Authorization` header alone.
- [ ] Multi-tenant SaaS: `X-Tenant-Id` propagated AND enforced in upstream DB queries (defense in depth).

### Testing

- [ ] Negative tests for missing token / wrong audience / wrong issuer / expired token all return 401.
- [ ] Insufficient-scope test returns 403, not 401.
- [ ] Forged HS256 token rejected.
- [ ] Token from a different Auth0 tenant rejected.
- [ ] Load test (≥1k RPS for ~5 min) shows zero JWKS re-fetch storms and stable p99 latency.
- [ ] Logout end-to-end test confirms the next visit triggers full re-authentication (no silent SSO).

### Observability

- [ ] Kong Prometheus metrics scraped (success/failure counters, latency histogram per route).
- [ ] Access logs include propagated `X-User-Email` / `X-User-Id` (or equivalent).
- [ ] Auth0 dashboard shows expected `Success Login` / `Success Exchange` / `Failed Exchange` rates.
- [ ] Alert on >1% auth-failure rate over a 5-minute window per route.
- [ ] Alert on Kong JWKS fetch rate > N per worker per hour (indicates cache thrash or key rotation event).

### Secrets & rotation

- [ ] No secret string appears in `kong.yaml`, `KongPlugin` CR, or Terraform state in plaintext.
- [ ] Kong vault references resolve at startup; deploy fails fast if a secret is missing.
- [ ] `session_secret` rotation runbook exists; rotation invalidates all sessions and is announced.
- [ ] Auth0 client_secret rotation: per-environment runbook (Auth0 dashboard → Rotate → update Kong vault → Kong rolling restart) tested.

### Kong Gateway Operator (KGO) + Gateway API (when applicable)

- [ ] Gateway API CRDs installed at a pinned upstream release (`v1.4.x` or current GA).
- [ ] `kong/kong-operator` Helm chart pinned to a specific `image.tag` (no `latest`, no floating major).
- [ ] `GatewayConfiguration.spec.dataPlaneOptions.deployment.podTemplateSpec` mounts `kong-enterprise-license` (or a `KongLicense` CR is present) — `openid-connect` requires Enterprise.
- [ ] `GatewayClass.spec.controllerName: konghq.com/gateway-operator` + `parametersRef` points to the `GatewayConfiguration`.
- [ ] `Gateway.status.conditions[Programmed].status == "True"` before declaring rollout done.
- [ ] OIDC `KongPlugin` is attached at the **`HTTPRoute`** level (per-audience), NOT on the `Gateway` (global).
- [ ] Auth0 OIDC config is NOT placed in a `KongClusterPlugin` (cluster scope defeats audience pinning).
- [ ] Cross-namespace plugin attachment is backed by a `KongReferenceGrant` (and `ReferenceGrant` for backend `Service` if needed).
- [ ] Smoke test asserts the `HTTPRoute` is actually plugin-bound (e.g. negative test returns 401, not 200).
- [ ] DataPlane Deployment rollout strategy: `maxSurge: 1, maxUnavailable: 0` so JWKS cache warm-up is staggered.
- [ ] Vault env vars / Secret mounts are on the DataPlane Deployment (via `GatewayConfiguration.dataPlaneOptions`), NOT on the operator pod.
- [ ] If using Konnect: `KonnectExtension` + `KonnectAPIAuthConfiguration` exist, Konnect API token is vaulted.
- [ ] Operator upgrade runbook tested in non-prod (`v1alpha1` CRD schema changes are possible).

### Governance

- [ ] Auth0 tenant config is in code (Deploy CLI or Terraform), version controlled.
- [ ] Kong plugin config is in code (declarative `kong.yaml`, `KongPlugin` CR, or Terraform).
- [ ] CODEOWNERS protects Auth0 tenant manifests AND Kong plugin manifests under platform-engineering.
- [ ] Production tenant access is via OIDC SSO with MFA; no shared admin accounts.
- [ ] Drift detection: scheduled CI job that diffs live Auth0 + Kong state against repo state and alerts.

If any box is unchecked, the integration is not done.
