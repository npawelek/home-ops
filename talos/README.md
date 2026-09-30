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
prefixes. Later patches merge over earlier ones; lists with a merge key
(`machine.files` by `path`, `cluster.inlineManifests` by `name`) append rather than
replace, so a role patch adds to what `all/` already set.

## Patch Format

Every file is a strategic merge patch — a YAML mapping, never an RFC 6902 array of
`{op, path, value}` operations, which TOPF rejects. Remove a field with
`$patch: delete` rather than a JSON patch `remove` op. A file may hold several YAML
documents when it contributes more than one Talos config kind.

Files ending in `.tpl` are rendered as Go templates first, with `.Node.Host`,
`.Node.IP`, `.Node.Role`, `.Node.Data.*`, `.Data.*` and `.ClusterName` in scope. A
missing key is a hard error. Plain `.yaml` patches are never templated, so `{{` and
`${...}` in them pass through untouched.
