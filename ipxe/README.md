# Talos iPXE Boot Configurations

This directory contains iPXE configurations for booting different Talos Linux variants via netboot.xyz using custom factory schematics.

## Main Configuration

```
ipxe/
├── generate-schematics.py  (Generates Talos Factory schematics with custom extensions)
├── netboot.sops.yaml       (iPXE automation secrets)
└── talos-custom.ipxe       (iPXE boot menu for netboot.xyz)
```

### Current Schematic IDs

<!-- SCHEMATIC_IDS_START -->
**Talos Version**: v1.12.1

- **Intel i915**: `0b6deb91fb651b3885f5f703d894096cbb71e9cd59324a5ea84f9919427995da`
- **Intel XE Arc**: `92cdade33f77e1c7ec5a581e3415952d107414facf9da5383ad8c9f579064377`
- **AMD iGPU**: `f0b77609affe4cdc9b0e8fcf943e5e14eeba33678424860a3a845bb1b10c82d8`
- **Raspberry Pi**: `9dfae53ec9d4b97cce946e2b16edfdce0e6c33aaf2019cc219c68e18acafaa7a`
<!-- SCHEMATIC_IDS_END -->

*This section is automatically updated by the generate script.*

### Supported Builds

All builds include common extensions and kernel parameters:
- **Storage**: `iscsi-tools`, `nfs-utils`, `nvme-cli` (amd64 only), `util-linux-tools`
- **Kernel Parameters**: `ipv6.disable=1 net.ifnames=0`

1. **Intel i915** (amd64)
   - Extensions: siderolabs/i915, siderolabs/intel-ucode, siderolabs/iscsi-tools, siderolabs/nfs-utils, siderolabs/nvme-cli, siderolabs/util-linux-tools
   - Kernel Parameters: `ipv6.disable=1 net.ifnames=0`
   - Use case: Intel systems with integrated graphics (i915 driver)

2. **Intel XE Arc** (amd64)
   - Extensions: siderolabs/xe, siderolabs/intel-ucode, siderolabs/iscsi-tools, siderolabs/mei, siderolabs/nfs-utils, siderolabs/nvme-cli, siderolabs/util-linux-tools
   - Kernel Parameters: `ipv6.disable=1 net.ifnames=0`
   - Use case: Intel systems with Arc GPU support (xe driver)

3. **AMD iGPU** (amd64)
   - Extensions: siderolabs/amdgpu, siderolabs/amd-ucode, siderolabs/iscsi-tools, siderolabs/nfs-utils, siderolabs/nvme-cli, siderolabs/util-linux-tools
   - Kernel Parameters: `ipv6.disable=1 net.ifnames=0`
   - Use case: AMD systems with integrated graphics

4. **Raspberry Pi** (arm64)
   - Extensions: siderolabs/iscsi-tools, siderolabs/nfs-utils, siderolabs/util-linux-tools
   - Kernel Parameters: `ipv6.disable=1 net.ifnames=0`
   - Use case: Raspberry Pi 4/5 (uses standard ARM64 kernel)

## Setup Instructions

### Prerequisites

- Python dependencies are managed by mise and installed automatically via `mise install`
- Netboot server configuration stored in `ipxe/netboot.sops.yaml`

### Deployment

The deployment process is fully automated via task commands:

```bash
# Full deployment (generate + sync + download)
task ipxe:deploy

# Or run individual steps:
task ipxe:generate        # Generate schematics from talenv.yaml
task ipxe:sync-menu       # Sync iPXE menu file to server
task ipxe:download-assets # Download kernel/initramfs to server
```

### How It Works

1. **Version Management**: The script automatically reads the Talos version from `talos/talenv.yaml`
2. **Schematic Generation**: Generates 4 schematic IDs with hardware-specific extensions
3. **Menu Update**: Updates `talos-custom.ipxe` with the version and schematic IDs
4. **Server Sync**: Copies the iPXE menu to netboot.xyz server
5. **Asset Download**: Downloads all kernel/initramfs assets to netboot.xyz

### Updating Talos Version

When the Talos version in `talos/talenv.yaml` is updated, run `task ipxe:deploy`.

### Server Configuration

Server details are stored in `ipxe/netboot.sops.yaml` (encrypted):

```yaml
netboot_host: root@your-server.com
netboot_path: /path/to/netboot/assets/talos
netboot_menu_path: /path/to/netboot/config/menus
```

Edit with: `sops ipxe/netboot.sops.yaml`

## Boot Flow

1. Machine PXE boots → netboot.xyz loads
2. User selects custom Talos menu
3. Picks a build (Intel i915, Intel XE, AMD, etc.)
4. iPXE downloads kernel + initramfs
5. Boots Talos with custom extensions baked in

## Talos Factory URLs

Each schematic generates URLs in this format:
```
https://factory.talos.dev/image/{schematic_id}/{talos_version}/kernel-amd64
https://factory.talos.dev/image/{schematic_id}/{talos_version}/initramfs-amd64.xz
```

Netboot.xyz locally serves these files instead of hitting Talos Factory directly.
