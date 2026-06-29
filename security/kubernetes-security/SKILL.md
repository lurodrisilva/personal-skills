---
name: kubernetes-security
description: >-
  MUST USE when **securing / hardening** Kubernetes — threat-modeling a cluster,
  hardening the control plane / kubelet / etcd, encrypting secrets at rest,
  designing least-privilege RBAC and workload identity, hardening workloads
  (`securityContext`, Pod Security Admission), securing the software supply chain
  (image scanning, signing, SLSA provenance, admission policy), building
  zero-trust network microsegmentation, or running runtime threat detection. This
  is the security **discipline** skill — *why* controls exist, *how* they fail,
  and the attack chains they block — distinct from day-2 operation. Use for —
  the **4Cs** (Cloud/Cluster/Container/Code) and the Kubernetes attack surface
  (API server, etcd, kubelet, registry/supply-chain, compromised-workload →
  lateral movement → node takeover); **cluster hardening**
  (`--anonymous-auth=false`, audit logging, admission plugins, kubelet
  `--read-only-port=0` + `--authorization-mode=Webhook` + NodeRestriction); **etcd
  encryption-at-rest** (`EncryptionConfiguration` + KMS); **secrets**
  (External Secrets Operator / Vault / CSI Secret Store, no secrets in
  env/image/git, bound short-lived tokens); **RBAC** least-privilege and the
  dangerous verbs (`escalate` / `bind` / `impersonate`), `automountServiceAccount-
  Token: false`, OIDC / Entra as IdP, multi-tenancy / blast-radius; **workload
  hardening** (`runAsNonRoot`, `readOnlyRootFilesystem`, drop ALL capabilities,
  `seccompProfile: RuntimeDefault`, no `privileged`/`hostPath`/`hostNetwork`/
  `hostPID`/`hostIPC`, `allowPrivilegeEscalation: false`) and PSA
  baseline/restricted; **supply chain** (Trivy/Grype scanning + SBOM, Sigstore
  **Cosign** signing/verification + SLSA attestations, distroless + digest
  pinning); **admission policy** — in-tree **ValidatingAdmissionPolicy** (CEL) vs
  **OPA Gatekeeper** (ConstraintTemplate/Constraint, Rego) vs **Kyverno**
  (validate/mutate/generate/verifyImages) + CI policy-as-code (conftest /
  kubescape); **zero-trust networking** (default-deny ingress AND egress
  `NetworkPolicy`, **Calico** GlobalNetworkPolicy/tiers/FQDN egress, **Cilium**
  CiliumNetworkPolicy L7 + Hubble, mTLS / service mesh / SPIFFE); **runtime
  security** (**Falco** eBPF detection, **Tetragon** eBPF enforcement, drift
  prevention, CNAPP); and **CIS Benchmark** + **kube-bench** / **kubescape**.
  Ships read-only audit scripts under `tools/`. Triggers on phrases — "kubernetes
  security", "harden cluster", "CIS benchmark", "kube-bench", "etcd encryption",
  "pod security", "securityContext", "least privilege RBAC", "network policy
  default deny", "zero trust kubernetes", "microsegmentation", "cilium", "calico",
  "image signing", "cosign", "trivy", "SLSA", "OPA gatekeeper", "kyverno",
  "admission policy", "falco", "runtime security", "secrets management",
  "threat model". Triggers on file patterns — `NetworkPolicy` /
  `ValidatingAdmissionPolicy` / `ConstraintTemplate` / `ClusterPolicy` (Kyverno) /
  RBAC / `PodSecurity` / `EncryptionConfiguration` YAML, `CiliumNetworkPolicy` /
  `GlobalNetworkPolicy`, Falco rules, `cosign`/`trivy` CI steps. To **run** a
  cluster day-to-day (apply RBAC/PSA, drain, scale) see `kubernetes-operations`;
  to **build** a controller see `kubernetes-operator-golang`; for GitHub Actions
  supply-chain CI see `github-actions`; for Kong/Auth0 edge authN/authZ see
  `auth0-kong-authZ-authN`. Authored as a Distinguished Security Engineer's
  playbook — assume breach, defense in depth, least privilege, default-deny,
  verify provenance.
