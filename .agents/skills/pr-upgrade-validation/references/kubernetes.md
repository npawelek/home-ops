# Kubernetes upgrades (`ghcr.io/siderolabs/kubelet`)

Read this when a PR bumps `kubernetesVersion` in `talos/topf.yaml`. Renovate labels a Kubernetes
minor (`v1.36.x` → `v1.37.x`) as `minor`, but it is a **lifecycle upgrade**: treat it as a major.
Kubernetes minors remove APIs, feature gates, flags and metrics, flip defaults, and have no supported
minor downgrade. A mistake therefore has to be fixed by rolling forward. The `siderolabs/kubelet`
release notes are empty compare links, so all evidence comes from upstream and from this cluster.

A patch bump inside the same minor stays on the normal baseline. Check only the upstream patch notes
(step 2) and the Talos bound (step 1).

Merging changes only `topf.yaml`. Nothing rolls out until `task talos:upgrade-k8s-safe` runs, which
calls `talosctl upgrade-k8s` and then upgrades kubelets node by node.

## Procedure

1. **Talos bound.** Read `talosVersion` from `talos/topf.yaml` on **main**, since the Renovate branch
   can be stale. Then read the min/max for that Talos minor:
   ```bash
   mise x -- gh api "repos/siderolabs/talos/contents/pkg/machinery/compatibility/talos1NN?ref=<talosVersion>" --jq '.[].name'
   # read the .go file listed: MinimumKubernetesVersion / MaximumKubernetesVersion
   mise x -- gh api "repos/siderolabs/talos/contents/pkg/machinery/constants/constants.go?ref=<talosVersion>" \
     --jq '.content' | base64 -d | grep -E 'DefaultKubernetesVersion'
   ```
   If the target is above `MaximumKubernetesVersion`, the verdict is DO NOT MERGE until Talos is bumped.
2. **Upstream changelog.** Download `CHANGELOG/CHANGELOG-1.<old>.md` and `CHANGELOG-1.<new>.md`
   from `kubernetes/kubernetes` (`gh api -H "Accept: application/vnd.github.raw"`) into the scratchpad.
   Cover every release in range: the later patches of the old minor, `.0`, and each new patch. Read
   **Urgent Upgrade Notes** in full, plus the Deprecation and API Change sections. Grep the rest for
   `removed|no longer|locked|deprecated|default`, keeping removed feature gates, flags, metrics and
   API versions, and changed defaults.
3. **Check each item against this cluster.** An item applies only if the repo or the live cluster
   uses what it touches:
   - Talos patches (`talos/all`, `control-plane`, `worker`, `node/*`): `feature-gates`, `extraArgs`,
     kubelet config keys, kube-proxy (disabled; Cilium replaces it).
   - The rendered kubelet config, which includes gates Talos sets itself:
     `mise x -- talosctl -n <worker-ip> read /etc/kubernetes/kubelet.yaml`
   - SELinux items: `talosctl get securitystate` (nodes run `enabled, permissive`), pods with
     `seLinuxOptions`, and `kubectl get csidriver -o custom-columns=N:.metadata.name,S:.spec.seLinuxMount`.
   - Removed metrics: grep `kubernetes/`, `terraform/` and `bootstrap/`.
   - Removed API versions: list what the apiserver serves (`kubectl get --raw /apis/<group>`) and grep the repo.
4. **Live use of removed APIs.** Query every control plane, because the metric is per-apiserver:
   ```bash
   for ip in 192.168.0.27 192.168.0.28 192.168.0.29; do
     mise x -- kubectl get --raw /metrics --server https://$ip:6443 | grep '^apiserver_requested_deprecated_apis'
   done | sort -u
   ```
   Any series with `removed_release="1.<new>"` blocks the upgrade until that client is fixed.
5. **Chart `kubeVersion` constraints.** helm-controller refuses to install or upgrade a chart whose
   `kubeVersion` excludes the cluster. Read the constraint from each deployed release, printing only
   chart metadata, because release secrets also hold rendered values:
   ```bash
   mise x -- kubectl get secret -A -l owner=helm,status=deployed -o json \
     | jq -r '.items[] | "\(.metadata.namespace) \(.data.release)"' \
     | while read ns rel; do echo "$rel" | base64 -d | base64 -d | gunzip \
       | jq -r --arg ns "$ns" '"\($ns)/\(.name) \(.chart.metadata.kubeVersion // "-")"'; done \
     | grep -E '<|\^|~'
   ```
