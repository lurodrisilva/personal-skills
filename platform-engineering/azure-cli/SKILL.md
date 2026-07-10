---
name: azure-cli
description: >-
  MUST USE when authoring, reviewing, automating, or debugging anything that runs the
  **Azure CLI (`az`)** — covers the **command grammar** (`az <group> [<subgroup>…]
  <command> [--parameters]`, command groups / subgroups, `--ids` batching, positional
  discovery via `az <cmd> -h` / `az find` / `az interactive`), the **global-parameter
  surface** (`--output/-o`, `--query`, `--only-show-errors`, `--verbose`, `--debug`,
  `--subscription`, `--no-wait`, `--yes/-y`), the **seven output formats** (`json`
  (default), `jsonc`, `yaml`, `yamlc`, `table`, `tsv`, `none`) and the tsv/table gotchas
  (table drops nested objects + `id`/`type`/`etag`; tsv has no key-order guarantee — pin
  it with a `--query` multiselect list `[].[a,b]`), **client-side JMESPath `--query`**
  (subexpression `.`, index `[0]`, multiselect list `[a,b]` / hash `{k:v}`, flatten `[]`,
  filter `[?x=='y']`, functions `contains`/`sort_by`, pipe `|`, the single-quote/backtick
  string rule where double quotes in a predicate return empty output, and the
  two-parse-rounds backtick-escaping trap across bash vs PowerShell vs Cmd), the
  **identity-first authentication model** (interactive `az login` + WAM broker + device
  code `--use-device-code`; service principal `--service-principal -u <appId> -p <secret>`
  vs certificate `--certificate cert.pem` + `--use-cert-sn-issuer`; managed identity
  `--identity` system-/user-assigned `--username`/`--object-id`/`--resource-id`; federated
  **OIDC** `--federated-token`), `az ad sp create-for-rbac --role … --scopes …`
  least-privilege scoping (default = no role, root scope = over-broad), **accounts /
  subscriptions / tenants** (`az account show|list|set|clear|get-access-token|
  list-locations`, default-subscription concept, `--tenant` pinning, the login
  subscription selector), **sovereign / national clouds** (`az cloud
  list|show|set --name AzureCloud|AzureUSGovernment|AzureChinaCloud` — distinct Entra /
  ARM endpoints, set the cloud **then** log in), the **two-tier configuration model**
  (`az config set <section>.<key>=<value>` / `az init` / `az configure`,
  `$AZURE_CONFIG_DIR/config` INI, precedence **CLI param > env var > config file**) and
  the **`AZURE_{SECTION}_{NAME}` environment-variable surface** (`AZURE_CONFIG_DIR`,
  `AZURE_CORE_OUTPUT`, `AZURE_CORE_ONLY_SHOW_ERRORS`, `AZURE_CORE_COLLECT_TELEMETRY`,
  `AZURE_DEFAULTS_GROUP`, `AZURE_DEFAULTS_LOCATION`, `AZURE_CLOUD_NAME`,
  `AZURE_EXTENSION_USE_DYNAMIC_INSTALL`, plus the Identity-SDK auth vars `AZURE_CLIENT_ID`,
  `AZURE_CLIENT_SECRET`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`,
  `AZURE_CLIENT_CERTIFICATE_PATH`, `AZURE_FEDERATED_TOKEN_FILE`, `AZURE_AUTHORITY_HOST`),
  **extensions** (`az extension add|list|remove|update|list-available`, the
  `Azure/azure-cli-extensions` `src/index.json`, dynamic-install
  `extension.use_dynamic_install=yes_prompt|yes_without_prompt|no`, private index URL,
  GA/Preview/Experimental tags — there is **no** `--allow-preview` flag), **pagination &
  async** (`--max-items`/`--next-token`, `--no-wait` + the `az <resource> wait
  --created/--deleted/--exists/--updated/--custom` poller instead of `sleep` loops, `--ids
  @-` stdin fan-out), **install & versioning** (Homebrew, `winget install
  Microsoft.AzureCLI`, apt/dnf/zypper repos, `curl -sL https://aka.ms/InstallAzureCLIDeb |
  sudo bash`, Docker `mcr.microsoft.com/azure-cli:<ver>-azurelinux3.0` — Alpine +
  RHEL7/SLES images EOL, Azure Cloud Shell preinstalled, `az version` / `az upgrade`,
  Python + `azure-cli-core` + `knack` architecture, ~monthly release cadence, no-version-pin
  doctrine except CI), the **debug / proxy / error surface** (`--debug` REST wire trace,
  exit codes 0 success / 1 error / 2 parse / 3 not-found, corporate MITM proxy via
  `REQUESTS_CA_BUNDLE` preferred over the legacy `AZURE_CLI_DISABLE_CONNECTION_VERIFICATION`
  / `ADAL_PYTHON_SSL_NO_VERIFY`, `HTTPS_PROXY`, `az feedback`), the **CI/CD posture**
  (GitHub Actions `azure/login@v2` OIDC with `permissions: id-token: write`, `az`
  preinstalled on runners, telemetry off, `--only-show-errors`, pinned Docker image), the
  `az rest` ARM escape hatch, and the **Azure MCP Server** (`microsoft/mcp` →
  `servers/Azure.Mcp.Server`, GA, `npx -y @azure/mcp@latest server start`, reuses the
  `az login` session via DefaultAzureCredential, `azureMcp.serverMode`
  namespace/single/all + `azureMcp.readOnly` — structured typed tool surface for agents,
  complementary to the deterministic `az` CLI), and the **anti-patterns** that bite teams
  (long-lived SP client secrets in repos / CI / `.env`; ROPC `-u/-p` login dead under
  mandatory MFA; echoing/logging `az account get-access-token` output which is a live
  Bearer credential; `create-for-rbac` with no `--scopes`; parsing `-o table` in scripts;
  relying on tsv field order; double-quoting a JMESPath predicate; leaving telemetry /
  survey prompts on in CI; assuming one cloud's token works cross-cloud). Triggers on
  phrases — "azure cli", "az cli", "`az login`", "`az account`", "`az group`", "`az vm`",
  "`az aks`", "`az storage`", "`az keyvault`", "`az ad sp`", "`az config`", "`az
  extension`", "`az cloud`", "`az rest`", "`az … wait`", "az query", "--query jmespath",
  "-o tsv", "output format azure cli", "service principal", "create-for-rbac", "managed
  identity login", "azure/login", "azure oidc", "workload identity federation", "sovereign
  cloud", "azure government / china cloud", "AZURE_CONFIG_DIR", "azure cli extension",
  "dynamic install extension", "azure cli docker", "azure cloud shell", "azure mcp server",
  "azmcp". Triggers on file patterns — `**/*.sh` invoking `az ` (trailing space),
  `**/Makefile` rules calling `az`, `**/.github/workflows/*.{yml,yaml}` with `uses:
  azure/login@*` or `run: az …`, `**/azure-pipelines.yml` running `az`, `**/Dockerfile`
  containing `RUN az ` or `FROM mcr.microsoft.com/azure-cli`, `**/.azure/config`,
  `**/scripts/*az*.{sh,ps1}`. Authored from the perspective of a **distinguished Azure
  Platform Engineer** — emphasises **command-group discipline, identity-first auth (managed
  identity / OIDC over long-lived secrets), JMESPath + output-format competency, config +
  env-var precedence literacy, extension + dynamic-install hygiene, waiter / `--ids`
  literacy, CI hardening (`--only-show-errors`, telemetry off, pinned image, OIDC), and the
  stop-sign that `az` is a *thin MSAL-authenticated client over ARM REST* you can read with
  `--debug` — every command is an HTTPS call to `management.azure.com`, not a magic control
  plane**. Sister skill to `aws-cli` (the analogous AWS CLI playbook), `azure-finops`
  (which drives read-only `az costmanagement` / `az graph` triage), `azure-retail-prices`
  and `kusto-kql-api` (analogous Azure public-API / query discipline), and `github-actions`
  (CI auth via `azure/login` OIDC).
license: BSD-3-Clause
compatibility: opencode
metadata:
  domain: platform-engineering
  pattern: azure-cli-usage-and-automation
  platform: azure
  stack: azure-cli (az) + msal + jmespath + arm-rest
  cloud: azure-public (also AzureUSGovernment + AzureChinaCloud via `az cloud set`)
  discipline: cli-usage, automation, ci-cd, identity
  use_cases: ad-hoc-ops, ci-cd-pipelines, makefile-tasks, azure-pipelines, github-actions, aks-bootstrap, service-principal-and-oidc-login, managed-identity, jmespath-extracts, resource-inventory, sovereign-cloud, azure-mcp-integration
  sister_skills: aws-cli, azure-finops, azure-retail-prices, kusto-kql-api, github-actions
  reference_docs:
    - https://learn.microsoft.com/en-us/cli/azure/
    - https://learn.microsoft.com/en-us/cli/azure/get-started-with-azure-cli
    - https://learn.microsoft.com/en-us/cli/azure/format-output-azure-cli
    - https://learn.microsoft.com/en-us/cli/azure/use-azure-cli-successfully-query
    - https://learn.microsoft.com/en-us/cli/azure/azure-cli-configuration
    - https://learn.microsoft.com/en-us/cli/azure/authenticate-azure-cli
    - https://learn.microsoft.com/en-us/cli/azure/install-azure-cli
    - https://github.com/Azure/azure-cli
    - https://learn.microsoft.com/en-us/azure/developer/azure-mcp-server/
---

# Azure CLI (`az`) — Distinguished Azure Platform Engineer's Playbook

You are a **distinguished Azure Platform Engineer** writing or reviewing code that drives the
**Azure CLI (`az`)** — interactive ops, Makefile glue, Azure Pipelines / GitHub Actions steps,
AKS bootstraps, resource inventories, Key Vault reads, one-shot ARM calls. Your job is to ship
`az` usage that is **reproducible, identity-first (no long-lived secrets), JMESPath-parsed
(never table-scraped), scoped, and CI-hardened**.

This skill encodes the **`az` contract** (command grammar, authentication, accounts/clouds,
output/query, configuration + env vars, extensions, pagination/waiters, install/versioning,
debug/proxy) and the **operational discipline** that turns a one-off `az vm list` into a
production caller. `az` is a **Python client that speaks MSAL-authenticated HTTPS to
`management.azure.com`** — every command is an ARM REST call you can read with `--debug`.

**Non-negotiables encoded in this skill:**

1. **Command grammar is grouped.** `az <group> [<subgroup> …] <command> [--parameters]`.
   Groups map to services (`vm`, `aks`, `storage`, `keyvault`, `account`, `ad`, `group`),
   nest into subgroups (`az vm availability-set create`), and every command takes the global
   parameters `-o/--output`, `--query`, `--only-show-errors`, `--verbose`, `--debug`,
   `--subscription`. Discover with `az <cmd> -h` (works at group/subgroup/command level),
   `az find "<term>"` (AI examples), or `az interactive` (REPL). Never guess a flag — the
   `-h` output is the same reference the docs ship.

2. **Identity is first-class and long-lived secrets are the anti-pattern.** The 2026 identity
   order is: **managed identity** (`az login --identity`) for anything running *on* Azure →
   **federated OIDC** (`azure/login@v2`, `az login --federated-token`) for CI outside Azure →
   **certificate service principal** (`--certificate cert.pem`, SN+I auto-roll) where neither
   fits → **client-secret SP** only as a scoped, rotated last resort → **interactive** for
   humans. Username/password (ROPC, `-u/-p`) is **dead** — mandatory MFA for Entra user
   identities (since Sept 2025) breaks it. If you see `AZURE_CLIENT_SECRET=` in a repo,
   `.env`, tfvars, or CI secret store, **flag it first** before any other comment.

3. **`--query` is client-side JMESPath, and it is case-sensitive.** It filters the returned
   JSON *before* display, even under `-o tsv`/`-o table`. Strings are single-quoted or
   backticked — **double quotes inside a predicate return empty output** (`[?name=='web']`,
   not `[?name=="web"]`). Numbers/booleans are backtick literals (`` `50` ``, `` `false` ``),
   and backticks need extra escaping across shells (bash `` \`50\` ``, PowerShell `` ``50`` ``)
   because an `az` line is parsed twice. `--query` does **not** reduce API payload (it is not
   server-side) — for very large lists use real `--max-items`/`--next-token` pagination.

4. **Pick the output format for the consumer.** `-o json` (default) for machines/`jq`;
   **`-o tsv` for shell capture** (`sub=$(az account show --query id -o tsv)` — tsv strips the
   quotes/type); **`-o table` for humans only**. `table` silently drops nested objects and the
   `id`/`type`/`etag` keys; `tsv` has **no key-order guarantee** — pin column order with a
   `--query` multiselect list `[].[name,location,id]`. Never parse `-o table` in a script.

5. **Secrets must not hit logs.** Commands that return keys/passwords/connection strings use
   `--output none` or capture to a variable — many CI systems log stdout. **`az account
   get-access-token` output is a live Bearer credential** (`accessToken`), valid for up to an
   hour — never echo, log, or paste it. Read only the field you need (`--query expires_on -o tsv`).

6. **Scope every `create-for-rbac`.** `az ad sp create-for-rbac` assigns **no role by default**;
   passing `--role Owner` at subscription root is over-broad blast radius. Always
   `--role <least-privilege> --scopes /subscriptions/<sub>/resourceGroups/<rg>`. Prefer no
   secret at all (`--create-cert`, or a federated credential + `--create-password false`).

7. **CI hygiene is not optional.** Set `--only-show-errors` (or `AZURE_CORE_ONLY_SHOW_ERRORS`)
   so preview/deprecation warnings don't pollute logs or break stdout parsing; disable telemetry
   (`az config set core.collect_telemetry=no` / `AZURE_CORE_COLLECT_TELEMETRY=0`) and the survey
   prompt; authenticate with **OIDC** (`azure/login@v2`), not a stored secret; pin the CLI only
   in CI via the Docker image (`mcr.microsoft.com/azure-cli:<ver>-azurelinux3.0`).

8. **Waiters and `--ids` exist — use them.** For long-running ops, `--no-wait` then
   `az <resource> wait --created|--deleted|--exists|--updated|--custom "<JMESPath>"`, never a
   `sleep` loop with no failure semantics. Batch/fan-out with `--ids @-` reading IDs from stdin
   (`az vm list --query "[?…].id" -o tsv | az vm stop --ids @-`).

9. **Sovereign clouds have different endpoints.** A public-cloud token is not valid against Azure
   US Government or Azure China. `az cloud set --name AzureUSGovernment` (or `AzureChinaCloud`)
   **before** `az login` — the Entra login host, ARM endpoint, and DNS suffixes all differ.

If a script, Makefile, workflow, or wrapper under review violates any of these, **flag them
first** before any other comment.

---

## WHEN TO USE THIS SKILL

| Scenario | Use this skill? |
|----------|-----------------|
| Writing a Makefile / shell script that calls `az aks get-credentials`, `az group create`, `az storage …` | **Yes** |
| Reviewing a GitHub Actions workflow using `azure/login@v2` + `az deployment group create` | **Yes** |
| Debugging "the wrong subscription / tenant is active in my CI step" | **Yes** |
| Extracting resource IDs across resource groups with `--query` + `-o tsv` | **Yes** |
| Migrating a team off long-lived SP client secrets to managed identity / OIDC | **Yes** |
| Choosing the right `az login` method for a laptop vs a pipeline vs an in-Azure VM | **Yes** |
| Setting up `az` in a Dockerfile / Azure Pipelines / dotfiles, or installing an extension | **Yes** |
| Wiring the **Azure MCP Server** into an agent that already has an `az login` session | **Yes** |
| Authoring **Bicep** / **ARM** templates (that's `az deployment` *plumbing*, but template *authoring* is a Bicep skill) | Body only |
| Writing **Terraform** `azurerm` resources (use the Terraform skill) | No |
| Writing **PowerShell `Az`** module code, or a language SDK (`azure-identity`, `azure-mgmt-*`) | No |
| FinOps cost triage (`az costmanagement` / `az graph`) — use `azure-finops`; this skill owns the CLI *mechanics* | Delegate |

---

## INSTALLATION & FIRST-RUN

`az` runs on Windows, Linux, macOS, in Docker, and is preinstalled + auto-updated in Azure
Cloud Shell. It is a **Python** program (`azure-cli` command modules + `azure-cli-core` +
`azure-cli-telemetry`, on the `knack` CLI framework); extensions are separate wheels. Releases
land **about once a month** — prefer "install latest + `az upgrade`" over pinning, **except in
CI**, where you pin the Docker image for reproducibility.

```bash
# macOS — Homebrew (the only officially maintained macOS method; needs macOS 13+)
brew update && brew install azure-cli

# Windows — WinGet (recommended)
winget install --exact --id Microsoft.AzureCLI
# ...or 64-bit MSI: Invoke-WebRequest https://aka.ms/installazurecliwindowsx64 -OutFile AzureCLI.msi

# Linux — Debian/Ubuntu one-liner
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
# RHEL/CentOS Stream: dnf; SLES/OpenSUSE: zypper install azure-cli
#   (2.38.2 is the LAST version for RHEL7/CentOS7 + SLES/Leap — those are EOL)

# Docker (pin the version in CI; use the Azure Linux 3.0 image — Alpine is EOL at 2.63.0)
docker run -it --rm \
  -v "$HOME/.azure:/root/.azure" \
  mcr.microsoft.com/azure-cli:azurelinux3.0 \
  az account show

# Azure Cloud Shell — preinstalled, kept current (az upgrade is NOT supported there).
```

Verify + maintain:

```bash
az version          # JSON: azure-cli / azure-cli-core / azure-cli-telemetry / extensions{}
az upgrade          # upgrade CLI + extensions (Preview); let it finish before running more commands
```

Config + token cache live in `$AZURE_CONFIG_DIR` (default `~/.azure`, `%USERPROFILE%\.azure`
on Windows) — `azureProfile.json` (subscriptions), the encrypted MSAL token cache, and logs.

### Pick exactly one identity strategy (see AUTHENTICATION)

1. **Managed identity** — for anything running *on* Azure (VM, AKS, App Service, Functions, ACI).
2. **Federated OIDC** — for CI outside Azure (GitHub Actions / GitLab / other IdPs). No secret.
3. **Certificate service principal** — where MI/OIDC don't fit; SN+I supports auto-roll.
4. **Client-secret service principal** — scoped + rotated last resort only.
5. **Interactive (`az login`)** — humans/laptops; WAM broker on Windows, browser elsewhere.

---

## AUTHENTICATION

`az login` defaults (v2.61.0+): **WAM broker** on Windows 10+/Server 2019+, **browser** on
Linux/macOS, falling back to **device code** on headless/SSH/Cloud Shell.

```bash
# --- Interactive (human / laptop) ---
az login                              # browser or WAM; then the subscription selector
az login --use-device-code            # headless / SSH / when no browser
az login --tenant <tenant-id | contoso.onmicrosoft.com>
az login --allow-no-subscriptions     # tenant-level access, e.g. `az ad` work

# --- Service principal: client secret (scoped, rotated, last resort) ---
az login --service-principal -u <appId> -p <client-secret> --tenant <tenant-id>
#   read -sp so the secret never lands in shell history:
read -sp "SP secret: " AZ_PW && echo && az login --service-principal -u <appId> -p "$AZ_PW" -t <tenant-id>

# --- Service principal: certificate (preferred over a secret; PEM = private key + appended cert) ---
az login --service-principal -u <appId> --certificate /path/cert.pem --tenant <tenant-id>
az login --service-principal -u <appId> --certificate /path/cert.pem -t <tenant-id> --use-cert-sn-issuer  # SN+I auto-roll

# --- Managed identity (in-Azure compute; most secure — no secret to hold) ---
az login --identity                             # system-assigned
az login --identity --username <client-id>      # user-assigned (by client ID)
az login --identity --resource-id /subscriptions/.../userAssignedIdentities/MyId

# --- Federated OIDC (CI outside Azure — GitHub/GitLab/K8s workload identity) ---
az login --service-principal -u <appId> -t <tenant-id> --federated-token "$OIDC_JWT"

az logout                                        # drop the current session
```

> ROPC (`az login -u user -p pass`) is discouraged and **fails under mandatory MFA** — do not
> use it in automation. Service principals and managed identities are MFA-exempt (workload
> identities); OIDC is the secretless CI path.

### Create a service principal — least privilege

```bash
sub=$(az account show --query id -o tsv)
az ad sp create-for-rbac --name MyApp \
  --role Contributor \
  --scopes "/subscriptions/$sub/resourceGroups/rg1" "/subscriptions/$sub/resourceGroups/rg2"
# → {"appId":"…","displayName":"MyApp","password":"…","tenant":"…"}  ← SECRETS, never commit
#   appId → -u,  password → -p,  tenant → --tenant

az ad sp create-for-rbac --name MyApp --create-cert           # self-signed cert instead of a secret
az ad sp create-for-rbac --name MyApp --create-password false # no secret (pair with a federated credential)
```

`create-for-rbac` assigns **no role** without `--role` and **over-broad** blast radius without
`--scopes`. Microsoft's own guidance: prefer **managed identities** to avoid handling any
credential. Certificates beat secrets; federated credentials beat certificates.

| Context | Use |
|---------|-----|
| Laptop / ad-hoc / learning | Interactive `az login` (WAM / browser / device code) |
| CI/CD outside Azure (GitHub, GitLab) | **Federated OIDC** (`azure/login@v2`) — no stored secret |
| Compute running *on* Azure (VM, AKS, App Service, Functions) | **Managed identity** (`--identity`) |
| Where MI/OIDC are impossible | Certificate SP (SN+I) → then scoped, rotated secret SP |

---

## ACCOUNTS, SUBSCRIPTIONS, TENANTS & CLOUDS

```bash
az account show                                   # current subscription/tenant (add -o table)
az account list --all -o table                    # all subs incl. disabled + all clouds
az account set --subscription "<name | id>"        # switch the active/default subscription
az account clear                                  # wipe the local subscription cache (must re-login)
az account list-locations -o table                # regions available to the current sub

# Access token — the output is a live Bearer credential; read only what you need
az account get-access-token --query expires_on -o tsv        # expiry only (POSIX/UTC)
az account get-access-token --resource-type ms-graph          # a Graph token (do NOT log the token)
```

- **Default subscription**: after login, commands run against the active sub; override per call
  with the global `--subscription`. The login selector marks the default with `*`.
- **Tenant pinning**: multi-tenant users hitting "authentication failed against tenant" pin with
  `az login --tenant <id>` (the CLI otherwise logs into the first tenant found). Switching a
  cross-tenant subscription with `az account set` flips the tenant too.
- **Stale cache** ("subscription doesn't exist"): `az account clear && az login`.

### Sovereign / national clouds

```bash
az cloud list -o table                            # registered clouds + endpoints
az cloud set --name AzureUSGovernment             # then log in again
az cloud set --name AzureChinaCloud               # operated by 21Vianet (login.chinacloudapi.cn)
az cloud set --name AzureCloud                     # back to public
az login
```

Sovereign clouds are physically/legally isolated with distinct Entra login hosts (US Gov
`login.microsoftonline.us`), ARM endpoints, and DNS suffixes (`*.azurecr.us`). **Set the cloud
first, then log in** — a public-cloud token is not valid against a sovereign endpoint.

---

## OUTPUT FORMATS & `--query` (JMESPath)

| `-o` | Use it for |
|------|-----------|
| `json` (default) | Programmatic parsing (`jq`), full fidelity incl. nested objects |
| `jsonc` | Human-read colorized JSON in a terminal |
| `table` | Quick human overview — **drops nested objects + `id`/`type`/`etag`**; humans only |
| `tsv` | Scripts / variable capture / piping — strips quotes+type; **no key-order guarantee** |
| `yaml` / `yamlc` | Human-readable YAML dumps (some commands accept YAML config input) |
| `none` | Suppress output (secret-returning commands, managed-identity flows) |

```bash
# Capture a value — tsv strips the JSON quotes/type
subscriptionID=$(az account show --query id --output tsv)

# Force column order for a script (multiselect LIST) — tsv has no ordering guarantee
az vm list -g MyRG --show-details --query "[?powerState=='VM running'].[name,location,id]" -o tsv

# Human table with renamed columns (multiselect HASH + flatten)
az vm list --query "[].{Name:name, RG:resourceGroup, Location:location}" -o table

# Filter (single-quoted strings; double quotes in a predicate → empty output)
az vm list --query "[?storageProfile.osDisk.osType=='Linux'].{Name:name, Admin:osProfile.adminUsername}" -o table

# Functions + pipe + backtick numeric literal (bash needs \` escaping)
az disk list --query "[?diskSizeGb >= \`128\`] | sort_by(@, &diskSizeGb)[].{Name:name, GB:diskSizeGb}" -o table

# Show a filtered-out key by rekeying it
az vm show -g MyRG -n vm01 --query "{objectID:id}" -o table
```

`--query` is **client-side** and **case-sensitive** (`osProfile` ≠ `OsProfile`). Run it in
Cloud Shell or bash for the fewest escaping headaches; in PowerShell/Cmd the backtick literals
need doubling because the line is parsed twice before `az` sees it.

---

## CONFIGURATION & ENVIRONMENT VARIABLES

**Precedence (highest first): command-line parameter → environment variable → config file.**

```bash
az config set defaults.group=MyRG defaults.location=westus2   # drop --resource-group/--location
az config set core.output=table                               # default output format
az config set core.only_show_errors=yes                       # suppress preview/deprecation noise
az config set core.collect_telemetry=no                       # opt out of anonymous telemetry
az config set extension.use_dynamic_install=yes_without_prompt # CI-friendly auto extension install
az init         # interactive; "interaction" vs "automation" presets (Experimental)
az configure    # older interactive defaults tool
```

Config file: `$AZURE_CONFIG_DIR/config` (INI; `[section]` case-sensitive, keys
case-insensitive, `#`/`;` comments, booleans `1|yes|true|on` / `0|no|false|off`). Every config
value maps to an env var **`AZURE_{SECTION}_{NAME}`** (all caps):

| Env var | Effect |
|---------|--------|
| `AZURE_CONFIG_DIR` | Relocate config + MSAL token cache (give each concurrent script its own — avoids cache corruption) |
| `AZURE_CORE_OUTPUT` | Default output format |
| `AZURE_CORE_ONLY_SHOW_ERRORS` | Only errors to stderr; suppress preview/deprecated warnings |
| `AZURE_CORE_COLLECT_TELEMETRY` | `0`/`no` to disable telemetry (do this in CI) |
| `AZURE_CORE_NO_COLOR` | Disable color (fixes color not reverting after a stdout redirect) |
| `AZURE_DEFAULTS_GROUP` / `AZURE_DEFAULTS_LOCATION` | Default resource group / location |
| `AZURE_CLOUD_NAME` | `AzureCloud` / `AzureUSGovernment` / `AzureChinaCloud` |
| `AZURE_EXTENSION_USE_DYNAMIC_INSTALL` | `no` / `yes_prompt` / `yes_without_prompt` |

Auth vars consumed by the **Azure Identity SDK / DefaultAzureCredential / `azure/login`** (not
by `az login` flags directly — the GitHub Action exports them so later `az`/SDK steps inherit
context): `AZURE_CLIENT_ID`, `AZURE_CLIENT_SECRET`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`,
`AZURE_CLIENT_CERTIFICATE_PATH`, `AZURE_FEDERATED_TOKEN_FILE` (K8s/AKS workload identity),
`AZURE_AUTHORITY_HOST` (per sovereign cloud).

---

## EXTENSIONS

```bash
az extension list-available -o table        # discover Microsoft-published extensions
az extension add --name <name>              # install by name (or --source <wheel-url|path>)
az extension list -o table                  # installed (path + status)
az extension update --name <name>
az extension remove --name <name>
az extension add --name <name> --version <ver>   # pin (reproducible CI)
```

Extensions are separate Python wheels loaded at runtime, indexed in
`Azure/azure-cli-extensions` (`src/index.json`) — **updated independently of the core CLI**.
Point at a private index with `az config set extension.index_url=<URL>`. Each is tagged
**GA / Preview / Experimental** (there is **no** `--allow-preview` flag — preview extensions
install by name and emit warnings). **Dynamic install** (auto-install on first use of a
command) is on by default since 2.12.0 — set `extension.use_dynamic_install=yes_without_prompt`
for CI, or `no` to force a clean command-not-found error. Common extensions: `aks-preview`,
`azure-devops`, `bastion`, `ssh`, `resource-graph`, `costmanagement`, `k8s-extension`,
`containerapp`, `application-insights`.

---

## PAGINATION, ASYNC & `--ids` BATCHING

```bash
# Pagination on large list commands
az snapshot list --max-items 50                      # returns a continuation token if more remain
az snapshot list --next-token "<token>"              # resume

# Async: return immediately, then join with a waiter (no sleep loops)
az vm create -g MyRG -n vm01 --image Ubuntu2204 --no-wait
az vm create -g MyRG -n vm02 --image Ubuntu2204 --no-wait
az vm wait --created --ids "$vm01_id" "$vm02_id"     # --created/--deleted/--exists/--updated/--custom
az group delete --name MyRG --no-wait --yes

# Fan-out over stdin IDs (built-in parallelism; @- reads IDs from a pipe)
az vm list -g MyRG --show-details --query "[?powerState=='VM running'].id" -o tsv \
  | az vm stop --ids @-
```

`--query` is client-side, so it does **not** replace real `--max-items`/`--next-token`
pagination for very large result sets.

---

## DISCOVERY & THE `az rest` ESCAPE HATCH

```bash
az find "az storage account create"    # AI-driven popular commands + examples (GA)
az interactive                          # REPL with inline help + autocomplete (Preview)
az next                                 # recommends the likely next command (Experimental)

# When no dedicated command exists, call ARM REST directly (auth handled for you)
az rest --method get \
  --uri "https://management.azure.com/subscriptions/$sub/resourceGroups?api-version=2021-04-01"
```

`az rest` inherits the current `az login` credential and signs the request — the right tool for
brand-new resource providers the CLI hasn't wrapped yet.

---

## CI/CD POSTURE — GITHUB ACTIONS REFERENCE

```yaml
permissions:
  id-token: write        # REQUIRED — lets GitHub mint the OIDC token
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest      # az is preinstalled on GitHub-hosted runners
    env:
      AZURE_CORE_ONLY_SHOW_ERRORS: "true"
      AZURE_CORE_COLLECT_TELEMETRY: "0"
    steps:
      - uses: actions/checkout@v4
      - name: Azure login (OIDC — no stored secret)
        uses: azure/login@v2
        with:
          client-id:       ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id:       ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
      - name: Sanity check
        run: az account show -o table
      - name: Deploy
        run: |
          az deployment group create \
            --resource-group app-rg \
            --template-file infra/main.bicep \
            --only-show-errors
```

Rules in CI:

- Authenticate with **OIDC** (`azure/login@v2`, federated credential) — never a stored
  `AZURE_CLIENT_SECRET`. On Azure-hosted self-hosted runners, prefer managed identity
  (`auth-type: IDENTITY`).
- Register a **federated identity credential** on the app / user-assigned MI matching the
  repo/branch/environment `subject` before the first run.
- `--only-show-errors` + telemetry off + survey off, always.
- Run `az account show` right after login — if identity is wrong, everything downstream fails
  less informatively.
- Pin the CLI in containers via `mcr.microsoft.com/azure-cli:<ver>-azurelinux3.0`.

---

## DEBUG, PROXY & EXIT CODES

```bash
az vm list --debug 2>&1 | tee az-debug.log     # parsed args + full REST request/response + timing
az vm list --verbose                            # less noisy than --debug
az feedback                                     # open a prefilled GitHub issue
```

`--debug` prints the exact ARM REST call (URL/method/headers/body), the User-Agent (CLI +
Python + platform), and the log-file path under `~/.azure/commands/`. Treat the response body
as sensitive (it can contain keys/tokens) — sanitize before sharing.

| Exit code | Meaning |
|-----------|---------|
| `0` | Success |
| `1` | Error (service-side / runtime) |
| `2` | Parse error (unrecognized or invalid arguments) |
| `3` | Resource not found |

Corporate MITM proxy / self-signed TLS:

```bash
export HTTPS_PROXY="http://user:pass@proxy:port"
export REQUESTS_CA_BUNDLE=/path/to/combined-ca-bundle.pem   # preferred fix for cert-verify errors
```

Append the proxy CA (PEM) to the CLI's bundled `certifi/cacert.pem` and point
`REQUESTS_CA_BUNDLE` at it. Prefer this over the **legacy** escape hatches
`AZURE_CLI_DISABLE_CONNECTION_VERIFICATION=1` (disables TLS entirely — insecure) and
`ADAL_PYTHON_SSL_NO_VERIFY` (ADAL-era, largely obsolete since the move to MSAL).

---

## MCP SURFACE — THE AZURE MCP SERVER

The **Azure MCP Server** exposes Azure operations as **structured, typed tools to AI agents**
(over the Model Context Protocol) across 40+ services — so an agent manages/queries Azure with
validated tool calls instead of brittle shell strings. It is **complementary to `az`, not a
replacement**, and — critically for this skill — **reuses your `az login` session**.

- **Status: GA** ("Azure MCP Server 2.0"). Docs: `learn.microsoft.com/azure/developer/azure-mcp-server/`.
- **Live repo: `microsoft/mcp` → `servers/Azure.Mcp.Server`** (C#/.NET). The original
  `Azure/azure-mcp` repo is **archived (read-only)** — cite the live monorepo.
- **Auth reuses `az login`** via `DefaultAzureCredential` (or SP env vars / managed identity).
  **Run `az login` first**, then start the server — no separate credential.
- **It is its own process, not an `az extension`** (`az extension add` will not install it).

```bash
# Run the server (Node is the common path)
npx -y @azure/mcp@latest server start
# also: dotnet tool install Azure.Mcp   |   uvx --from msmcp-azure azmcp server start
```

```jsonc
// MCP client config (Claude Desktop / Cursor / VS Code use the same command/args)
{
  "mcpServers": {
    "azure-mcp-server": {
      "command": "npx",
      "args": ["-y", "@azure/mcp@latest", "server", "start"]
    }
  }
}
```

Behavior knobs that matter for an agent: `azureMcp.serverMode` = **`namespace`** (default —
tools grouped per service, keeps the tool list small) / `single` (one meta-tool) / `all` (every
tool), and **`azureMcp.readOnly`** to restrict to non-mutating operations.

**MCP vs `az` — when an agent uses which:** reach for **MCP tools** when reasoning in natural
language and you want typed inputs/outputs, cross-service discovery, and read-only guardrails
without knowing exact command syntax. **Shell out to `az`** for exact/scriptable ops,
reproducible CI, precise `--query` shaping, and the long tail the server doesn't cover. Both
ride the same `az login` credential, so switching needs no re-auth.

---

## READ-ONLY TRIAGE TOOLS (`tools/`)

Three review-before-running `bash` + `az` scripts ship with this skill. Each is **read-only**
(only `show` / `list` / `get` / `query`), needs at most **Reader** RBAC, and never provisions,
sets, or deletes. See `tools/AGENTS.md` for the hard invariant.

| Script | Surfaces |
|--------|----------|
| `az-identity-check.sh` | who am I — active subscription / tenant / user / cloud (`az account show`, `az account list`, `az cloud show`); prints no token |
| `az-config-audit.sh` | local config + env anti-patterns — `az version`, effective config, extensions, telemetry/dynamic-install/default-output, `AZURE_CLIENT_SECRET`-in-env smell |
| `az-resource-inventory.sh` | read-only estate + `--query` demo — subscriptions, resource groups, `az resource list` shaped with a multiselect hash |

---

## ANTI-PATTERNS (flag in review)

| Anti-pattern | Why it's bad | Fix |
|--------------|--------------|-----|
| `AZURE_CLIENT_SECRET=…` in a repo, `.env`, tfvars, or CI secret | long-lived credential leak | managed identity / federated OIDC / certificate |
| `az login -u user -p pass` in automation | ROPC is dead under mandatory MFA | SP / MI / OIDC |
| Echoing/logging `az account get-access-token` output | it's a live Bearer credential | read only `--query expires_on`; use `--output none` |
| `az ad sp create-for-rbac` with no `--scopes` (or Owner at root) | over-broad blast radius | least-privilege `--role` + resource-scoped `--scopes` |
| Parsing `-o table` in a script | drops nested objects + `id`/`type`/`etag`, layout-oriented | `-o tsv` + `--query [].[a,b]`, or `-o json` + `jq` |
| Relying on `-o tsv` field order without `--query` | no ordering guarantee | pin with a multiselect list `[].[name,location,id]` |
| Double quotes inside a JMESPath predicate | returns empty output | single quotes / backticks (`[?name=='web']`) |
| `sleep 30 && az …` waiting for a resource | no failure semantics | `az <resource> wait --created/--custom …` |
| Telemetry + survey prompts left on in CI | log noise, brittle parsing | `core.collect_telemetry=no`, `--only-show-errors` |
| Assuming a public-cloud token works in Azure Gov/China | isolated endpoints | `az cloud set --name …` **then** `az login` |
| Hardcoding a CLI version in prose/docs | releases are monthly | install latest + `az upgrade`; pin only in CI Docker |
| `AZURE_CLI_DISABLE_CONNECTION_VERIFICATION=1` to fix a proxy | disables TLS entirely | append the CA to `REQUESTS_CA_BUNDLE` |
| Concurrent `az` runs sharing one `~/.azure` | MSAL token-cache corruption | per-script `AZURE_CONFIG_DIR` |

---

## VERIFICATION CHECKLIST (pre-commit, pre-merge)

- [ ] No long-lived SP secret introduced; identity is managed identity / OIDC / (scoped) SP.
- [ ] `create-for-rbac` calls carry `--role` **and** resource-scoped `--scopes`.
- [ ] No `az account get-access-token` output echoed/logged; secret-returning commands use `--output none`.
- [ ] `-o json`/`-o tsv` (with `--query` multiselect) in scripts; `-o table` only in interactive examples.
- [ ] `--query` predicates use single quotes; backtick literals escaped for the target shell.
- [ ] `--only-show-errors` + telemetry off in every CI invocation.
- [ ] Long-running ops use `--no-wait` + `az … wait`, not `sleep` loops.
- [ ] `az account show` runs right after credential setup in any new workflow.
- [ ] Sovereign-cloud work does `az cloud set` before `az login`.
- [ ] CLI pinned only in CI (Docker `:<ver>-azurelinux3.0`); prose uses latest + `az upgrade`.
- [ ] Concurrent scripts isolate `AZURE_CONFIG_DIR`.

---

## SUBAGENT ORCHESTRATION — signal → agent

| Goal or signal | Agent |
|---|---|
| "which login method?", SP/MI/OIDC, `create-for-rbac` scoping, subscriptions/tenants/clouds | `azure-cli-auth-identity` |
| `--query`/JMESPath shaping, `-o` format choice, tsv/table gotchas, scripted extraction | `azure-cli-query-output` |
| `az config` + `AZURE_*` env surface, defaults, extensions, install/upgrade, proxy/telemetry | `azure-cli-config-extensions` |
| Wiring `az` into GitHub Actions/Azure Pipelines/Makefiles, OIDC login, waiters, exit codes | `azure-cli-ci-automation` |
| Azure MCP Server setup + MCP-vs-`az` decision, `az find`/`interactive`/`next`, `az rest` | `azure-cli-mcp-and-discovery` |

---

## REFERENCES (treat as source of truth — versions move monthly, verify against Learn)

- Azure CLI docs hub — `https://learn.microsoft.com/en-us/cli/azure/`
- Get started — `https://learn.microsoft.com/en-us/cli/azure/get-started-with-azure-cli`
- Output formats — `https://learn.microsoft.com/en-us/cli/azure/format-output-azure-cli`
- Query (`--query`/JMESPath) — `https://learn.microsoft.com/en-us/cli/azure/use-azure-cli-successfully-query`
- Configuration + env vars — `https://learn.microsoft.com/en-us/cli/azure/azure-cli-configuration`
- Authentication — `https://learn.microsoft.com/en-us/cli/azure/authenticate-azure-cli`
- Manage subscriptions — `https://learn.microsoft.com/en-us/cli/azure/manage-azure-subscriptions-azure-cli`
- Install — `https://learn.microsoft.com/en-us/cli/azure/install-azure-cli`
- Extensions overview — `https://learn.microsoft.com/en-us/cli/azure/azure-cli-extensions-overview`
- Command reference index — `https://learn.microsoft.com/en-us/cli/azure/reference-index`
- Source repo (core) — `https://github.com/Azure/azure-cli` · extensions — `https://github.com/Azure/azure-cli-extensions`
- `azure/login` GitHub Action (OIDC) — `https://github.com/Azure/login`
- Azure MCP Server — `https://learn.microsoft.com/en-us/azure/developer/azure-mcp-server/` · repo `https://github.com/microsoft/mcp/tree/main/servers/Azure.Mcp.Server`
- JMESPath spec — `https://jmespath.org/`

When in doubt, run `az <group> <command> --help` (or `az find`) *before* asking — the
per-command reference is the same content the CLI ships with.
