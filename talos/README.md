# Talos Configuration

This directory holds the TOPF config for the cluster:

- `topf.yaml`: cluster settings, versions, image schematics and the node list
- `secrets.yaml`: the SOPS-encrypted Talos secrets bundle
- `all/`, `control-plane/`, `worker/`, `node/`: strategic merge patches applied on top
  of the machine config TOPF generates. This is TOPF's default layout (patches next to
  `topf.yaml`), so `topf.yaml` sets no `patchesDir`.
- `talosconfig` and `output/` are generated locally and gitignored. `output/` (from
  `task talos:render`) contains cluster secrets in plaintext; delete it after use.

## Patch Directories

TOPF loads patches for each node from these directories, in this order:

- `all/`: applied to every node
- `control-plane/`: applied to control-plane nodes only
- `worker/`: applied to worker nodes only
- `node/${node-host}/`: applied to the node with that `host` in `topf.yaml`

Within a directory, files are applied in lexicographic order, hence the numeric
prefixes. Later patches merge over earlier ones, so a role patch adds to or overrides
what `all/` already set.

## Patch Format

Every file is a strategic merge patch — a YAML mapping, never an RFC 6902 array of
`{op, path, value}` operations, which TOPF rejects. Remove a field with
`$patch: delete` rather than a JSON patch `remove` op. A file may hold several YAML
documents when it contributes more than one Talos config kind.

Files ending in `.tpl` are rendered as Go templates first, with `.Node.Host`,
`.Node.IP`, `.Node.Role`, `.Node.Data.*`, `.Data.*` and `.ClusterName` in scope. A
missing key is a hard error. Plain `.yaml` patches are never templated, so `{{` and
`${...}` in them pass through untouched.

## Multi-Document Config (Talos 1.14+)

Since Talos 1.14 the machine config is a stream of typed documents, each with
`apiVersion: v1alpha1` and a `kind:` (`KubeletConfig`, `ResolverConfig`,
`SysctlConfig`, `KubeAPIServerConfig`, ...), instead of one big `machine:`/`cluster:`
mapping. Patches target those documents:

- A patch document merges into the generated document with the same `kind`, plus the
  same `name` for named kinds (`KernelModuleConfig`, `EthernetConfig`,
  `UserVolumeConfig`, `KubeAdmissionControlConfig`, ...). A patch whose `kind`/`name`
  matches nothing is added as a new document.
- A v1alpha1 field and the document that replaces it cannot both be set; Talos rejects
  the config. Never reintroduce a deprecated `machine.*`/`cluster.*` key next to its
  document.
- Leaving a document out of the patches does not remove it, because TOPF generates a
  base config that already contains it. Delete a generated document explicitly:

      apiVersion: v1alpha1
      kind: KubeFlannelCNIConfig
      $patch: delete

  That one (`control-plane/05-flannel-disable.yaml`) is what keeps Flannel off so
  Cilium owns the CNI; `cni.name: none` no longer does it.
- Which format TOPF generates follows each node's running Talos version, not
  `talosVersion` in `topf.yaml`. Upgrade the OS first, then change config.

Three things stay in the v1alpha1 document on purpose: `machine.certSANs`
(`all/03-cert-sans.yaml`, never deprecated), `machine.logging`
(`all/15-machine-logging.yaml.tpl`, because `KmsgLogConfig` has no `extraTags` for the
hostname tag), and `cluster.etcd` (`control-plane/01-etcd.yaml`, no replacement
document yet).
