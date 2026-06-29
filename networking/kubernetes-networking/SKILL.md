---
name: kubernetes-networking
description: >-
  MUST USE when working on the **Kubernetes networking plane** — the pod network
  model, the **CNI**, Services / kube-proxy / DNS, and especially **Calico** as
  the CNI (architecture, dataplanes, IPAM, BGP, encapsulation, and Calico's
  network-policy data model). This is the *how the network works and how Calico
  implements it* skill — distinct from operational debugging and from security
  strategy. Use for — the **IP-per-pod / no-NAT model** and the four networking
  problems (container-to-container via the pause/sandbox netns, pod-to-pod
  intra/inter-node, pod-to-Service, external-to-Service); the **CNI** spec
  (kubelet → CRI → runtime → CNI `ADD`/`DEL`, IPAM plugins, `/etc/cni/net.d`
  conflist chaining, `/opt/cni/bin`); **Services & kube-proxy** (ClusterIP /
  NodePort / LoadBalancer / ExternalName / headless, EndpointSlices, the
  iptables / IPVS / nftables proxy modes, Service VIP vs pod IP); **CoreDNS** (FQDN,
  `ndots:5`, `dnsPolicy`) and **dual-stack**; **Calico architecture** (`calico-node`
  = Felix / BIRD / confd, Typha, calico-apiserver, kube-controllers, the
  Kubernetes-API datastore) and **dataplanes** (standard iptables, **eBPF**
  kube-proxy-free + DSR + source-IP, nftables, VPP); **install** via the **Tigera
  operator** (`Installation`, `operator.tigera.io/v1`, `linuxDataplane`) +
  `calicoctl`; **IPAM** (`IPPool` cidr/blockSize/nodeSelector/natOutgoing, Calico
  IPAM vs host-local, block affinity + borrowing + `strictAffinity`, pod
  annotations `cni.projectcalico.org/ipv4pools` / `ipAddrs`); **BGP**
  (`BGPConfiguration` node-to-node mesh vs route reflectors at scale, `BGPPeer`
  global/per-node/ToR peering, advertising `serviceClusterIPs` /
  `serviceLoadBalancerIPs` with `externalTrafficPolicy`); **encapsulation**
  (VXLAN vs IP-in-IP vs no-encap native routing, CrossSubnet, MTU, cloud
  constraints); and **Calico policy mechanics** (`NetworkPolicy` /
  `GlobalNetworkPolicy` `projectcalico.org/v3`, `action` Allow/Deny/Log/Pass,
  numeric `order`, EntityRule selectors, **tiers**, `HostEndpoint`,
  `GlobalNetworkSet`). Triggers on phrases — "kubernetes networking", "CNI", "pod
  networking", "calico", "calicoctl", "IP pool", "IPAM", "BGP", "route reflector",
  "VXLAN", "IPIP", "eBPF dataplane", "kube-proxy", "EndpointSlices",
  "GlobalNetworkPolicy", "advertise service IP", "encapsulation", "overlay
  network". Triggers on file patterns — `IPPool` / `BGPPeer` / `BGPConfiguration`
  / `Installation` (operator.tigera.io) / `FelixConfiguration` /
  `projectcalico.org/v3` `NetworkPolicy`/`GlobalNetworkPolicy`/`HostEndpoint` YAML,
  CNI `*.conflist`. To **debug** a broken cluster (service-not-reachable, DNS
  latency) see `kubernetes-operations` (Phase H); for **network security
  strategy** (zero-trust, microsegmentation threat model) see `kubernetes-security`
  (Phase F) — this skill owns the *mechanics & data model*, that one owns the
  *what-to-allow & why*. Authored as a Distinguished Network Engineer's playbook —
  know the packet path, choose dataplane + encapsulation deliberately, prefer
  native routing when the fabric allows.
license: BSD-3-Clause
compatibility: opencode
metadata:
  domain: networking
  pattern: cni-dataplane
  platform: kubernetes
  cni: calico
  surfaces: network-model, cni, services-proxy-dns, calico-architecture, ipam, bgp, encapsulation, calico-policy, troubleshooting
  use_cases: cluster-networking-design, cni-selection, calico-operations, bgp-routing
---

