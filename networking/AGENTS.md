<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-29 | Updated: 2026-06-29 | DEEPINIT: 2026-06-29 -->

# networking

## Purpose
Networking-plane skills — the **fifth** CI-validated domain, parallel to
`coding/`, `platform-engineering/`, `operations/`, and `security/`. This domain
owns the **networking plane itself**: how the Kubernetes pod network works (the
model, the CNI, Services/kube-proxy/DNS) and how a CNI implements it (dataplane,
IPAM, routing/BGP, encapsulation, and network-policy *mechanics*). Distinct from
*operating* a cluster (debugging) and from *security strategy* (zero-trust). Each
subdirectory ships one `SKILL.md`. **This directory IS CI-validated:**
`scripts/validate-skills.sh` walks every domain in its `DOMAIN_DIRS` array —
`coding/`, `platform-engineering/`, `operations/`, `security/`, and `networking/`
— on every push and PR.

## Key Files
None at this level — all content lives in subdirectories.

## Subdirectories
| Directory | Purpose |
|-----------|---------|
| `kubernetes-networking/` | The Kubernetes networking model + **Calico** as the CNI in depth — CNI mechanics, Services/kube-proxy/DNS, Calico architecture & dataplanes (incl. eBPF), IPAM, BGP, encapsulation, and Calico policy mechanics; ships a 5-agent networking team in `../.claude/agents/` (see `kubernetes-networking/AGENTS.md`) |

## For AI Agents

### Working In This Directory
- This domain is for the **networking plane / CNI mechanics**, not debugging and
  not security strategy. Keep the boundary sharp: *debug* a live fault (service
  unreachable, DNS) → `../operations/kubernetes-operations/` (Phase H); *network
  security strategy* (zero-trust, microsegmentation threat model) →
  `../security/kubernetes-security/` (Phase F). This domain owns the *mechanics &
  data model*.
- Naming convention: descriptive kebab-case (e.g. `kubernetes-networking`).
  Directory names are stable references — `README.md` links to them.
- Networking skills state the **packet path** and *behavior*; **do not pin a CNI
  release number** or a single Kubernetes minor (they rot). For Calico, the
  **Open Source vs Enterprise/Cloud** boundary is load-bearing — never present an
  Enterprise-only feature (ALP/L7 `HTTPMatch`, domain-based egress) as OSS, and
  gate version-dependent features (policy tiers). Author Calico policy against
  **`projectcalico.org/v3`**, not the legacy `crd.projectcalico.org/v1`.

### Testing Requirements
- **`scripts/validate-skills.sh` validates this directory** (its `DOMAIN_DIRS`
  array includes `networking/`); CI runs it on every push and PR. Per `SKILL.md` it
  checks frontmatter (`name`, `description`, `license`, `compatibility`, non-empty
  `metadata`), a non-empty body, and balanced fences.
- After editing frontmatter, confirm `.description` parses as a **string**
  (`yq '.description | type'` → `!!str`); a colon-dense description needs a `>-`
  block scalar.

### Common Patterns
- `metadata:` carries `domain: networking` plus `platform:` / `cni:` / `pattern:`
  (e.g. `pattern: cni-dataplane`). Body shape: CORE PRINCIPLES → the network model
  → phases (CNI → Services/proxy/DNS → CNI architecture/dataplanes → IPAM → BGP →
  encapsulation → policy mechanics → troubleshooting) → anti-patterns → checklist →
  reference → subagent orchestration.

## Dependencies

### Internal
- `../scripts/validate-skills.sh` — validates this tree (its `DOMAIN_DIRS` includes `networking/`); CI runs it on every push and PR. **A missing domain dir is itself a validator error**, so this directory must always contain at least one valid skill.
- `../README.md` — references each skill in the "Networking" table; rename → README update required.
- `../.claude/agents/` — the companion networking subagent team (`k8s-network-fundamentals`, `calico-architect`, `calico-ipam-bgp`, `calico-policy-author`, `calico-troubleshooter`).
- `../operations/kubernetes-operations/` & `../security/kubernetes-security/` — the debug / security-strategy counterparts this domain cross-references to keep boundaries sharp.

<!-- MANUAL: -->