license: BSD-3-Clause
compatibility: opencode
metadata:
  domain: security
  pattern: defense-in-depth
  platform: kubernetes
  surfaces: threat-model, cluster-hardening, secrets, rbac-identity, workload-hardening, supply-chain-admission, network-zerotrust, runtime-threat, compliance
  use_cases: hardening, threat-modeling, supply-chain-security, zero-trust, compliance-audit
---

# Kubernetes Security

You are a Distinguished Security Engineer **securing** Kubernetes. This skill is
the security **discipline**: the threat model, *why* each control exists, *how*
controls fail, and the attack chains they block — defense in depth across the
**4Cs** (Cloud, Cluster, Container, Code).

> **Scope boundary.** This is the *secure / harden / threat-model* skill.
> - **Run a cluster day-to-day** (apply RBAC/PSA labels, `auth can-i`, drain, scale) → `kubernetes-operations` (its Phase G is operational RBAC/PSA; this skill owns the *why/how-it-fails/defense-in-depth*).
> - **Build a controller / CRD** → `kubernetes-operator-golang`.
> - **GitHub Actions supply-chain CI** (OIDC, SHA-pinning, attestations) → `github-actions`.
> - **Edge authN/authZ at a gateway** → `auth0-kong-authZ-authN`.
> For exact API field specs cite **kubespec.dev**; for canonical behavior, **kubernetes.io** security docs + the **CIS Kubernetes Benchmark**.

> **Version note.** State *behavior* (stable); don't pin a single Kubernetes minor
> or a tool release number — they rot. Confirm exact API versions and flags
> against **your cluster** (`kubectl explain`, the kube-apiserver manifest) and
> the **CIS Benchmark** for your version. Security tooling itself has been
> supply-chain-compromised before — pin tools and CI actions **by digest**.

---

## CORE PRINCIPLES (NON-NEGOTIABLE)

> Violating any of these is an automatic review failure.

1. **Assume breach.** Design so a single compromised pod, token, or node does
   **not** cascade. Every boundary is a containment boundary.
2. **Defense in depth across the 4Cs.** No single control is sufficient — Cloud,
   Cluster, Container, and Code each enforce least privilege independently.
3. **Least privilege everywhere.** RBAC verbs, capabilities, network reach,
   token scope, and mounts default to the minimum the workload provably needs.
4. **Default-deny, then allow.** Network (default-deny ingress **and** egress),
   admission (deny unless policy-passed), and RBAC (no wildcards) start closed.
5. **Identity-based, not IP-based.** Authorize on workload identity
   (ServiceAccount / SPIFFE / OIDC), not pod IPs or network location.
6. **Encrypt at rest and in transit.** etcd `EncryptionConfiguration` (ideally
   KMS) for secrets at rest; mTLS for service-to-service in transit.
7. **Shift left, enforce at admission.** Catch misconfig in CI (policy-as-code),
   then **block** at admission — runtime detection is the last layer, not the
   first.
8. **Verify provenance; trust nothing by default.** Scan and **signature-verify**
   every image; pin by digest; reject unsigned/unscanned at admission.
9. **Secrets never in env/image/git.** Use a secret store + at-rest encryption +
   short-lived bound tokens; treat any plaintext secret as already leaked.

---

## THREAT MODEL & THE 4Cs

**The 4Cs** (each layer depends on the one beneath; a broken lower layer voids
the ones above):

| Layer | Owns | Primary controls |
|---|---|---|
| **Cloud** | infra / nodes / network perimeter | cloud IAM, node OS hardening, private API endpoint, host isolation |
| **Cluster** | control plane + data plane | API-server authn/authz, etcd encryption, RBAC, audit logging, kubelet hardening, admission |
| **Container** | the running workload | image provenance, `securityContext`, capabilities, seccomp, resource limits |
| **Code** | the app | dependency scanning, no secrets in code, short-lived tokens, least-privilege design |