6. **Ecosystem compatibility.** List what owns CRDs (`kubectl get crd -o json | jq -r '.items[].spec.group' | sort | uniq -c`)
   and the running image tags. For each controller, prefer an official matrix at the **running** tag:

   | Component | Where the matrix lives |
   |---|---|
   | Cilium | `cilium/cilium` `Documentation/network/kubernetes/compatibility.rst?ref=v<tag>` (and `ref=main` for the next release) |
   | CloudNativePG | `cloudnative-pg/cloudnative-pg` `docs/src/supported_releases.md` (Supported vs "Tested, but not supported") |
   | Envoy Gateway | `envoyproxy/gateway` `site/content/en/news/releases/matrix.md` |
   | cert-manager | `cert-manager/website` `content/docs/releases/README.md` |
   | Flux | `fluxcd/flux2` release notes at the running FluxInstance version, under "Kubernetes compatibility" |
   | Longhorn | `longhorn/longhorn` release notes and install docs state a minimum only, so they are not a matrix. Also check client-go on `longhorn-manager` `v1.<minor>.x` vs `master` to see which release moves to the target |

   For everything else (MetalLB, NFD, external-dns, trust-manager, OTel operator, tofu-controller,
   dragonfly-operator, llmkube, the Intel GPU DRA driver, kube-state-metrics, metrics-server, Reloader),
   read `k8s.io/client-go` from `go.mod` at the running tag
   (`gh api -H "Accept: application/vnd.github.raw" "repos/<owner>/<repo>/contents/go.mod?ref=<tag>"`).
   If a `replace` directive covers client-go, the `replace` version is what gets built, not the
   `require` line. Classify each one:
   - ✓: the target is named in an official matrix, or the component is built with client-go `v0.<new>`.
   - ⚠️ untested: everything else. That includes a minimum-only statement (">= 1.34"), a matrix
     that stops below the target, and client-go `v0.<new-1>`. One minor behind is within
     client-go's supported skew, so for a peripheral app operator, note it and move on. For a core
     component (CNI, storage, Flux, cert-manager, Gateway), it means the vendor has not tested the
     target, and the report says so.
   For every ⚠️, search the project's issues for the target version and say whether a newer release
   or branch moves to it.
   An unlisted target is "untested", not "broken". Weigh it by how central the component is: the CNI
   (Cilium) and storage (Longhorn) matter more than a single app operator.
7. **Community signal.** Check whether `onedr0p/cluster-template` already runs the target, and on
   which Cilium version:
   ```bash
   mise x -- gh api -H "Accept: application/vnd.github.raw" repos/onedr0p/cluster-template/contents/template/config/talos/topf.yaml.j2 | grep -A1 kubelet
   mise x -- gh api -H "Accept: application/vnd.github.raw" repos/onedr0p/cluster-template/contents/template/config/kubernetes/apps/kube-system/cilium/app/ocirepository.yaml.j2 | grep tag:
   mise x -- gh api "repos/onedr0p/cluster-template/commits?path=template/config/talos/topf.yaml.j2&per_page=10" --jq '.[] | "\(.commit.committer.date[0:10]) \(.commit.message | split("\n")[0])"'
   ```
   A matching Talos + Kubernetes + Cilium combination that has run there for weeks is supporting
   evidence. It does not replace steps 3 to 6.

## Risk

The baseline is 🔴 HIGH for every Kubernetes minor, whatever Renovate's label says. The
recommendation follows from what you find:
- **DO NOT MERGE**: the target is outside the Talos bound, a live client uses an API removed in the
  target, a chart `kubeVersion` excludes it, or an `ACTION REQUIRED` item applies and is not yet fixed.
- **REVIEW REQUIRED**: a core component (CNI, storage, Flux, cert-manager, Gateway) is ⚠️, or an
  applicable item needs a repo change that can land with the PR.
- **SAFE TO MERGE**: none of the above. Say so plainly, and still list the post-upgrade checks.

## Report addition

Add these blocks under the Kubernetes component in the Stage 6 report:

```
**Talos bound:** Talos <talosVersion> supports <min> – <max> (default <default>) ✓

**Upgrade notes vs this cluster:**

| Upstream item | Applies? |
|---|---|
| ACTION REQUIRED: SELinuxMount GA | nodes permissive; only cilium has seLinuxOptions (hostPath only); longhorn seLinuxMount=false → no ✓ |

**Ecosystem compatibility:**

| Component | Running | Evidence | Status |
|---|---|---|---|
| Cilium | 1.20.5 | matrix 1.33–1.36; main lists 1.37; cluster-template runs it | ⚠️ untested |
| MetalLB | 0.16.2 | client-go v0.37.1 | ✓ |

**Post-upgrade checks** (after `task talos:upgrade-k8s-safe`):
- `mise x -- kubectl get nodes -o wide`: every kubelet is on the target version
- Cilium DaemonSet and operator Ready; `cilium status` healthy on a worker
- `flux get ks -A` and `flux get hr -A`: all Ready, no new failures
- the deprecated-API metric from step 4 is unchanged
```
