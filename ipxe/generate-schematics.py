#!/usr/bin/env python3
"""
Talos Factory Schematic Generator

This script generates schematic IDs for different Talos configurations
and automatically updates talos-custom.ipxe with the version and IDs.
"""

import json
import os
import re
import sys
from pathlib import Path
from typing import Dict, List

try:
    import requests
    import yaml
except ImportError:
    print("Error: Required packages not installed")
    print("Please run: pip install requests pyyaml")
    sys.exit(1)

# Configuration
FACTORY_URL = "https://factory.talos.dev"
GITHUB_API = "https://api.github.com/repos/siderolabs/talos/releases/latest"
SCRIPT_DIR = Path(__file__).parent
IPXE_FILE = SCRIPT_DIR / "talos-custom.ipxe"

# Kernel arguments to apply to all schematics
KERNEL_ARGS = [
    "ipv6.disable=1",
    "net.ifnames=0",
]

# Raspberry Pi 4/CM4 overlay configuration
RPI_OVERLAY = {
    "overlay": {
        "name": "rpi_generic",
        "image": "siderolabs/sbc-raspberrypi",
        "options": {
            "configTxtAppend": "dtoverlay=disable-bt, dtoverlay=disable-wifi, gpu_mem=16, enable_uart=1",
        },
    },
}

# Build configurations
# Format: (name, arch, placeholder, extensions, board_config)
BUILD_CONFIGS = [
    (
        "Intel iGPU",
        "amd64",
        "YOUR_INTEL_IGPU_SCHEMATIC_ID",
        ["siderolabs/i915", "siderolabs/intel-ucode", "siderolabs/nvme-cli", "siderolabs/util-linux-tools"],
        None,
    ),
    (
        "Intel iGPU+Arc",
        "amd64",
        "YOUR_INTEL_ARC_SCHEMATIC_ID",
        ["siderolabs/i915", "siderolabs/intel-ucode", "siderolabs/mei", "siderolabs/nvme-cli", "siderolabs/util-linux-tools"],
        None,
    ),
    (
        "AMD iGPU",
        "amd64",
        "YOUR_AMD_IGPU_SCHEMATIC_ID",
        ["siderolabs/amdgpu", "siderolabs/amd-ucode", "siderolabs/nvme-cli", "siderolabs/util-linux-tools"],
        None,
    ),
    (
        "Raspberry Pi",
        "arm64",
        "YOUR_RPI_SCHEMATIC_ID",
        ["siderolabs/util-linux-tools"],
        RPI_OVERLAY,
    ),
]


def get_latest_talos_version() -> str:
    """Fetch the latest Talos version from GitHub."""
    version = os.environ.get("TALOS_VERSION")
    if version:
        print(f"Using specified version: {version}")
        return version

    print("Fetching latest Talos version from GitHub...")
    try:
        response = requests.get(GITHUB_API, timeout=10)
        response.raise_for_status()
        version = response.json()["tag_name"]
        print(f"Latest version: {version}")
        return version
    except Exception as e:
        print(f"Failed to fetch latest version: {e}")
        print("Using default: v1.11.5")
        return "v1.11.5"


def generate_schematic_yaml(extensions: List[str], board_config: Dict = None) -> str:
    """Generate schematic YAML configuration."""
    config = {
        "customization": {
            "systemExtensions": {"officialExtensions": extensions},
            "extraKernelArgs": KERNEL_ARGS,
        }
    }

    # Add board-specific configuration if provided (at root level)
    if board_config:
        config.update(board_config)

    return yaml.dump(config, default_flow_style=False, sort_keys=False)


def generate_schematic(
    name: str, arch: str, extensions: List[str], talos_version: str, board_config: Dict = None
) -> str:
    """Generate a schematic and return its ID."""
    print(f"\nGenerating schematic for: {name}")
    print(f"Architecture: {arch}")
    print(f"Extensions: {', '.join(extensions)}")
    print(f"Kernel args: {', '.join(KERNEL_ARGS)}")

    overlay = generate_schematic_yaml(extensions, board_config)
    print("\nOverlay configuration:")
    print(overlay)

    try:
        response = requests.post(
            f"{FACTORY_URL}/schematics",
            data=overlay,
            headers={"Content-Type": "application/x-yaml"},
            timeout=30,
        )
        response.raise_for_status()
        schematic_id = response.json()["id"]

        print(f"✓ Schematic ID: {schematic_id}")
        print(
            f"  Kernel URL: {FACTORY_URL}/image/{schematic_id}/{talos_version}/kernel-{arch}"
        )
        print(
            f"  Initramfs URL: {FACTORY_URL}/image/{schematic_id}/{talos_version}/initramfs-{arch}.xz"
        )
        print("-" * 60)

        return schematic_id
    except Exception as e:
        print(f"✗ Failed to generate schematic: {e}")
        print("-" * 60)
        return ""