**Attack surface & the chains that matter:**

| Entry point | Exploit | Leads to |
|---|---|---|
| **API server** (exposed / weak RBAC) | anonymous or over-privileged access | create privileged pod → read all secrets |
| **etcd** (unencrypted / reachable) | direct read | every secret, token, and RBAC rule in cleartext |
| **kubelet** (`--read-only-port`, anonymous) | unauthenticated `exec`/logs/metrics | workload data, node foothold |
| **Registry / supply chain** | unsigned or vulnerable image | malicious code runs with the workload's identity |
| **Compromised workload** (flat network, mounted token) | lateral movement | reach other namespaces, escalate to node, exfiltrate |

**Highest-leverage misconfigurations (cause real breaches):** no etcd encryption +
reachable API server; flat network (no default-deny) enabling lateral movement;
privileged / `hostPath` / `hostNetwork` pods enabling node takeover; auto-mounted
over-privileged ServiceAccount tokens; unsigned/unscanned images. Fix these
first — they're cheap and high-impact.

---

## PHASE B — CLUSTER & NODE HARDENING + SECRETS

### B.1 API server & audit
- `--anonymous-auth=false`; no `--basic-auth-file` / `--token-auth-file` (use OIDC/webhook). Enforce TLS everywhere.
- **Audit logging**: `--audit-policy-file` + `--audit-log-path` (off-cluster). Log Metadata for all, and `RequestResponse` for `secrets`, `tokenreviews`, and `pods/exec` — the forensic trail for privilege escalation and secret access.
- **Admission plugins**: enable `NodeRestriction`, `PodSecurity`, `ResourceQuota`, `LimitRange`; never `AlwaysAdmit`.

### B.2 kubelet
- `--anonymous-auth=false`, `--authorization-mode=Webhook`, **`--read-only-port=0`** (the default 10255 leaks logs/metrics/exec unauthenticated), client-cert auth, and the **NodeRestriction** admission controller so a kubelet can only modify its own node/pods.

### B.3 etcd encryption-at-rest
etcd stores Secrets base64-encoded — **not** encrypted by default. Enable
`EncryptionConfiguration` and prefer a **KMS** provider over a local key:

```yaml
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources: ["secrets"]
    providers:
      - kms:                 # external KMS (preferred); aescbc/secretbox for local
          name: myKmsPlugin
          endpoint: unix:///var/run/kmsplugin/socket.sock
      - identity: {}         # MUST be last; allows reading pre-encryption data
```

Wire it via `--encryption-provider-config`. Existing Secrets stay readable until
**re-encrypted** (`kubectl get secrets -A -o json | kubectl replace -f -`). Keep
etcd on an isolated network, client-cert-only, with **encrypted off-cluster
backups** (a plaintext backup = full compromise).

### B.4 Secrets management
- **External store** over raw Secrets: **External Secrets Operator** (syncs from
  Vault / cloud secret managers), **HashiCorp Vault** (dynamic, leased), or the
  **CSI Secrets Store** (mounted to `tmpfs`, rotates).
- **Never** put secrets in container env (visible in `describe`, logs, crash
  dumps), in images, or in Git. Prefer **bound, short-lived** ServiceAccount
  tokens (TokenRequest) over long-lived Secret tokens.

### B.5 CIS Benchmark & kube-bench
Run **kube-bench** to score the cluster against the **CIS Kubernetes Benchmark**
(control plane, etcd, kubelet, policies); remediate FAIL items by priority. This
skill ships read-only `tools/` audit scripts for the most common findings (see
**TOOLS**).

---

## PHASE C — IDENTITY & RBAC (DEEP)

- **Least privilege:** namespace-scoped `Role` over `ClusterRole`; explicit
  `verbs` (`get,list,watch` — not `*`); never bind `cluster-admin` to a workload.
