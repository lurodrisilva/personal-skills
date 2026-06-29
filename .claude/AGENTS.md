<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-28 | Updated: 2026-06-29 -->

# .claude

## Purpose
Repo-scoped Claude Code configuration for this skills distribution. Holds
**committed subagent definitions** that companion skills delegate to, plus
per-clone local settings that are not tracked. This is the only place in the repo
that ships first-class Claude Code artifacts other than `SKILL.md` files.

## Key Files
| File | Description |
|------|-------------|
| `settings.local.json` | Per-clone local Claude Code settings — **git-ignored** (via the user's global ignore); do not rely on it being present or commit it |

## Subdirectories
| Directory | Purpose |
|-----------|---------|
| `agents/` | Committed Claude Code subagent definitions, orchestrated by skills (see `agents/AGENTS.md`) |

## For AI Agents

### Working In This Directory
- `agents/*.md` are **tracked** and shared with everyone who clones the repo;
  `settings.local.json` is **local-only**. Don't move tracked content into the
  ignored file or vice versa.
- Subagents here are **repo-scoped**: a downstream install of a single `SKILL.md`
  does not carry them. When a skill names companion agents, those agents must
  live here to ship with the repo.

### Testing Requirements
- Not covered by `scripts/validate-skills.sh` (that validator only walks the
  skill domain directories). Validate subagent files by the rules in
  `agents/AGENTS.md` (valid YAML frontmatter, resolvable `model`, tool list).

### Common Patterns
- One subagent per file; frontmatter `name` matches the filename stem.

## Dependencies

### Internal
- `agents/` — the subagent definitions (six teams: operator-development,
  Crossplane, Dynatrace, Kubernetes-operations, Kubernetes-security,
  Kubernetes-networking).
- `../platform-engineering/kubernetes-operator-golang/SKILL.md` — drives the
  `operator-*` / `*-author` / `olm-packager` operator team.
- `../platform-engineering/crossplane/SKILL.md` — drives the `crossplane-*` team.
- `../platform-engineering/dynatrace/SKILL.md` — drives the `dynatrace-*` team.
- `../operations/kubernetes-operations/SKILL.md` — drives the Day-2 ops team
  (`k8s-workload-troubleshooter` / `k8s-cluster-operator` / `k8s-autoscaling-engineer`
  / `k8s-security-rbac` / `k8s-network-storage`).
- `../security/kubernetes-security/SKILL.md` — drives the security team
  (`k8s-cluster-hardener` / `k8s-rbac-iam-auditor` / `k8s-supplychain-admission`
  / `k8s-network-zerotrust` / `k8s-runtime-threat`).
- `../networking/kubernetes-networking/SKILL.md` — drives the networking team
  (`k8s-network-fundamentals` / `calico-architect` / `calico-ipam-bgp`
  / `calico-policy-author` / `calico-troubleshooter`).
  Each skill's "Subagent Orchestration" table maps its surfaces/phases → its agents.

### External
- Claude Code — the runtime that loads subagent definitions from `.claude/agents/`.

<!-- MANUAL: -->