def update_ipxe_file(
    schematic_ids: Dict[str, str], talos_version: str
) -> bool:
    """Update the iPXE file with version and schematic IDs."""
    if not IPXE_FILE.exists():
        print(f"✗ Error: {IPXE_FILE} not found")
        return False

    print(f"\nUpdating {IPXE_FILE}...")

    content = IPXE_FILE.read_text()

    # Update version
    content = re.sub(
        r"isset \${talos_version} \|\| set talos_version .*",
        f"isset ${{talos_version}} || set talos_version {talos_version}",
        content,
    )

    # Update schematic IDs
    for placeholder, schematic_id in schematic_ids.items():
        if schematic_id:
            # Replace placeholder
            content = re.sub(
                f"set schematic_id {placeholder}",
                f"set schematic_id {schematic_id}",
                content,
            )
            # Also replace existing schematic IDs (for re-runs)
            content = re.sub(
                r"set schematic_id [a-f0-9]{64}(\s*# " + placeholder.replace("YOUR_", "").replace("_SCHEMATIC_ID", "") + ")",
                f"set schematic_id {schematic_id}\\1",
                content,
            )

    IPXE_FILE.write_text(content)
    return True


def main():
    """Main execution."""
    print("=" * 60)
    print("Talos Factory Schematic Generator")
    print("=" * 60)

    talos_version = get_latest_talos_version()
    print(f"Version: {talos_version}\n")

    print("Generating schematics...")
    schematic_ids = {}

    for name, arch, placeholder, extensions, board_config in BUILD_CONFIGS:
        schematic_id = generate_schematic(name, arch, extensions, talos_version, board_config)
        if schematic_id:
            schematic_ids[placeholder] = schematic_id

    if not schematic_ids:
        print("\n✗ No schematics were generated successfully")
        sys.exit(1)

    if update_ipxe_file(schematic_ids, talos_version):
        print(f"\n✓ Updated {IPXE_FILE}")
        print(f"  - Talos version: {talos_version}")
        for name, _, placeholder, _, _ in BUILD_CONFIGS:
            if placeholder in schematic_ids:
                print(f"  - {name}: {schematic_ids[placeholder]}")
        print("\n✓ Done! Your talos-custom.ipxe is ready to deploy.")

        # Generate download commands
        print("\n" + "=" * 60)
        print("Download assets to netboot.xyz server:")
        print("=" * 60)
        print("\nRun this command on your netboot.xyz server:\n")

        # Filename mapping to match talos-custom.ipxe
        filename_map = {
            "Intel iGPU": "intel-igpu",
            "Intel iGPU+Arc": "intel-arc",
            "AMD iGPU": "amd-igpu",
            "Raspberry Pi": "rpi",
        }

        download_cmds = []
        for name, arch, placeholder, _, _ in BUILD_CONFIGS:
            if placeholder in schematic_ids:
                schematic_id = schematic_ids[placeholder]
                file_prefix = filename_map.get(name, name.lower().replace(" ", "-"))
                kernel_url = f"https://factory.talos.dev/image/{schematic_id}/{talos_version}/kernel-{arch}"
                initramfs_url = f"https://factory.talos.dev/image/{schematic_id}/{talos_version}/initramfs-{arch}.xz"

                download_cmds.append(f"echo 'Downloading {name} kernel...'")
                download_cmds.append(f"curl -sL -o {file_prefix}-kernel-{arch} {kernel_url}")
                download_cmds.append(f"echo 'Downloading {name} initramfs...'")
                download_cmds.append(f"curl -sL -o {file_prefix}-initramfs-{arch}.xz {initramfs_url}")

        full_cmd = "mkdir -p talos/" + talos_version + " && cd talos/" + talos_version + " && " + " && ".join(download_cmds)
        print(full_cmd)
        print("\n" + "=" * 60)
    else:
        print("\nManual schematic IDs:")
        for name, _, placeholder, _, _ in BUILD_CONFIGS:
            if placeholder in schematic_ids:
                print(f"  - {name}: {schematic_ids[placeholder]}")


if __name__ == "__main__":
    main()
