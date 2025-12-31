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
- Flux `HelmRelease` and `Kustomization` diffs w/ [flux-local](https://github.com/allenporter/flux-local)

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

1. **Generate schematics and download assets**:
   ```bash
   pip install requests pyyaml
   python3 ipxe/generate-schematics.py
   ```
   This creates schematic IDs and outputs a command to download all assets.

2. **Deploy to netboot.xyz**: Copy the generated command output and run it on your netboot.xyz server to download kernel/initramfs files.

3. **Add to menu**: Copy `ipxe/talos-custom.ipxe` to your netboot.xyz menus and add a menu entry pointing to it.

See [ipxe/README.md](./ipxe/README.md) for detailed setup instructions.

### Stage 1: Machine Preparation

| Name      | Role   | OS    | Cores | Memory | System Disk | Data Disk  | Architecture | Vendor |
|-----------|--------|-------|-------|--------|-------------|------------|--------------|--------|
| m1        | Master | Talos | 4     | 8GB    | 256GB NVMe  | N/A        | amd64        | Intel  |
| m2        | Master | Talos | 4     | 8GB    | 256GB NVMe  | N/A        | amd64        | Intel  |
| m3        | Master | Talos | 4     | 8GB    | 256GB NVMe  | N/A        | amd64        | Intel  |
| karakum   | Worker | Talos | 4     | 32GB   | 120GB SSD   | 500GB NVMe | amd64        | Intel  |
| rocinante | Worker | Talos | 8     | 64GB   | 120GB SSD   | 1TB NVMe   | amd64        | AMD    |
| donnager  | Worker | Talos | 4     | 64GB   | 240GB SSD   | 1TB NVMe   | amd64        | Intel  |
| hammurabi | Worker | Talos | 4     | 64GB   | 240GB SSD   | 1TB NVMe   | amd64        | Intel  |
| pella     | Worker | Talos | 20    | 128GB  | 240GB SSD   | 2TB NVMe   | amd64        | Intel  |


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

4. Logout of GitHub Container Registry (GHCR) as this may cause authorization problems when using the public registry:

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
    git commit -m "chore: add talhelper encrypted secret :lock:"
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

## 🛠️ Talos and Kubernetes Maintenance

### ⚙️ Updating Talos node configuration

> [!TIP]
> Ensure you have updated `talconfig.yaml` and any patches with your updated configuration. In some cases you **not only need to apply the configuration but also upgrade talos** to apply new configuration.

```sh
# (Re)generate the Talos config
task talos:generate-config
# Apply the config to the node
task talos:apply-node IP=? MODE=?
# e.g. task talos:apply-node IP=10.10.10.10 MODE=auto
```

### ⬆️ Updating Talos and Kubernetes versions

> [!TIP]
> Ensure the `talosVersion` and `kubernetesVersion` in `talenv.yaml` are up-to-date with the version you wish to upgrade to.

Prerequisites:
1. Validate that compatibility of talos and kubernetes versions
2. Upgrade the client tools in mise before the upgrade
3. Validate cilium compatibility with the kubernetes version being upgraded

```sh
# Upgrade node to a newer Talos version
task talos:upgrade-node IP=?
# e.g. task talos:upgrade-node IP=10.10.10.10
```

```sh
# Upgrade cluster to a newer Kubernetes version
task talos:upgrade-k8s
# e.g. task talos:upgrade-k8s
```

## 🧹 Tidy up

Once your cluster is fully configured and you no longer need to run `task configure`, it's a good idea to clean up the repository by removing the [templates](./templates) directory and any files related to the templating process. This will help eliminate unnecessary clutter from the upstream template repository and resolve any "duplicate registry" warnings from Renovate.

1. Tidy up your repository:

    ```sh
    task template:tidy
    ```

2. Push your changes to git:

    ```sh
    git add -A
    git commit -m "chore: tidy up :broom:"
    git push
    ```

## ❔ What's next

There's a lot to absorb here, especially if you're new to these tools. Take some time to familiarize yourself with the tooling and understand how all the components interconnect. Dive into the documentation of the various tools included — they are a valuable resource. This shouldn't be a production environment yet, so embrace the freedom to experiment. Move fast, break things intentionally, and challenge yourself to fix them.

Below are some optional considerations you may want to explore.

### DNS

The template uses [k8s_gateway](https://github.com/ori-edge/k8s_gateway) to provide DNS for your applications, consider exploring [external-dns](https://github.com/kubernetes-sigs/external-dns) as an alternative.

External-DNS offers broad support for various DNS providers, including but not limited to:

- [Pi-hole](https://github.com/kubernetes-sigs/external-dns/blob/master/docs/tutorials/pihole.md)
- [UniFi](https://github.com/kashalls/external-dns-unifi-webhook)
- [Adguard Home](https://github.com/muhlba91/external-dns-provider-adguard)
- [Bind](https://github.com/kubernetes-sigs/external-dns/blob/master/docs/tutorials/rfc2136.md)

This flexibility allows you to integrate seamlessly with a range of DNS solutions to suit your environment and offload DNS from your cluster to your router, or external device.

### Secrets

SOPs is an excellent tool for managing secrets in a GitOps workflow. However, it can become cumbersome when rotating secrets or maintaining a single source of truth for secret items.

For a more streamlined approach to those issues, consider [External Secrets](https://external-secrets.io/latest/). This tool allows you to move away from SOPs and leverage an external provider for managing your secrets. External Secrets supports a wide range of providers, from cloud-based solutions to self-hosted options.

### Storage

If your workloads require persistent storage with features like replication or connectivity to NFS, SMB, or iSCSI servers, there are several projects worth exploring:

- [rook-ceph](https://github.com/rook/rook)
- [longhorn](https://github.com/longhorn/longhorn)
- [openebs](https://github.com/openebs/openebs)
- [democratic-csi](https://github.com/democratic-csi/democratic-csi)
- [csi-driver-nfs](https://github.com/kubernetes-csi/csi-driver-nfs)
- [csi-driver-smb](https://github.com/kubernetes-csi/csi-driver-smb)
- [synology-csi](https://github.com/SynologyOpenSource/synology-csi)

These tools offer a variety of solutions to meet your persistent storage needs, whether you’re using cloud-native or self-hosted infrastructures.

### Community Repositories

Community member [@whazor](https://github.com/whazor) created [Kubesearch](https://kubesearch.dev) to allow searching Flux HelmReleases across Github and Gitlab repositories with the `kubesearch` topic.

## 🙋 Support

### Community

- Make a post in this repository's Github [Discussions](https://github.com/onedr0p/cluster-template/discussions).
- Start a thread in the `#support` or `#cluster-template` channels in the [Home Operations](https://discord.gg/home-operations) Discord server.

### GitHub Sponsors

If you're having difficulty with this project, can't find the answers you need through the community support options above, or simply want to show your appreciation while gaining deeper insights, I’m offering one-on-one paid support through GitHub Sponsors for a limited time. Payment and scheduling will be coordinated through [GitHub Sponsors](https://github.com/sponsors/onedr0p).

<details>

<summary>Click to expand the details</summary>

<br>

- **Rate**: $50/hour (no longer than 2 hours / day).
- **What’s Included**: Assistance with deployment, debugging, or answering questions related to this project.
- **What to Expect**:
  1. Sessions will focus on specific questions or issues you are facing.
  2. I will provide guidance, explanations, and actionable steps to help resolve your concerns.
  3. Support is limited to this project and does not extend to unrelated tools or custom feature development.

</details>

## 🙌 Related Projects

If this repo is too hot to handle or too cold to hold check out these following projects.

- [ajaykumar4/cluster-template](https://github.com/ajaykumar4/cluster-template) - _A template for deploying a Talos Kubernetes cluster including Argo for GitOps_
- [khuedoan/homelab](https://github.com/khuedoan/homelab) - _Fully automated homelab from empty disk to running services with a single command._
- [mitchross/k3s-argocd-starter](https://github.com/mitchross/k3s-argocd-starter) - starter kit for k3s, argocd
- [ricsanfre/pi-cluster](https://github.com/ricsanfre/pi-cluster) - _Pi Kubernetes Cluster. Homelab kubernetes cluster automated with Ansible and FluxCD_
- [techno-tim/k3s-ansible](https://github.com/techno-tim/k3s-ansible) - _The easiest way to bootstrap a self-hosted High Availability Kubernetes cluster. A fully automated HA k3s etcd install with kube-vip, MetalLB, and more. Build. Destroy. Repeat._

## ⭐ Stargazers

<div align="center">

<a href="https://star-history.com/#onedr0p/cluster-template&Date">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=onedr0p/cluster-template&type=Date&theme=dark" />
    <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/svg?repos=onedr0p/cluster-template&type=Date" />
    <img alt="Star History Chart" src="https://api.star-history.com/svg?repos=onedr0p/cluster-template&type=Date" />
  </picture>
</a>

</div>

## 🤝 Thanks

Big shout out to all the contributors, sponsors and everyone else who has helped on this project.
