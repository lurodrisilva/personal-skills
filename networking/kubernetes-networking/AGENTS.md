<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-29 | Updated: 2026-06-29 -->

# kubernetes-networking

## Purpose
Skill that guides the **Kubernetes networking plane** — the pod network model,
the CNI, Services/kube-proxy/DNS, and **Calico** as the featured CNI in depth:
architecture (Felix/BIRD/confd/Typha), dataplanes (iptables/eBPF/nftables/VPP),
IPAM (`IPPool` + borrowing), BGP (mesh / route reflectors / service-IP
advertisement), encapsulation (VXLAN/IPIP/no-encap), and Calico's network-policy
*mechanics & data model*. Owns *how the network works and how Calico implements
it*. First skill in the `networking/` domain.

## Key Files
| File | Description |
|------|-------------|
| `SKILL.md` | The skill definition — `name: kubernetes-networking`, `domain: networking`, `pattern: cni-dataplane`, `platform: kubernetes`, `cni: calico`, `surfaces: network-model, cni, services-proxy-dns, calico-architecture, ipam, bgp, encapsulation, calico-policy, troubleshooting` |

## Subdirectories
None.

## For AI Agents

### Working In This Directory
- Edit `SKILL.md` only.
- Keep the scope boundary sharp:
  - *Debug* a live network fault (service unreachable, DNS latency, stuck LoadBalancer) → `../../operations/kubernetes-operations/` (Phase H owns the runbooks).
  - *Network security strategy* (zero-trust, microsegmentation, threat model, what-to-allow & why) → `../../security/kubernetes-security/` (Phase F). This skill owns the policy **engine mechanics & data model**; that one owns the **strategy**.
- The **CORE PRINCIPLES** and the **NETWORK MODEL** are the load-bearing review
  gate. Highest-blast-radius facts to keep correct:
  - Author Calico policy against **`projectcalico.org/v3`** — **not** the legacy `crd.projectcalico.org/v1` some blogs (incl. the cited Palark post) show.
  - **OSS vs Enterprise boundary** (this skill's confabulation trap): policy **tiers** are OSS only in recent releases (version-gate them); **ALP / L7 `HTTPMatch`** and **domain-based egress (`allowedEgressDomains`)** are **Enterprise/Cloud only** — never present as OSS; OSS network sets are **CIDR-only**.
  - **eBPF dataplane is unsupported with GKE, the etcd datastore, IP-in-IP overlay, and mixed eBPF/standard nodes** — never pair an enable-eBPF example with IPIP.
  - A **`HostEndpoint` defaults to deny-all** on its interface and can lock you out of the node; failsafe ports live in **`FelixConfiguration`**, not the HostEndpoint.
  - `IPPool.blockSize` is **immutable** after creation; every node must be covered by a pool; node-to-node BGP mesh scales to ~100 nodes (then route reflectors); native routing preferred over overlay where the fabric allows.
  - `Installation` is `operator.tigera.io/v1`. Don't pin a Calico release — cite `docs.tigera.io/calico/latest`.
- The `description:` uses a `>-` YAML block scalar **on purpose** (colon- and
  backtick-dense). Keep it; re-verify `yq '.description | type'` is `!!str` after editing.

### Testing Requirements
- **`scripts/validate-skills.sh` validates this directory** (`DOMAIN_DIRS` includes
  `networking/`). It checks frontmatter, non-empty body, and even fences. Positive
  **and** negative check after structural edits: break a required field → validator
  must FAIL naming this skill; restore.

### Companion Subagents
- Orchestrated by five repo-scoped subagents in `../../.claude/agents/`:
  `k8s-network-fundamentals`, `calico-architect`, `calico-ipam-bgp`,
  `calico-policy-author`, `calico-troubleshooter`. The "Subagent Orchestration"
  table at the end of `SKILL.md` maps surfaces → agents. Rename a surface or agent
  → update both sides. Policy *strategy* hands to `kubernetes-security`; live fault
  debugging to `kubernetes-operations`.

### Common Patterns
- CORE PRINCIPLES → THE KUBERNETES NETWORK MODEL → phases (CNI mechanics →
  Services/kube-proxy/DNS → Calico architecture/dataplanes → IPAM → BGP →
  encapsulation → Calico policy mechanics → troubleshooting) → anti-patterns →
  checklist → reference → orchestration. Same authoring shape as the sibling K8s
  skills.

## Dependencies

### Internal
- `../../scripts/validate-skills.sh` — enforces the frontmatter + body + fenced-block contract.
- `../../README.md` — references this skill in the "Networking" table; rename → README update required.
- `../../.claude/agents/k8s-network-fundamentals.md` + the four `calico-*.md` agents — the companion subagents this skill delegates to.
- `../../operations/kubernetes-operations/SKILL.md` (debug / Phase H) & `../../security/kubernetes-security/SKILL.md` (policy strategy / Phase F) — cross-referenced to keep boundaries sharp.

### External
None at runtime — this is documentation. The skill *describes* Kubernetes
networking + Calico (`calicoctl`, the Tigera operator, BIRD/Felix, the CRDs) but
does not depend on them being installed in this repo. Cites
**docs.tigera.io/calico/latest** + kubernetes.io networking docs.

<!-- MANUAL: -->
