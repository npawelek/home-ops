# Talos iPXE Boot Configurations

This directory contains iPXE configurations for booting different Talos Linux variants via netboot.xyz using custom factory schematics.

## Main Configuration

**File**: `talos-custom.ipxe` - Single unified menu for all Talos factory builds

### Supported Builds

1. **Intel iGPU** (amd64)
   - Extensions: siderolabs/i915, siderolabs/intel-ucode, siderolabs/nvme-cli, siderolabs/util-linux-tools
   - Use case: Intel systems with integrated graphics

2. **Intel iGPU + Arc** (amd64)
   - Extensions: siderolabs/i915, siderolabs/intel-ucode, siderolabs/mei, siderolabs/nvme-cli, siderolabs/util-linux-tools
   - Use case: Intel systems with integrated graphics and Arc GPU support

3. **AMD iGPU** (amd64)
   - Extensions: siderolabs/amdgpu, siderolabs/amd-ucode, siderolabs/nvme-cli, siderolabs/util-linux-tools
   - Use case: AMD systems with integrated graphics

4. **Raspberry Pi** (arm64)
   - Extensions: siderolabs/util-linux-tools
   - Use case: Raspberry Pi 4/5 (uses standard ARM64 kernel)

## Setup Instructions

### 1. Generate Schematic IDs and Download Assets

Run the generator script:

```bash
pip install requests pyyaml
python3 ipxe/generate-schematics.py
```

This will:
- Fetch the latest Talos version from GitHub
- Generate 4 schematic IDs with the correct extensions
- Automatically update `talos-custom.ipxe` with the version and schematic IDs
- Output a command to download all kernel/initramfs files

### 2. Download Assets to netboot.xyz Server

Copy the download command from the script output and run it on your netboot.xyz server. It will download all 8 files (4 kernels + 4 initramfs) to `talos/<version>/`.

### 3. Deploy to netboot.xyz

Copy `talos-custom.ipxe` to your netboot.xyz server:

```bash
# Example - adjust path for your setup
scp ipxe/talos-custom.ipxe user@netboot-server:/var/www/html/custom/
```

### 4. Add to netboot.xyz Menu

Add an entry to your netboot.xyz custom menu to chain-load this file:

```ipxe
item talos_custom Talos Custom Factory Builds
# ...
:talos_custom
chain ${boot_domain}talos-custom.ipxe || goto error
```

### 5. Test Boot

- Boot a machine via PXE
- Navigate to the Talos Custom menu
- Select the appropriate build for your hardware
- Optionally set a userdata.yaml URL for configuration
- Boot and verify

## Talos Factory URLs

Each schematic will generate URLs in this format:
```
https://factory.talos.dev/image/{schematic_id}/{talos_version}/metal-amd64.iso
https://factory.talos.dev/image/{schematic_id}/{talos_version}/metal-arm64.iso
```

For netboot, we use the kernel and initramfs directly:
```
https://factory.talos.dev/image/{schematic_id}/{talos_version}/kernel-amd64
https://factory.talos.dev/image/{schematic_id}/{talos_version}/initramfs-amd64.xz
```
