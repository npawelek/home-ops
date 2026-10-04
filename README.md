# ⛵ Cluster Template

Welcome to my template designed for deploying a single Kubernetes cluster. Whether you're setting up a cluster at home on bare-metal or virtual machines (VMs), this project aims to simplify the process and make Kubernetes more accessible. This template is inspired by my personal [home-ops](https://github.com/onedr0p/home-ops) repository, providing a practical starting point for anyone interested in managing their own Kubernetes environment.

At its core, this project leverages [makejinja](https://github.com/mirkolenz/makejinja), a powerful tool for rendering templates. By reading configuration files—such as [cluster.yaml](./cluster.sample.yaml) and [nodes.yaml](./nodes.sample.yaml)—Makejinja generates the necessary configurations to deploy a Kubernetes cluster with the following features:

- Easy configuration through YAML files.
- Compatibility with home setups, whether on physical hardware or VMs.
- A modular and extensible approach to cluster deployment and management.

With this approach, you'll gain a solid foundation to build and manage your Kubernetes cluster efficiently.

## ✨ Features

A Kubernetes cluster deployed with [Talos Linux](https://github.com/siderolabs/talos) and an opinionated implementation of [Flux](https://github.com/fluxcd/flux2) using [GitHub](https://github.com/) as the Git provider, [sops](https://github.com/getsops/sops) to manage secrets.

- **Required:** Some knowledge of [Containers](https://opencontainers.org/), [YAML](https://noyaml.com/), and [Git](https://git-scm.com/).
- **Included components:** [flux](https://github.com/fluxcd/flux2), [cilium](https://github.com/cilium/cilium), [cert-manager](https://github.com/cert-manager/cert-manager), [spegel](https://github.com/spegel-org/spegel), [reloader](https://github.com/stakater/Reloader), [envoy-gateway](https://github.com/envoyproxy/gateway), and [external-dns](https://github.com/kubernetes-sigs/external-dns).

**Other features include:**

- Dev env managed w/ [mise](https://mise.jdx.dev/)
- Workflow automation w/ [GitHub Actions](https://github.com/features/actions)
- Dependency automation w/ [Renovate](https://www.mend.io/renovate)
- Flux `HelmRelease` and `Kustomization` diffs w/ [flate](https://github.com/home-operations/flate)

Does this sound cool to you? If so, continue to read on! 👇

## 🚀 Let's Go!

There is **1 prerequisite** and **5 stages** outlined below for completing this project.

### Prerequisites - Network (PXE) Boot

UniFi remains broken because it **doesn't support proper PXE configuration via the UI**. In order to use UniFi as the primary DHCP, and enable network boot, you must configure it exclusively from the UI. Below is a reference configuration for booting across differing types of clients:

```sh
ssh udmp

cat << EOF > /run/dnsmasq.dhcp.conf.d/pxe.conf
# dnsmasq configuration for netboot.xyz
# PXE Server: 192.168.0.9
#
dhcp-boot=netboot.xyz.kpxe,,192.168.0.9

dhcp-vendorclass=BIOS,PXEClient:Arch:00000
dhcp-vendorclass=UEFI32,PXEClient:Arch:00006
dhcp-vendorclass=UEFI,PXEClient:Arch:00007
dhcp-vendorclass=UEFI64,PXEClient:Arch:00009

dhcp-boot=net:UEFI32,netboot.xyz.efi,,192.168.0.9
dhcp-boot=net:BIOS,netboot.xyz.kpxe,,192.168.0.9
dhcp-boot=net:UEFI64,netboot.xyz.efi,,192.168.0.9
dhcp-boot=net:UEFI,netboot.xyz.efi,,192.168.0.9
EOF

# Bounce dnsmasq
kill $(cat /run/dnsmasq-main.pid)
```

> [!TODO]
> Still need to determine persistence on UniFi as this will reset upon reboot or UI changes.

#### Custom Talos PXE Boot

This repo includes custom iPXE configurations for netboot.xyz with hardware-specific Talos builds:

1. **Update topf.yaml with version intending to upgrade**:

2. **Generate schematics and download assets**:

   ```bash
   task ipxe:deploy
   ```

   This creates schematic IDs, updates talos-custom.ipxe, and pushes associated configs to netboot.xyz

See [ipxe/README.md](./ipxe/README.md) for detailed setup instructions.

### Stage 1: Machine Preparation

| Name      | Role   | OS    | Cores | Memory | System Disk | Data Disk  | Architecture | Vendor |
|-----------|--------|-------|-------|--------|-------------|------------|--------------|--------|
| m1        | Master | Talos | 4     | 8GB    | 256GB NVMe  | N/A        | amd64        | Intel  |
| m2        | Master | Talos | 4     | 8GB    | 256GB NVMe  | N/A        | amd64        | Intel  |
| m3        | Master | Talos | 4     | 8GB    | 256GB NVMe  | N/A        | amd64        | Intel  |
| donnager  | Worker | Talos | 4     | 64GB   | 240GB SSD   | 1TB NVMe   | amd64        | Intel  |
| hammurabi | Worker | Talos | 4     | 64GB   | 240GB SSD   | 1TB NVMe   | amd64        | Intel  |
| pella     | Worker | Talos | 20    | 64GB   | 500GB SSD   | 2TB NVMe   | amd64        | Intel  |

1. PXE boot custom Talos for all nodes.

2. Verify that all nodes are available on the network.

### Stage 2: Local Workstation

1. **Install** the [Mise CLI](https://mise.jdx.dev/getting-started.html#installing-mise-cli) on your workstation.

2. **Activate** Mise in your shell by following the [activation guide](https://mise.jdx.dev/getting-started.html#activate-mise).

3. Use `mise` to install the **required** CLI tools:

    ```sh
    mise trust
    pip install pipx
    mise install
    ```

   📍 _**Having trouble installing the tools?** Try unsetting the `GITHUB_TOKEN` env var and then run these commands again_
   📍 _**Having trouble compiling Python?** Try running `mise settings python.compile=0` and then run these commands again_

4. Install pre-commit hooks

    ```sh
    pre-commit install
    pre-commit run --all-files
    ```

5. Logout of GitHub Container Registry (GHCR) as this may cause authorization problems when using the public registry:

    ```sh
    docker logout ghcr.io
    helm registry logout ghcr.io
    ```

### Stage 3: Cluster configuration

1. Generate the config files from the sample files:

    ```sh
    task init
    ```

2. Fill out `cluster.yaml` and `nodes.yaml` configuration files using the comments in those file as a guide.

3. Template out the kubernetes and talos configuration files, if any issues come up be sure to read the error and adjust your config files accordingly.

    ```sh
    task configure
    ```

4. Push your changes to git:

   📍 _**Verify** all the `./kubernetes/**/*.sops.*` files are **encrypted** with SOPS_

    ```sh
    git add -A
    git commit -m "chore: initial commit :rocket:"
    git push
    ```

### Stage 5: Bootstrap Talos, Kubernetes, and Flux

> [!WARNING]
> It might take a while for the cluster to be setup (10+ minutes is normal). During which time you will see a variety of error messages like: "couldn't get current server API group list," "error: no matching resources found", etc. 'Ready' will remain "False" as no CNI is deployed yet. **This is a normal.** If this step gets interrupted, e.g. by pressing <kbd>Ctrl</kbd> + <kbd>C</kbd>, you likely will need to [reset the cluster](#-reset) before trying again

1. Install Talos:

    ```sh
    task bootstrap:talos
    ```

2. Push your changes to git:

    ```sh
    git add -A
    git commit -m "chore: add topf encrypted secret :lock:"
    git push
    ```

3. Install cilium, coredns, spegel, flux and sync the cluster to the repository state:

    ```sh
    task bootstrap:apps
    ```

4. Watch the rollout of your cluster happen:

    ```sh
    kubectl get pods --all-namespaces --watch
    ```

## 📣 Post installation

### ✅ Verifications

1. Check the status of Cilium:

    ```sh
    cilium status
    ```

2. Check the status of Flux and if the Flux resources are up-to-date and in a ready state:

   📍 _Run `task reconcile` to force Flux to sync your Git repository state_

    ```sh
    flux check
    flux get sources git flux-system
    flux get ks -A
    flux get hr -A
    ```

3. Check TCP connectivity to the internal gateway:

   📍 _The variable below is a placeholder._

    ```sh
    nmap -Pn -n -p 443 ${cluster_gateway_internal_addr} -vv
    ```

## 💥 Reset

> [!CAUTION]
> **Resetting** the cluster **multiple times in a short period of time** could lead to being **rate limited by DockerHub or Let's Encrypt**.

There might be a situation where you want to destroy your Kubernetes cluster. The following command will reset your nodes back to maintenance mode.

```sh
task talos:reset
```

To redeploy, you can just re-run bootstrap:

```sh
task bootstrap:talos
task bootstrap:apps
```

## 🛠️ Talos and Kubernetes Maintenance

### ⚙️ Updating Talos node configuration

> [!TIP]
> Ensure you have updated `topf.yaml` and any patches with your updated configuration. In some cases you **not only need to apply the configuration but also upgrade talos** to apply new configuration.

```sh
# Preview what the change does to every node
task talos:diff
# Apply the config to one node
task talos:apply-node HOST=? MODE=?
# e.g. task talos:apply-node HOST=pella MODE=auto
# Or apply to every node, one at a time
task talos:apply
```

`task talos:diff` exits 2 when there are changes to apply, so `task` reports it as
failed. That is the signal, not an error.

> [!IMPORTANT]
> Most config changes apply without a reboot — check `task talos:diff` output for
> "without a reboot". If a change *does* require one, do not use `task talos:apply`: it
> would roll all six nodes with only a 30s gap. Apply per node with `talos:apply-node`
> and run `task longhorn:wait-healthy` between workers, as in the upgrade section below.

`topf` renders and applies in one step, so there is no separate generate step. Use
`task talos:render` to write the generated configs to `talos/output/` for inspection —
they contain cluster secrets in plaintext, so delete them afterwards.

### ➕ Adding a new node

#### 1. PXE boot the node

Boot the machine via netboot.xyz, select the appropriate Talos build (e.g. Intel i915), and enable both **Maintenance Mode** and **Disk Wipe** before booting.

#### 2. Gather disk and network info

```sh
# List disks to identify OS disk and Longhorn data disk
talosctl get disks -n <IP> --insecure

# Wipe the Longhorn data disk if it has existing partitions
talosctl -n <IP> wipe disk <disk> --insecure # e.g. nvme0n1

# Get MAC address for network interface config
talosctl get links -n <IP> --insecure
```

#### 3. Add the node to `talos/topf.yaml`

```yaml
- host: newnode                   # update
  ip: 192.168.0.XX                # update
  role: worker                    # or control-plane
  data:
    mac: "xx:xx:xx:xx:xx:xx"      # update — selects the primary NIC
```

Hostname, the network link and the address come from `talos/all/`, which templates
them off `host`, `ip` and `data.mac`. Only the install disk needs a per-node patch.

Also add the node to the `hosts` of its build in `BUILD_CONFIGS`
(`ipxe/generate-schematics.py`), then run `task ipxe:generate`. That sets the node's image:
the most common build's schematic is the cluster-wide `schematicId`, and a node on a
different build gets its own per-node `schematicId` in `topf.yaml`. A host missing from
`BUILD_CONFIGS` makes the generator skip the `topf.yaml` update.

#### 4. Create the per-node patches

Create `talos/node/newnode/01-install.yaml`:

```yaml
machine:
  install:
    disk: /dev/sda   # update (OS disk)
```

Create `talos/node/newnode/20-longhorn-volume.yaml`:

```yaml
apiVersion: v1alpha1
kind: UserVolumeConfig
name: longhorn
provisioning:
  diskSelector:
    match: disk.dev_path == "/dev/nvme0n1"  # Longhorn data disk
  grow: true
  maxSize: 1TB
```

#### 5. Apply

`topf` dials nodes in maintenance mode too, so the same task bootstraps a new node:

```sh
task talos:apply-node HOST=newnode
```

#### 6. Verify

```sh
# Node joins the cluster
kubectl get node <hostname>

# Longhorn volume provisioned
talosctl -n <IP> get volumestatus
```

### ⬆️ Updating Talos and Kubernetes versions

> [!TIP]
> Ensure the `talosVersion` and `kubernetesVersion` in `topf.yaml` are up-to-date with the version you wish to upgrade to.

Prerequisites:
1. Validate that compatibility of talos and kubernetes versions
2. Upgrade the client tools in mise before the upgrade
3. Validate cilium compatibility with the kubernetes version being upgraded

> [!CAUTION]
> Every Longhorn volume in this cluster is `numberOfReplicas: 2` spread across three
> workers, so rebooting one worker leaves its volumes on a **single** healthy replica.
> Rebooting the next worker before the rebuild finishes can strand a volume. Always
> confirm Longhorn is fully rebuilt between worker reboots.

Rebuilds typically take **30-45 minutes** and can take longer. Rebuild time tracks actual
data over the slowest link involved — donnager and hammurabi are 2.5Gbps, pella is
10Gbps — so any rebuild touching the 2.5Gbps pair is capped there no matter how fast
pella is. pella alone holds ~420 GiB provisioned across 46 replicas. Plan the maintenance
window around that, and treat a slow rebuild as normal rather than stuck.

Upgrade Talos one node at a time, waiting for Longhorn between workers:

```sh
# Upgrade a single node (cordons and drains it first, so PDBs gate the reboot)
task talos:upgrade-node HOST=?
# e.g. task talos:upgrade-node HOST=donnager

# Then, before touching the next worker, block until every volume is rebuilt.
# Prints elapsed time and sync progress every 30s. Guard defaults to 3h; it is a
# runaway guard, not a target, so raise TIMEOUT rather than lowering it.
task longhorn:wait-healthy
# e.g. task longhorn:wait-healthy TIMEOUT=21600 INTERVAL=60

# Inspect robustness, replica placement and provisioned size per node at any time
task longhorn:status
```

Only **attached** volumes are gated on. While a node is cordoned, workloads that cannot
schedule elsewhere sit `Pending` and their volumes stay `detached` with
`robustness: unknown` — those can only attach again *after* the node is uncordoned, so
waiting on them would deadlock. They are reported as `(N detached, not gated)` rather
than waited on. A `faulted` volume fails the task immediately, since waiting cannot
recover it.

Control-plane nodes (m1/m2/m3) hold no Longhorn replicas — Longhorn only manages the
three workers — so they need no wait between them; only etcd quorum matters there.

> [!WARNING]
> `task talos:upgrade` upgrades **every** node in succession with only a 30s
> stabilization gap, which is not long enough for a Longhorn rebuild. Do not use it on
> this cluster; drive upgrades per node with `talos:upgrade-node` as above.

```sh
# Upgrade cluster to a newer Kubernetes version.
# Per node: drain (PDB-gated) -> patch kubelet -> wait Ready -> uncordon -> wait for
# Longhorn to finish rebuilding. Safe to leave unattended.
task talos:upgrade-k8s-safe
```

### Secrets

SOPs is an excellent tool for managing secrets in a GitOps workflow. However, it can become cumbersome when rotating secrets or maintaining a single source of truth for secret items.

For a more streamlined approach to those issues, consider [External Secrets](https://external-secrets.io/latest/). This tool allows you to move away from SOPs and leverage an external provider for managing your secrets. External Secrets supports a wide range of providers, from cloud-based solutions to self-hosted options.

### Storage

Leverages [Longhorn](https://github.com/longhorn/longhorn) for storage.

### Community Repositories

Community member [@whazor](https://github.com/whazor) created [Kubesearch](https://kubesearch.dev) to allow searching Flux HelmReleases across Github and Gitlab repositories with the `kubesearch` topic.