# Kubernetes Networking & Calico

You are a Distinguished Network Engineer working on the **Kubernetes networking
plane**: how the pod network actually works, and how **Calico** implements it as
a CNI. This skill is about the *mechanics and data model* — the packet path, the
CNI contract, Calico's architecture, IPAM, BGP, encapsulation, and Calico's
policy CRDs.

> **Scope boundary.** This is the *how-the-network-works + how-Calico-implements-it* skill.
> - **Debug** a live network fault (service unreachable, DNS latency, stuck LoadBalancer) → `kubernetes-operations` (Phase H owns the runbooks: `iptables-save`, `nsenter`, `dig`, endpointslice triage).
> - **Network security strategy** (zero-trust, microsegmentation, threat model, *what to allow and why*) → `kubernetes-security` (Phase F). This skill owns the policy *engine mechanics & data model*; that one owns the *strategy*.
> For exact field specs cite **docs.tigera.io/calico/latest** and **kubespec.dev**; confirm against your cluster (Calico version + edition matter).

> **Edition & version note.** Calico ships **Open Source** plus commercial
> **Enterprise / Cloud** editions — features differ (see the OSS-vs-Enterprise
> callouts below; getting this wrong ships a config a user can't run). Don't pin a
> Calico release number in prose — cite `…/calico/latest` and verify on the cluster.

---

## CORE PRINCIPLES (NON-NEGOTIABLE)

1. **The model is IP-per-pod, no-NAT.** Every pod has a unique, cluster-routable
   IP; pods reach pods on any node without NAT; a pod sees its own IP as others
   see it. The network is **flat by default** — isolation is layered on with
   policy, not topology.
2. **The CNI is the contract.** Kubernetes defines the model; a CNI plugin
   fulfills it. kubelet never networks a pod directly — it goes kubelet → CRI →
   runtime → CNI `ADD`. Know where that boundary is.
3. **Choose dataplane and encapsulation deliberately.** iptables vs eBPF vs
   nftables, and VXLAN vs IP-in-IP vs no-encap, are design decisions with real
   performance, compatibility, and cloud constraints — not defaults to accept
   blindly.
4. **Prefer native routing (no-encap) when the fabric allows it.** Overlay is for
   when you can't route pod CIDRs on the underlay; it costs CPU and MTU. Don't
   encapsulate by reflex.
5. **Know the packet path before you change it.** Same-node vs cross-node
   pod-to-pod, and pod-to-ClusterIP, each take a specific path. Reason about it
   before touching IP pools, BGP, or the dataplane.
6. **Policy is identity/label-based, evaluated in order.** Calico policy selects
   on labels, has explicit `action` and numeric `order`, and (with tiers) a
   deterministic evaluation pipeline — not the additive-allow-only model of native
   NetworkPolicy.
7. **Respect blast radius on host-level changes.** A `HostEndpoint`, a BGP-mesh
   change, or an encapsulation switch can sever the cluster. Stage them; keep
   failsafes.

---

## THE KUBERNETES NETWORK MODEL

**Four requirements** (the contract every CNI fulfills): (1) every pod gets a
unique cluster-wide IP; (2) pods communicate across nodes **without NAT** (real
pod IPs end to end); (3) node agents (kubelet, etc.) can reach pods on their node;
(4) a pod sees its own IP consistently. This eliminates host port-mapping
conflicts and keeps Kubernetes CNI-agnostic.

**The four networking problems:**

| Problem | How it's solved |
|---|---|
| **container ↔ container** (same pod) | shared **network namespace** held by the **pause / sandbox container** (CRI PodSandbox); containers talk over `localhost` |
| **pod ↔ pod** | intra-node: **veth pair** + host bridge/route; inter-node: the **CNI datapath** (overlay encap *or* native BGP/cloud routes), pod IPs preserved |
| **pod ↔ Service** | stable **ClusterIP (VIP)**; kube-proxy (or the CNI) **DNATs** the VIP to a backend pod IP |
| **external ↔ Service** | NodePort / LoadBalancer / Ingress / Gateway API inbound; egress usually SNAT/masquerade to the node IP |

**Packet paths:**
- **pod→pod same node:** podA `eth0` → veth → host route/bridge → veth → podB `eth0`. No encap, no NAT.
- **pod→pod cross node:** podA → veth → host routing → CNI datapath (VXLAN/IPIP encap **or** native route) → underlay → dest node → veth → podB. Pod IPs preserved; encap only wraps for transit.
- **pod→ClusterIP:** pod → VIP hits kube-proxy-programmed rules in the host netns → **DNAT** to a chosen backend pod IP (+ conntrack for the reverse) → then the pod-to-pod path. The VIP is never on the wire past the originating node's kernel.

---

## PHASE A — CNI MECHANICS

- **The spec:** a CNCF binary+JSON contract (CNI 1.x) decoupling the runtime from
  network setup. The runtime executes the plugin **binary**, passing
  `CNI_COMMAND` + config/runtime data (container id, netns path, ifname) as JSON
  on stdin.
- **Invocation:** kubelet → **CRI** → containerd / CRI-O → CNI plugin. One pod
  creation = one **`ADD`** against the sandbox netns; `DEL` on teardown; plus
  `CHECK` / `VERSION` / `GC` / `STATUS`.
- **IPAM** is a sub-plugin: `host-local` (per-node ranges), `dhcp`, `static`, or a
  CNI-native IPAM (Calico's block allocator, Cilium's).
- **Config:** `/etc/cni/net.d/*.conflist` (runtime picks the lexicographically
  first); binaries in `/opt/cni/bin`. A `.conflist` **chains** `plugins[]` in order
  (main CNI → `portmap` for hostPort → `bandwidth` → `tuning`), each receiving the
  previous `prevResult`.
- **How a CNI plugs in:** it drops a config into `/etc/cni/net.d`, installs its
  binary, and runs a node agent (Calico's Felix, cilium-agent) that programs the
  inter-node datapath and (optionally) implements policy and **replaces kube-proxy**.

---

## PHASE B — SERVICES, kube-proxy & DNS

- **Service types:** ClusterIP (internal VIP) · NodePort (node port, default
  30000–32767) · LoadBalancer (external L4 LB) · ExternalName (DNS CNAME, no VIP) ·
  **headless** (`clusterIP: None`, DNS returns pod IPs — StatefulSets).
- **EndpointSlices** (`discovery.k8s.io/v1`, **GA in 1.21**) replaced the monolithic
  Endpoints object; kube-proxy consumes them by default (≤~100 endpoints/slice,
  with zone + ready/serving/terminating conditions).
- **kube-proxy modes:** **iptables** is the cluster **default** — DNAT VIP→backend
  via netfilter chains, random backend pick, O(n) rule traversal. **IPVS** —
  kernel hash-table O(1), **deprecated as of 1.35**. **nftables** — verdict-map
  ~O(1), **GA in 1.33** (kernel ≥ 5.13), the recommended path on modern kernels
  but **not yet the default**. (Calico's eBPF dataplane can replace kube-proxy
  entirely — Phase C.)
- **Service VIP vs pod IP** (the key distinction): the **ClusterIP** is allocated
  from the **service CIDR**, is **virtual / non-routable / stable**, and exists only
  as kernel rules that rewrite the destination — it never appears on a wire. The
  **pod IP** is allocated by the **CNI/IPAM** from the **pod CIDR**, is **real /
  routable / ephemeral**, and is the actual DNAT target.
- **CoreDNS:** Service FQDN `<svc>.<ns>.svc.cluster.local`; headless → per-pod A
  records; SRV for named ports. Pod `resolv.conf` has `search …svc.cluster.local …`
  and **`options ndots:5`** — names with < 5 dots try every search domain first
  (one-hop for `mysvc`, but `api.example.com` wastes 3 lookups → a latency
  footgun; mitigate with a trailing-dot FQDN or per-pod `dnsConfig`). `dnsPolicy`:
  `ClusterFirst` (default), `Default`, `ClusterFirstWithHostNet` (required with
  `hostNetwork: true`), `None`.
- **Dual-stack** (IPv4/IPv6) is **GA (1.23)**, default-on since 1.21:
  `ipFamilyPolicy` (`SingleStack`/`PreferDualStack`/`RequireDualStack`) +
  `ipFamilies`. **Ingress** (L7, maintenance) vs **Gateway API** (GatewayClass /
  Gateway / HTTPRoute, core GA) — implemented by a controller, not kube-proxy.

> Operational debugging of all the above (`kubectl get endpointslices`, empty-endpoint
> triage, CoreDNS latency tuning, `dig` from a pod) is **`kubernetes-operations`
> Phase H** — this skill owns the *mechanism*, that one the *runbook*.

---

## PHASE C — CALICO ARCHITECTURE & DATAPLANES

### C.1 Components
- **`calico-node`** (per-node DaemonSet) bundles: **Felix** (the core agent —
  programs kernel routes, ACLs/policy, interfaces, reports health), **BIRD** (the
  BGP client, **only in BGP mode** — distributes routes; can be a route
  reflector), and **confd** (watches the datastore, regenerates BIRD config).
- **Typha** (separate Deployment) — a datastore fan-out that holds one connection
  on behalf of all Felix clients; caches + dedupes events. **Recommended/auto for
  > ~50 nodes**; not on the data path.
- **calico-apiserver** — serves the user-facing `projectcalico.org/v3` API so you
  manage Calico resources with `kubectl`/`calicoctl`.
- **kube-controllers** (Deployment) — reconciles policy/namespace/serviceaccount/
  workloadendpoint/node controllers (e.g. cleans up IPAM on node delete).
- **Datastore:** **Kubernetes API datastore (kdd)** is default + recommended
  (Calico state as CRDs). etcd is legacy — and **unsupported with the eBPF dataplane**.

### C.2 Dataplanes (`spec.calicoNetwork.linuxDataplane` in the `Installation`)

| Dataplane | Value | Notes |
|---|---|---|
| **Linux iptables** | `Iptables` (**default**) | most mature/portable; Felix programs iptables/ipsets |
| **eBPF** | `BPF` | kube-proxy-free; see below |
| **nftables** | `Nftables` | for distros standardizing on nft |
| **VPP** | `VPP` | FD.io userspace dataplane, very high throughput |

**eBPF dataplane** (open source) replaces kube-proxy and handles Services in eBPF:
**connect-time load balancing** (DNAT avoided on the data path), **source-IP
preservation**, **DSR** (`FelixConfiguration.bpfExternalServiceMode: DSR` vs
`Tunnel`), lower latency, XDP for DoS. Enable: point Calico at the apiserver via
the `kubernetes-services-endpoint` ConfigMap → disable kube-proxy → set BPF mode
(`kubectl patch installation default --type merge -p
'{"spec":{"calicoNetwork":{"linuxDataplane":"BPF"}}}'`).

> **eBPF requirements/limits:** kernel ≥ 5.10; x86-64/arm64. **Unsupported with
> GKE, the etcd datastore, IP-in-IP overlay, and mixed eBPF/standard nodes.** Do
> not pair an enable-eBPF example with an IPIP pool.

### C.3 Install
- **Tigera operator** (recommended): a `tigera-operator` Deployment reconciling the
  **`Installation`** CR (`operator.tigera.io/v1`, named **`default`**, one per
  cluster) — `spec.calicoNetwork` (`linuxDataplane`, `ipPools[]` with
  `encapsulation`, `bgp`, MTU), `spec.cni.type` (`Calico`/`AmazonVPC`/`AzureVNET`/`GKE`).
- **Manifest install** (alternative): apply `calico.yaml`; config via
  `FelixConfiguration` / `IPPool` / DaemonSet env, not the `Installation` CR.
- **CLI:** `calicoctl` (Calico resources, IPAM, node status) and the
  `kubectl calico` plugin.

> **OSS vs Enterprise.** Core (Felix/BIRD/confd, Typha, apiserver, kube-controllers,
> CNI/IPAM, **all dataplanes incl. eBPF/nftables/VPP**, all encapsulation, BGP,
> NetworkPolicy/GlobalNetworkPolicy, `calicoctl`, the operator) is **open source**.
> **Enterprise / Cloud** add advanced observability (flow/DNS/L7 logs, packet
> capture), L7 **WAF / egress access controls**, multi-cluster federation,
> compliance/threat-defense. The same `Installation` CR drives both — the edition
> is the image set.

---

## PHASE D — IPAM & IP POOLS

Calico IPAM carves each `IPPool` (`projectcalico.org/v3`) CIDR into per-node
**blocks** (default `/26` = 64 addrs), so the node advertises **one route per
block**, not per pod.

```yaml
apiVersion: projectcalico.org/v3
kind: IPPool
metadata: { name: pool-west }
spec:
  cidr: 10.48.0.0/16
  blockSize: 26                 # IMMUTABLE after creation (v4 20–32; default /26)
  ipipMode: Never               # mutually exclusive with vxlanMode
  vxlanMode: CrossSubnet
  natOutgoing: true             # SNAT pod→external; recommended when encapsulating
  nodeSelector: zone == "west"  # which nodes draw from this pool (default all())
  # disabled, disableBGPExport (v3.21+), allowedUses, assignmentMode also available
```

- **Calico IPAM** (`calico-ipam`) does block allocation, specific-IP requests,
  pool selection, reservation, and **borrowing** (a full node borrows individual
  IPs from another node's block, with per-/32 routes) — unless
  `IPAMConfiguration.strictAffinity: true` forbids it (`maxBlocksPerHost` default 20).
  **host-local** IPAM (static per-node `podCIDR`, e.g. GKE) has none of these.
- **Multiple pools / topology:** label nodes, set `nodeSelector` per pool. **Every
  node must be selected by at least one pool** or its pods get no IP. Existing pods
  keep their IPs; only new pods use new pools.
- **Per-pod / per-namespace assignment** (annotations, set **at pod creation**,
  require Calico IPAM; **precedence:** annotation > CNI config > pool `nodeSelector`):
  - `cni.projectcalico.org/ipv4pools: '["pool-west"]'` — restrict to named pools (pod or namespace; pod wins).
  - `cni.projectcalico.org/ipAddrs: '["10.48.0.10"]'` — request a specific free in-pool IP.
- Read-only IPAM resources: `IPAMBlock` (a block's allocations), `BlockAffinity`
  (block↔node), `IPAMHandle` (release all IPs for a workload together). `IPReservation`
  carves out never-auto-assigned IPs. (Confirm exact `IPAMBlock` fields on the live ref.)

---

## PHASE E — BGP & ROUTING

`BGPConfiguration` (singleton `default`) holds global BGP; `BGPPeer` defines peerings.

- **Full node-to-node mesh** (`nodeToNodeMeshEnabled: true`, default; `asNumber`
  default 64512): every node iBGP-peers with every other. Good to **~100 nodes**;
  doesn't scale past. Disable **only after** configuring replacement peers, or pod
  networking breaks.
- **Route reflectors** (Calico nodes as RRs) for large clusters: annotate a node
  `projectcalico.org/RouteReflectorClusterID=<unused-ipv4>`; RRs full-mesh among
  themselves, other nodes peer with ~2 RRs (via `BGPPeer` + selectors). Cuts the
  N² peering count.
- **`BGPPeer`** — `peerIP` + `asNumber`; **omit `node` for a global peer**, set it
  (or `nodeSelector`) for per-node/per-rack peering with a **ToR / physical
  fabric** router (`nodeSelector: rack == "rack-1"`, AS-per-rack designs). Also
  `password` (TCP-MD5 via `secretKeyRef`), `ttlSecurity` (GTSM), `filters`
  (`BGPFilter` import/export route policy), `peerSelector` (intra-cluster).

### Advertising Service IPs over BGP
```yaml
apiVersion: projectcalico.org/v3
kind: BGPConfiguration
metadata: { name: default }
spec:
  serviceClusterIPs:      [{ cidr: 10.96.0.0/16 }]   # make ClusterIPs routable externally
  serviceLoadBalancerIPs: [{ cidr: 192.0.2.0/24 }]   # Calico as the LB data path (no external LB)
```
- **`externalTrafficPolicy: Cluster`** (default) → all nodes advertise the whole
  CIDR; **ECMP** across nodes, source IP SNAT'd. **`Local`** → only nodes with a
  backing pod advertise a **/32**; preserves client source IP, no extra hop —
  needs upstream **BGP multipath/ECMP**. Exclude control-plane nodes with
  `node.kubernetes.io/exclude-from-external-load-balancers=true`. Use cases: on-prem
  ingress without a hardware LB, directly routable services.

---

## PHASE F — ENCAPSULATION: OVERLAY vs NATIVE

Set per `IPPool` (`ipipMode` / `vxlanMode`: `Always` | `CrossSubnet` | `Never`).

| Mode | When | Needs BGP? | Notes |
|---|---|---|---|
| **No-encap (native)** | fabric can route pod CIDRs (BGP to ToR, or single subnet) | yes (or flat L2) | lowest overhead; unlocks service-IP advertisement |
| **IP-in-IP (IPIP)** | cross-subnet, fabric can't route pod IPs, IPIP allowed | yes (route distribution) | **IPv4 only**; ~20-byte overhead |
| **VXLAN** | IPIP/BGP blocked (e.g. **Azure**), minimal underlay deps | **no** (Felix programs FDB) | ~50-byte overhead; simplest in restrictive clouds |
| **CrossSubnet** (either) | L3 fabric, same-subnet perf matters | partial | native within a subnet, encapsulate only across |

**Decision drivers:** prefer **native** when you control/peer the fabric (Principle
4). **Cloud constraints break native routing** (source/dest checks): **AWS** →
VXLAN overlay (or AWS VPC CNI); **Azure** → overlay (native only via Azure CNI);
**GCP** pure-L3 doesn't support cross-subnet overlay. **MTU:** encap lowers
effective MTU (VXLAN ≈ −50, IPIP ≈ −20; WireGuard/IPv6 more) — set
`calicoNetwork.mtu`. **Switching encapsulation on a live cluster disrupts existing
connections.** `natOutgoing: true` is recommended whenever you encapsulate.

---

## PHASE G — CALICO POLICY MECHANICS (the data model)

> This phase is the policy **engine mechanics** — how Calico *evaluates* policy.
> For the *strategy* (zero-trust, microsegmentation, what to allow and why) see
> **`kubernetes-security` Phase F**. Author against **`projectcalico.org/v3`** —
> not the legacy `crd.projectcalico.org/v1` some blogs show.

Calico's `NetworkPolicy` (namespaced) and `GlobalNetworkPolicy` (cluster-wide, also
covers host endpoints) are a **superset** of native NetworkPolicy:

```yaml
apiVersion: projectcalico.org/v3
kind: NetworkPolicy
metadata: { name: redis-allow, namespace: app }
spec:
  selector: service == 'redis'        # rich selector expressions, not just podSelector
  order: 100                          # FLOAT precedence — LOWEST applied first
  types: [Ingress]
  ingress:
    - action: Allow                   # explicit Allow | Deny | Log | Pass
      source:
        selector: service == 'nodejs'
        namespaceSelector: module == 'prometheus'
      destination:
        ports: [6379]
```

- **What it adds over native NP:** explicit **`action`** (`Allow`/`Deny`/`Log`/**`Pass`**);
  numeric **`order`** (deterministic precedence — native NP is additive-allow only);
  rich **`selector`** language (`service == 'x'`, `all()`, `has(label)`, `k in {…}`,
  `&&`/`||`/`!`); `serviceAccountSelector`; richer match (`protocol`/`notProtocol`
  incl. ICMP/SCTP, port ranges, `nets`/`notNets`); and host-traffic fields.
- **EntityRule** (`source`/`destination`): `selector`/`notSelector`,
  `namespaceSelector`, `nets`/`notNets`, `ports`/`notPorts`, `serviceAccounts`,
  `services`.
- **Tiers** (`Tier` CRD) — ordered policy groups (e.g. platform → security → app →
  built-in `default`). `order` float (smallest first); `defaultAction: Deny`
  (default) | `Pass`. Evaluation: tiers ascending → policies in `order` → first
  **Allow or Deny terminates**; **`Pass`** skips the rest of the current tier and
  defers to the next.
  > **OSS gate:** tiers were historically **Enterprise-only** and are in
  > **open-source Calico only in recent releases** — verify your Calico version/edition.
- **`HostEndpoint`** — secures a node's **own** interfaces (`interfaceName`, `node`,
  `expectedIPs`, `labels`). GNP-only fields apply here: `applyOnForward` (govern
  forwarded traffic), `preDNAT` (enforce before kube-proxy DNAT), `doNotTrack`.
  > **Lockout warning:** creating a `HostEndpoint` **defaults to deny-all on that
  > interface** and can sever node access. Configure **failsafe ports in
  > `FelixConfiguration`** (`failsafeInboundHostPorts` / `…Outbound`) — SSH 22, BGP
  > 179, apiserver 6443, etcd 2379 — and a permissive GNP **before** applying it.
- **`GlobalNetworkSet` / `NetworkSet`** — labeled, reusable **CIDR** groups
  referenced by a rule's `selector`; the clean way to build egress allowlists
  (update the set, every referencing policy updates).
  > **OSS gate:** OSS network sets are **CIDR-only**. Domain-based egress
  > (`allowedEgressDomains`) and **L7 / ALP `HTTPMatch`** are **Enterprise/Cloud only**
  > — do not present them as open source.
- **`calicoctl` workflow:** `calicoctl get networkpolicy -n app -o yaml`,
  `calicoctl get globalnetworkpolicy`, `calicoctl apply -f policy.yaml`,
  `calicoctl get felixconfiguration default -o yaml`.

---

## PHASE H — OPERATIONS & TROUBLESHOOTING

- **Node / BGP status:** `calicoctl node status` (BIRD peerings: Established?),
  `calicoctl get bgppeer`, `calicoctl get bgpconfiguration default -o yaml`.
- **IPAM:** `calicoctl ipam show [--show-blocks]`, `calicoctl get ippool -o wide`,
  check every node is covered by a pool; `calicoctl ipam check` for leaks.
- **Connectivity:** confirm the dataplane (`calicoctl get felixconfiguration default`),
  routes (`ip route` shows per-block/per-pod routes), and that the right
  encapsulation is in effect; mismatched MTU after enabling overlay is a classic
  "large packets hang" symptom.
- **eBPF:** verify kube-proxy is actually removed and the
  `kubernetes-services-endpoint` ConfigMap is set before enabling BPF mode; don't
  combine with IPIP.
- **Scale:** enable **Typha** past ~50 nodes; move off node-to-node mesh to route
  reflectors past ~100.
- For *cluster-fault* debugging (service unreachable, DNS, LoadBalancer) defer to
  **`kubernetes-operations` Phase H**; for policy that's *blocking wanted traffic*
  as a security concern, **`kubernetes-security`**.

---

## ANTI-PATTERNS (each one bites)

| Anti-pattern | Why it breaks | Do instead |
|---|---|---|
| Overlay by reflex when the fabric can route pod CIDRs | needless CPU + MTU cost | native routing (no-encap) with BGP/CrossSubnet |
| Disabling node-to-node mesh without replacement peers | pod networking collapses | configure RR/ToR `BGPPeer`s first, then disable mesh |
| Running full node-to-node mesh past ~100 nodes | N² peerings, instability | route reflectors |
| Authoring policy against `crd.projectcalico.org/v1` | wrong/served API group | `projectcalico.org/v3` |
| Presenting tiers / ALP / domain-egress as OSS | Enterprise-only (or version-gated) → user can't run it | gate tiers on version; flag ALP & `allowedEgressDomains` as Enterprise |
| `HostEndpoint` without failsafes + permissive GNP | deny-all locks you out of the node | set `FelixConfiguration` failsafe ports + GNP first |
| eBPF dataplane with IPIP / etcd / on GKE | unsupported combination | VXLAN-or-native + kdd; not GKE |
| Adding pool/IP annotations to a running pod | ignored — only honored at creation | set at creation (pod/namespace) |
| Changing `blockSize` on an existing pool | immutable; rejected/ignored | create a new pool, migrate |
| Switching encapsulation on a live cluster casually | drops existing connections | plan a maintenance window |
| A node not selected by any IPPool | its pods get no IP | ensure every node matches ≥1 pool |
| Pinning a Calico version in docs/manifests as "current" | rots; edition drift | cite `…/calico/latest`; verify on cluster |

---

## PRE-DONE VERIFICATION CHECKLIST

**Model & CNI**
- [ ] Reasoned about the packet path (same-node / cross-node / ClusterIP) before changing pools, BGP, or the dataplane; CNI plug-in points (`/etc/cni/net.d`, agent) understood.

**Calico install / dataplane**
- [ ] Dataplane chosen deliberately (iptables default vs eBPF/nftables/VPP); eBPF only with supported combos (kdd, no IPIP, not GKE, kube-proxy removed); Typha past ~50 nodes.

**IPAM**
- [ ] Every node covered by an `IPPool`; `blockSize` set at creation; pool/IP annotations applied at pod creation; `strictAffinity`/borrowing intended.

**BGP / encapsulation**
- [ ] Mesh-vs-RR matches cluster size; mesh disabled only after peers exist; encapsulation matches the fabric/cloud (native preferred; VXLAN on Azure/AWS-restricted); MTU set; `natOutgoing` on when encapsulating; service-IP advertisement + `externalTrafficPolicy` deliberate.

**Policy**
- [ ] Authored against `projectcalico.org/v3`; `action`/`order` deterministic; tiers/ALP/domain-egress not assumed OSS; `HostEndpoint` paired with failsafes + a permissive GNP.

---

## REFERENCE

### CRD cheat-sheet
- **Policy** (`projectcalico.org/v3`): `NetworkPolicy`, `GlobalNetworkPolicy`, `Tier`, `HostEndpoint`, `GlobalNetworkSet`/`NetworkSet`, `NetworkSet`.
- **IPAM** (`projectcalico.org/v3`): `IPPool`, `IPReservation`, `IPAMConfiguration` + read-only `IPAMBlock`/`BlockAffinity`/`IPAMHandle`.
- **BGP** (`projectcalico.org/v3`): `BGPConfiguration`, `BGPPeer`, `BGPFilter`.
- **Felix/config:** `FelixConfiguration` (failsafes, `bpfEnabled`, `bpfExternalServiceMode`).
- **Install:** `Installation` (`operator.tigera.io/v1`).

### Encapsulation decision (one line)
fabric routes pod CIDRs → **native** · cross-subnet, IPIP ok → **IPIP/CrossSubnet** ·
cloud blocks IPIP/BGP (Azure/AWS) → **VXLAN** (no BGP needed).

### Stable anchors (verify on cluster)
EndpointSlices GA 1.21 · dual-stack GA 1.23 · kube-proxy nftables GA 1.33 (not
default) · IPVS deprecated 1.35 · eBPF kernel ≥ 5.10 · Calico policy CRDs
`projectcalico.org/v3` · `Installation` `operator.tigera.io/v1`. Don't pin a
Calico release — cite **docs.tigera.io/calico/latest**.

---

## SUBAGENT ORCHESTRATION

When this repo's networking subagents are installed (`.claude/agents/`), delegate
to the specialist; this skill is the shared contract (CORE PRINCIPLES + the
NETWORK MODEL). The subagents are **repo-scoped**.

| Surface | Subagent | Owns |
|---|---|---|
| Model + CNI + Services | `k8s-network-fundamentals` | the network model, CNI mechanics, Services/kube-proxy/EndpointSlices, CoreDNS, dual-stack |
| Calico architecture | `calico-architect` | components (Felix/BIRD/confd/Typha), dataplanes (eBPF/iptables/nftables/VPP), Tigera operator install, datastore |
| IPAM + BGP + encap | `calico-ipam-bgp` | IP pools/IPAM/borrowing, BGP peering/RR/service-IP advertisement, overlay-vs-native (model=opus for complex BGP topologies) |
| Policy mechanics | `calico-policy-author` | `NetworkPolicy`/`GlobalNetworkPolicy` data model, `action`/`order`/tiers, host endpoints, network sets |
| Troubleshooting | `calico-troubleshooter` | `calicoctl` node/BGP/IPAM status, route/MTU/connectivity, eBPF enablement, Typha scale |

For a networking build-out: `k8s-network-fundamentals` → `calico-architect` →
{`calico-ipam-bgp` | `calico-policy-author`} → `calico-troubleshooter`. Policy
*strategy* hands off to `kubernetes-security`; live fault debugging to
`kubernetes-operations`.