- **The dangerous verbs:** `escalate` (grant perms you don't hold), `bind`
  (attach any Role), `impersonate` (act as another user/SA), and `create` on
  `pods`/`pods/exec` (run arbitrary code) — audit these specifically; they are
  privilege-escalation primitives.
- **`auth can-i`** to verify (not assume): `kubectl auth can-i '*' '*' --as=…`.
  The `tools/rbac-audit.sh` script flags wildcard, cluster-admin, and
  dangerous-verb bindings.
- **Kill ambient authority:** `automountServiceAccountToken: false` on workloads
  that don't call the API; a mounted token is a credential an attacker inherits.
- **Identity provider:** OIDC / Entra as the IdP; you can **delegate authz** to a
  cloud RBAC system via an authorization webhook (e.g. Azure Arc's `guard`
  webhook is one managed example — see Phase H). SPIFFE/SPIRE issues
  cryptographic workload identity (X.509 SVIDs) for mesh and cross-cluster.
- **Multi-tenancy:** namespaces + RBAC + quotas + NetworkPolicy as a blast-radius
  boundary; a tenant breach must not reach another tenant.

---

## PHASE D — WORKLOAD HARDENING

**Pod Security Admission** (PSP is **removed** — PSA is the mechanism): label
namespaces with a **level** (`baseline` / `restricted`) × **mode**
(`enforce`/`audit`/`warn`). `restricted` is the goal; roll out `warn`/`audit`
first. PSA is *threat reduction* — `restricted` blocks the majority of historical
container-breakout vectors.

**`securityContext` an attacker hates:**

```yaml
securityContext:                 # pod-level
  runAsNonRoot: true
  seccompProfile: { type: RuntimeDefault }   # restricts syscalls
containers:
  - name: app
    securityContext:             # container-level
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      privileged: false
      capabilities: { drop: ["ALL"] }        # add back only what's proven needed
```

- **Never** `privileged: true`, `hostPath`, `hostNetwork`, `hostPID`, `hostIPC`,
  or extra Linux capabilities without a written justification — each is a
  node-takeover or sniffing primitive.
- **`seccompProfile: RuntimeDefault`** on the pod works **on its own** — it does
  *not* require any kubelet flag. (The kubelet `--seccomp-default` flag is a
  separate convenience that makes `RuntimeDefault` the cluster-wide default for
  pods that don't set one; you don't need it to opt a pod in.)
- **Resource limits are a security control** (DoS containment): an unbounded pod
  can starve a node. Set them; enforce with `LimitRange`/`ResourceQuota`.

---

## PHASE E — SUPPLY CHAIN & ADMISSION

### E.1 Build → registry
- **Scan** images + filesystems for CVEs and misconfig (**Trivy**, **Grype**) and
  emit an **SBOM** (CycloneDX/SPDX). Gate CI on critical findings.
- **Sign & attest** with **Sigstore Cosign** (keyless via OIDC); attach **SLSA
  provenance** attestations. Verify at admission with the **Sigstore
  policy-controller** or Kyverno `verifyImages`.
- **Minimize & pin:** distroless/minimal base, non-root, and pin by **digest**
  (`image@sha256:…`) — tags drift, digests don't.

### E.2 Admission policy — pick the right engine

| Engine | Language | Use when |
|---|---|---|
| **ValidatingAdmissionPolicy** (in-tree, CEL) | CEL | lightweight, webhook-free, native rules (require digest, block `privileged`, enforce labels) |
| **OPA Gatekeeper** | Rego (`ConstraintTemplate` + `Constraint`) | complex/stateful org-wide policy, mature ecosystem |
| **Kyverno** | YAML (`validate`/`mutate`/`generate`/`verifyImages`) | YAML-native teams, built-in **image signature verification** |

`ValidatingAdmissionPolicy` runs in-process in the apiserver (no webhook latency
or availability risk) and is the default reach for simple rules; Gatekeeper/Kyverno
for richer logic. **Mutation runs before validation.**

### E.3 Policy-as-code in CI
Catch violations at **PR time**, not deploy time: `conftest` (Rego on manifests),
`kubescape` (CIS/NSA/MITRE frameworks on manifests + cluster), Checkov. This is
the "shift left" layer feeding the admission layer.

---

## PHASE F — NETWORK ZERO-TRUST & MICROSEGMENTATION

Zero trust = never trust/always verify, identity-based policy, assume breach,
encrypt in transit. The network is **flat by default** — fix that first.

### F.1 Default-deny (ingress AND egress)

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: { name: default-deny-all, namespace: payment }
spec:
  podSelector: {}                 # every pod in the namespace
  policyTypes: [Ingress, Egress]  # egress is GA — deny it too, then allow DNS + needed flows
```

Then add explicit allows (e.g. DNS egress to CoreDNS on 53, ingress from the
`frontend` namespace only). Rules are **additive**; absence of an allow = deny.
`tools/netpol-coverage.sh` flags namespaces with workloads but no default-deny.

### F.2 Beyond native NetworkPolicy (L3/4 only)
Native NetworkPolicy can't do FQDN egress, L7, or identity — CNI policy engines
extend it:
- **Calico** — `GlobalNetworkPolicy` (cluster-wide), **policy tiers** (ordered
  evaluation), **DNS/FQDN egress**, **host endpoints** (protect nodes/VMs).
- **Cilium** — `CiliumNetworkPolicy` with **L7** (HTTP method/path, gRPC),
  **identity-based** eBPF enforcement, and **Hubble** flow observability.

### F.3 Identity & mTLS
A **service mesh** (Istio `PeerAuthentication` `mode: STRICT`, Linkerd) adds
mTLS (encryption + cryptographic workload identity) and L7 `AuthorizationPolicy`.
NetworkPolicy alone covers L3/4 isolation; add a mesh when you need
encryption-in-transit, L7 authz, or trust across untrusted networks — not by
default (it's operational weight).

### F.4 Containment
Per-namespace default-deny + tiered policies + DNS-pinned egress = a compromised
pod can't scan the cluster or exfiltrate. eBPF flow telemetry (Hubble/Calico)
detects denied/anomalous connections for incident response.

---

## PHASE G — RUNTIME SECURITY & THREAT DETECTION

Admission stops bad config from entering; **runtime** catches what gets through.

- **Falco** — eBPF/syscall **detection**: rules (condition → alert) enriched with
  pod/namespace/SA context. Detects shells in containers, writes to `/etc` or
  `/usr/bin`, unexpected egress, privilege escalation. CNCF-graduated. Route
  alerts to a SIEM (Falcosidekick).
- **Tetragon** — eBPF **enforcement**: can observe **and kill** a syscall
  in-kernel (not just alert); `TracingPolicy` CRDs, GitOps-friendly. Use for
  zero-trust runtime enforcement and drift prevention.
- **Drift prevention:** `readOnlyRootFilesystem: true` + immutable digest-pinned
  images mean the running container can't be modified; Falco/Tetragon flag
  deviation from expected behavior.
- **Incident response:** quarantine a suspect pod by applying a deny-all
  NetworkPolicy + cordoning its node, preserve it for forensics (don't just
  delete), and pull audit + flow logs.
- **CNAPP** (commercial, optional): platforms bundle scanning + admission +
  runtime + compliance with a central console + per-node agent (e.g. **Prisma
  Cloud Compute** = Console + Defender DaemonSet + admission webhook; **Aqua**,
  **Sysdig** (Falco-based), **Microsoft Defender for Containers** are peers).
  Useful at scale; the open-source stack above covers the same layers.

---

## PHASE H — MANAGED / HYBRID SECURITY (one example)

Managed and hybrid control planes share a model worth generalizing (Azure Arc is
**one** example, not the only way):

- **Outbound-only / agent connectivity:** the cluster dials out (no inbound
  ports); a reverse-proxy agent bridges API access. Reduces attack surface — lock
  egress to the required endpoints only.
- **Delegated identity & authz:** agents use **managed identity** (no stored
  credentials); a webhook (Arc's `guard`) delegates Kubernetes authz to a cloud
  RBAC + IdP (Entra) for a unified audit trail. The pattern — central OIDC IdP +
  delegated authz — generalizes to any provider.
- **Policy-as-guardrails at scale:** Azure Policy for Kubernetes (Gatekeeper
  under the hood) enforces constraints fleet-wide; **GitOps (Flux)** with
  namespaced source restrictions for config integrity; **Defender for Containers**
  for threat detection. Substitute the equivalent in your platform; the
  principles (managed identity, policy-as-code, GitOps, threat detection) are
  vendor-neutral.

---

## TOOLS

### Shipped audit scripts (`tools/`, read-only)
Read-only `kubectl` wrappers — they **only `get`/`list`**, never mutate. Treat
them as **starting points to review before running**; they need only
cluster-reader RBAC.

| Script | Flags |
|---|---|
| `tools/rbac-audit.sh` | cluster-admin bindings, wildcard verbs/resources, `escalate`/`bind`/`impersonate`, broad secret access |
| `tools/psa-coverage.sh` | namespaces missing a `pod-security.kubernetes.io/enforce` label (or not baseline/restricted) |
| `tools/netpol-coverage.sh` | namespaces with workloads but no default-deny `NetworkPolicy` |
| `tools/privileged-workloads.sh` | `privileged`, `hostPath`/`hostNetwork`/`hostPID`/`hostIPC`, missing `runAsNonRoot`, added capabilities, `allowPrivilegeEscalation` |
| `tools/image-provenance.sh` | images on mutable tags / `:latest` instead of `@sha256:` digests |

```bash
# example: review then run against the current kube-context (read-only)
less tools/rbac-audit.sh
bash tools/rbac-audit.sh
```

### External-tool playbook (the defense-in-depth stack)
End-to-end: **build** (Trivy scan + SBOM, distroless, digest pin) → **sign**
(Cosign + SLSA attestation) → **CI gate** (conftest / kubescape) → **admission**
(ValidatingAdmissionPolicy / Gatekeeper / Kyverno `verifyImages` + PSA) →
**runtime** (Falco detect / Tetragon enforce) → **compliance** (kube-bench CIS,
kubescape multi-framework). Each layer assumes the previous one can be bypassed.

---

## ANTI-PATTERNS (each one is exploitable)

| Anti-pattern | Why it's exploitable | Do instead |
|---|---|---|
| etcd Secrets unencrypted | etcd/backup read = every secret in cleartext | `EncryptionConfiguration` + KMS; encrypted off-cluster backups |
| Flat network (no NetworkPolicy) | compromised pod moves laterally cluster-wide | default-deny ingress **and** egress, then allow |
| `privileged` / `hostPath` / `hostNetwork` pods | container → node takeover / traffic sniffing | `restricted` PSA + hardened `securityContext` |
| `cluster-admin` or wildcard RBAC for a workload | token theft = full cluster | least-privilege namespaced Role; audit `escalate`/`bind`/`impersonate` |
| Auto-mounted SA token on a non-API workload | attacker inherits the credential | `automountServiceAccountToken: false` |
| Secrets in env vars / images / Git | leaked via logs, dumps, SBOM, registry | secret store + at-rest encryption + bound tokens |
| Running unsigned / unscanned images | supply-chain code execution | scan + Cosign verify at admission; pin by digest |
| `:latest` / mutable tags | silent, unauditable image drift | pin `@sha256:` digest |
| seccomp/caps left default (unconfined) | broad syscall + capability surface | `seccompProfile: RuntimeDefault`, drop `ALL` caps |
| Runtime detection as the *only* layer | first real defense is the last line | shift-left + admission-time **block**, runtime as backstop |
| Pinning a K8s minor or tool version as "current" | rots; false confidence | state behavior; verify against the live cluster + CIS Benchmark |

---

## PRE-DONE SECURITY CHECKLIST

**Cluster**
- [ ] API server: anonymous-auth off, audit policy logging secret/exec/tokenreview access off-cluster; kubelet read-only-port 0 + Webhook authz + NodeRestriction.
- [ ] etcd Secrets encrypted at rest (KMS preferred); backups encrypted + off-cluster.

**Identity**
- [ ] RBAC least-privilege; no wildcard/cluster-admin for workloads; `escalate`/`bind`/`impersonate` audited; `automountServiceAccountToken: false` where unused.

**Workload**
- [ ] PSA `restricted` (or justified baseline); `securityContext` drops ALL caps, non-root, read-only root, `seccompProfile: RuntimeDefault`, no privileged/host* ; resource limits set.

**Supply chain**
- [ ] Images scanned + SBOM; signed (Cosign) + SLSA attested; verified at admission; digest-pinned; CI policy-as-code gate.

**Network**
- [ ] Default-deny ingress **and** egress per namespace; egress/DNS scoped; mesh mTLS where in-transit encryption / L7 authz is needed.

**Runtime**
- [ ] Falco/Tetragon deployed; drift prevention (read-only root + immutable images); incident-response quarantine path; audit + flow logs to a SIEM.

---

## REFERENCE

### Defense-in-depth stack (one line)
distroless + digest pin → Trivy scan + SBOM → Cosign sign + SLSA → CI
(conftest/kubescape) → admission (ValidatingAdmissionPolicy / Gatekeeper / Kyverno
+ PSA) → network default-deny + Calico/Cilium + mesh mTLS → runtime
(Falco detect / Tetragon enforce) → CIS (kube-bench) + continuous (kubescape).

### Stable version anchors (verify against your cluster)
- **PodSecurityPolicy removed** → **Pod Security Admission** is the mechanism (PSA GA).
- **ValidatingAdmissionPolicy** (CEL, in-tree) is GA — the webhook-free option.
- **NetworkPolicy egress** is GA — default-deny egress is production-safe.
- **Falco** is CNCF-graduated; Calico/Cilium are production CNIs.
- `seccompProfile: RuntimeDefault` on a pod needs **no** kubelet flag.
- Don't hardcode tool release numbers or a single K8s minor — cite **kubernetes.io**
  security docs + the **CIS Kubernetes Benchmark** and confirm on the live cluster.

### Sources
kubernetes.io security docs · CIS Kubernetes Benchmark (kube-bench) · NSA/CISA
Kubernetes Hardening Guidance · the 4Cs model · Sigstore / SLSA · Calico & Cilium
docs · Falco / Tetragon · vendor security guidance (Red Hat, Tigera, Microsoft,
Prisma Cloud) framed as examples, not endorsements.

---

## SUBAGENT ORCHESTRATION

When this repo's security subagents are installed (`.claude/agents/`), delegate to
the specialist; this skill is the shared contract (CORE PRINCIPLES + THREAT
MODEL). The subagents are **repo-scoped** — installing only this `SKILL.md`
elsewhere will not carry them.

| Surface | Subagent | Owns |
|---|---|---|
| Cluster + secrets | `k8s-cluster-hardener` | control plane / kubelet / node hardening, etcd encryption, secrets stores, CIS / kube-bench, audit logging |
| Identity | `k8s-rbac-iam-auditor` | least-privilege RBAC, dangerous verbs, SA tokens, OIDC/Entra, multi-tenancy (owns `rbac-audit.sh`) |
| Supply chain + admission | `k8s-supplychain-admission` | scan/sign/SLSA, PSA + securityContext, ValidatingAdmissionPolicy / Gatekeeper / Kyverno, CI policy-as-code |
| Network | `k8s-network-zerotrust` | default-deny NetworkPolicy, Calico/Cilium microsegmentation, mTLS/mesh, egress control (owns `netpol-coverage.sh`) |
| Runtime | `k8s-runtime-threat` | Falco/Tetragon detection+enforcement, drift, CNAPP, incident response |

Every subagent enforces the **CORE PRINCIPLES** and reasons from the **THREAT
MODEL** (which attack chain does this control block?). Security is layered — for a
hardening engagement, run threat-model first, then all five specialists for
defense in depth.
