#!/usr/bin/env python3
"""
Talos Factory Schematic Generator

This script generates schematic IDs for different Talos configurations.
BUILD_CONFIGS is the single source of truth: the iPXE menu and boot entries,
the README build list, and the schematicIds in topf.yaml are all generated
from it.
"""

import os
import re
import sys
from collections import Counter
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List, Optional

try:
    import requests
    import yaml
except ImportError:
    print("Error: Required packages not installed")
    print("Please run: pip install requests pyyaml")
    sys.exit(1)

# Configuration
FACTORY_URL = "https://factory.talos.dev"
SCRIPT_DIR = Path(__file__).parent
REPO_ROOT = SCRIPT_DIR.parent
IPXE_FILE = SCRIPT_DIR / "talos-custom.ipxe"
TOPF_FILE = REPO_ROOT / "talos" / "topf.yaml"

# Kernel arguments to apply to all schematics
KERNEL_ARGS = [
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

@dataclass
class BuildConfig:
    name: str
    # Used for netboot asset file names and the iPXE menu label
    slug: str
    arch: str
    extensions: List[str]
    use_case: str
    board_config: Optional[Dict] = None
    # Nodes that run this schematic; drives schematicId in topf.yaml
    hosts: List[str] = field(default_factory=list)
    extra_kernel_args: List[str] = field(default_factory=list)

    @property
    def ipxe_label(self) -> str:
        return self.slug.replace("-", "_")


BUILD_CONFIGS = [
    BuildConfig(
        name="Intel i915",
        slug="intel-i915",
        arch="amd64",
        extensions=["siderolabs/i915", "siderolabs/intel-ucode", "siderolabs/iscsi-tools", "siderolabs/nfs-utils", "siderolabs/nvme-cli", "siderolabs/util-linux-tools"],
        use_case="Intel systems with integrated graphics (i915 driver)",
        hosts=["m1", "m2", "m3", "karakum", "donnager", "hammurabi"],
    ),
    BuildConfig(
        name="Intel Arc i915",
        slug="intel-arc-i915",
        arch="amd64",
        extensions=["siderolabs/i915", "siderolabs/intel-ucode", "siderolabs/iscsi-tools", "siderolabs/mei", "siderolabs/nfs-utils", "siderolabs/nvme-cli", "siderolabs/util-linux-tools"],
        use_case="Intel Arc gen1 (Alchemist/DG2) discrete GPUs. xe does not support gen1, so this uses i915; "
                 "mei lets the GSC load HuC, which the low-power encoders need for bitrate control",
        hosts=["pella"],
    ),
    BuildConfig(
        name="AMD iGPU",
        slug="amd-igpu",
        arch="amd64",
        extensions=["siderolabs/amdgpu", "siderolabs/amd-ucode", "siderolabs/iscsi-tools", "siderolabs/nfs-utils", "siderolabs/nvme-cli", "siderolabs/util-linux-tools"],
        use_case="AMD systems with integrated graphics",
        hosts=["rocinante"],
    ),
    BuildConfig(
        name="Raspberry Pi",
        slug="rpi",
        arch="arm64",
        extensions=["siderolabs/iscsi-tools", "siderolabs/nfs-utils", "siderolabs/util-linux-tools"],
        use_case="Raspberry Pi 4/5 (uses standard ARM64 kernel)",
        board_config=RPI_OVERLAY,
    ),
]


def get_latest_talos_version() -> str:
    """Get Talos version from topf.yaml or environment variable."""
    version = os.environ.get("TALOS_VERSION")
    if version:
        print(f"Using specified version from environment: {version}")
        return version

    # Try to read from topf.yaml
    if TOPF_FILE.exists():
        print(f"Reading Talos version from {TOPF_FILE}...")
        try:
            with open(TOPF_FILE, 'r') as f:
                topf = yaml.safe_load(f)
                version = topf.get('talosVersion')
                if version:
                    print(f"Found version in topf.yaml: {version}")
                    return version
        except Exception as e:
            print(f"Failed to read topf.yaml: {e}")

    print("ERROR: Could not determine Talos version")
    print("Please set TALOS_VERSION environment variable or ensure talos/topf.yaml exists")
    sys.exit(1)


def generate_schematic_yaml(extensions: List[str], board_config: Dict = None, extra_kernel_args: List[str] = None) -> str:
    """Generate schematic YAML configuration."""
    # Combine global and extra kernel args
    all_kernel_args = KERNEL_ARGS.copy()
    if extra_kernel_args:
        all_kernel_args.extend(extra_kernel_args)

    config = {
        "customization": {
            "systemExtensions": {"officialExtensions": extensions},
            "extraKernelArgs": all_kernel_args,
        }
    }

    # Add board-specific configuration if provided (at root level)
    if board_config:
        config.update(board_config)

    return yaml.dump(config, default_flow_style=False, sort_keys=False)


def generate_schematic(config: BuildConfig, talos_version: str) -> str:
    """Generate a schematic and return its ID."""
    arch = config.arch
    print(f"\nGenerating schematic for: {config.name}")
    print(f"Architecture: {arch}")
    print(f"Extensions: {', '.join(config.extensions)}")
    print(f"Kernel args: {', '.join(KERNEL_ARGS + config.extra_kernel_args)}")

    overlay = generate_schematic_yaml(config.extensions, config.board_config, config.extra_kernel_args)
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


def replace_generated_section(content: str, start: str, end: str, body: str, path: Path) -> Optional[str]:
    """Replace the text between two marker lines, keeping the markers."""
    pattern = re.compile(rf"({re.escape(start)}\n).*?(^{re.escape(end)})", flags=re.DOTALL | re.MULTILINE)
    new_content, count = pattern.subn(lambda m: m.group(1) + body + m.group(2), content)
    if count != 1:
        print(f"✗ Error: expected one '{start}' ... '{end}' section in {path}, found {count}")
        return None
    return new_content


def update_ipxe_file(talos_version: str) -> bool:
    """Update the iPXE file's version, build menu and boot entries from BUILD_CONFIGS."""
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

    menu = "".join(
        f"item {c.ipxe_label} ${{space}} {c.name} ({', '.join(e.removeprefix('siderolabs/') for e in c.extensions)})\n"
        for c in BUILD_CONFIGS
    )
    entries = "\n".join(
        f":{c.ipxe_label}\n"
        f"set kernel_file {c.slug}-kernel-{c.arch}\n"
        f"set initramfs_file {c.slug}-initramfs-{c.arch}.xz\n"
        f"set os_name Talos {c.name}\n"
        f"set extensions {', '.join(c.extensions)}\n"
        f"set os_arch {c.arch}\n"
        f"goto talos_boot\n"
        for c in BUILD_CONFIGS
    )

    for start, end, body in (
        ("# BEGIN GENERATED BUILD MENU", "# END GENERATED BUILD MENU", menu),
        ("# BEGIN GENERATED BUILD ENTRIES", "# END GENERATED BUILD ENTRIES", entries),
    ):
        content = replace_generated_section(content, start, end, body, IPXE_FILE)
        if content is None:
            return False

    IPXE_FILE.write_text(content)
    return True


def update_readme(schematic_ids: Dict[str, str], talos_version: str) -> bool:
    """Update the README's schematic IDs and build list from BUILD_CONFIGS."""
    readme_file = SCRIPT_DIR / "README.md"
    if not readme_file.exists():
        print(f"✗ Warning: {readme_file} not found, skipping README update")
        return False

    print(f"\nUpdating {readme_file}...")

    content = readme_file.read_text()

    ids = f"**Talos Version**: {talos_version}\n\n" + "".join(
        f"- **{c.name}**: `{schematic_ids.get(c.slug, 'N/A')}`\n" for c in BUILD_CONFIGS
    )
    builds = "\n".join(
        f"{i}. **{c.name}** ({c.arch})\n"
        f"   - Extensions: {', '.join(c.extensions)}\n"
        f"   - Kernel Parameters: `{' '.join(KERNEL_ARGS + c.extra_kernel_args)}`\n"
        f"   - Use case: {c.use_case}\n"
        f"   - Nodes: {', '.join(c.hosts) if c.hosts else 'none'}\n"
        for i, c in enumerate(BUILD_CONFIGS, start=1)
    )
    nodes = (
        "| Node | Build | Schematic ID | Extensions | Kernel Args |\n"
        "|---|---|---|---|---|\n"
        + "".join(
            f"| {host} | {c.name} | `{schematic_ids.get(c.slug, 'N/A')}` | {', '.join(c.extensions)} "
            f"| `{' '.join(KERNEL_ARGS + c.extra_kernel_args)}` |\n"
            for c in BUILD_CONFIGS
            for host in c.hosts
        )
    )

    for start, end, body in (
        ("<!-- SCHEMATIC_IDS_START -->", "<!-- SCHEMATIC_IDS_END -->", ids),
        ("<!-- BUILDS_START -->", "<!-- BUILDS_END -->", builds),
        ("<!-- NODES_START -->", "<!-- NODES_END -->", nodes),
    ):
        content = replace_generated_section(content, start, end, body, readme_file)
        if content is None:
            return False

    readme_file.write_text(content)
    return True


def update_topf_config(node_mapping: Dict[str, str]) -> bool:
    """Update schematicIds in topf.yaml.

    The most common schematic becomes the cluster-wide schematicId. Nodes that
    need a different one get a per-node schematicId, which topf prefers over the
    cluster-wide value. Per-node entries matching the cluster-wide value are removed.
    """
    if not TOPF_FILE.exists():
        print(f"✗ Warning: {TOPF_FILE} not found, skipping topf.yaml update")
        return False

    content = TOPF_FILE.read_text()
    topf = yaml.safe_load(content)
    hosts = [node["host"] for node in topf.get("nodes", [])]

    unmapped = [host for host in hosts if host not in node_mapping]
    if unmapped:
        print(f"✗ Warning: nodes {unmapped} are not in any BUILD_CONFIGS host list, "
              "skipping topf.yaml update")
        return False

    print(f"\nUpdating {TOPF_FILE}...")
    cluster_id = Counter(node_mapping[host] for host in hosts).most_common(1)[0][0]
    content, count = re.subn(
        r'^schematicId: [a-f0-9]{64}$',
        f'schematicId: {cluster_id}',
        content,
        flags=re.MULTILINE,
    )
    if count != 1:
        print(f"✗ Warning: expected one top-level schematicId line in {TOPF_FILE}, found {count}")
        return False

    for host in hosts:
        block_pattern = re.compile(
            rf'^  - host: {re.escape(host)}\n.*?(?=^  - host: |\Z)',
            flags=re.MULTILINE | re.DOTALL,
        )
        match = block_pattern.search(content)
        if not match:
            print(f"✗ Warning: could not find node block for {host} in {TOPF_FILE}")
            return False

        block = re.sub(r'^    schematicId: .*\n', '', match.group(0), flags=re.MULTILINE)
        if node_mapping[host] != cluster_id:
            node_line = f"    schematicId: {node_mapping[host]}\n"
            block, inserted = re.subn(r'^(    role: .*\n)', rf'\g<1>{node_line}', block, count=1, flags=re.MULTILINE)
            if not inserted:
                block = re.sub(r'^(  - host: .*\n)', rf'\g<1>{node_line}', block, count=1)
            print(f"✓ {host}: per-node schematicId {node_mapping[host]}")
        content = content[:match.start()] + block + content[match.end():]

    # Confirm every node resolves to its intended schematic the way topf does:
    # per-node schematicId first, then the cluster-wide one.
    rendered = yaml.safe_load(content)
    for node in rendered["nodes"]:
        effective = node.get("schematicId") or rendered["schematicId"]
        if effective != node_mapping[node["host"]]:
            print(f"✗ Error: {node['host']} would resolve to {effective}, "
                  f"expected {node_mapping[node['host']]}; not writing {TOPF_FILE}")
            return False

    TOPF_FILE.write_text(content)
    print(f"✓ Updated cluster-wide schematicId to {cluster_id}")
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
    node_mapping = {}

    for config in BUILD_CONFIGS:
        schematic_id = generate_schematic(config, talos_version)
        if schematic_id:
            schematic_ids[config.slug] = schematic_id
            for hostname in config.hosts:
                node_mapping[hostname] = schematic_id

    # Every generated file lists every build, so a partial run would leave them
    # pointing at assets or schematics that don't exist.
    failed = [c.name for c in BUILD_CONFIGS if c.slug not in schematic_ids]
    if failed:
        print(f"\n✗ Failed to generate schematics for: {', '.join(failed)}; no files were updated")
        sys.exit(1)

    duplicates = [h for h, n in Counter(h for c in BUILD_CONFIGS for h in c.hosts).items() if n > 1]
    if duplicates:
        print(f"\n✗ Hosts listed in more than one build: {', '.join(duplicates)}; no files were updated")
        sys.exit(1)

    if not update_ipxe_file(talos_version):
        sys.exit(1)
    print(f"\n✓ Updated {IPXE_FILE}")
    print(f"  - Talos version: {talos_version}")
    for config in BUILD_CONFIGS:
        print(f"  - {config.name}: {schematic_ids[config.slug]}")

    update_readme(schematic_ids, talos_version)

    # Update topf.yaml with cluster-wide and per-node schematic IDs. Must not fail
    # silently: the iPXE menu and README are already written at this point, so a
    # skipped topf.yaml leaves the cluster pinned to the previous schematic while
    # every other generated file advertises the new one.
    if not update_topf_config(node_mapping):
        sys.exit(1)

    print("\n✓ Done! Your talos-custom.ipxe is ready to deploy.")

    # Generate download commands
    print("\n" + "=" * 60)
    print("Download assets to netboot.xyz server:")
    print("=" * 60)
    print("\nRun this command on your netboot.xyz server:\n")

    download_cmds = []
    for config in BUILD_CONFIGS:
        schematic_id = schematic_ids[config.slug]
        arch = config.arch
        kernel_url = f"{FACTORY_URL}/image/{schematic_id}/{talos_version}/kernel-{arch}"
        initramfs_url = f"{FACTORY_URL}/image/{schematic_id}/{talos_version}/initramfs-{arch}.xz"

        download_cmds.append(f"echo 'Downloading {config.name} kernel...'")
        download_cmds.append(f"curl -fSL --progress-bar --max-time 20 --retry 5 --retry-delay 2 -o {config.slug}-kernel-{arch} {kernel_url}")
        download_cmds.append(f"echo 'Downloading {config.name} initramfs...'")
        download_cmds.append(f"curl -fSL --progress-bar --max-time 20 --retry 5 --retry-delay 2 -o {config.slug}-initramfs-{arch}.xz {initramfs_url}")

    full_cmd = "mkdir -p talos/" + talos_version + " && cd talos/" + talos_version + " && " + " && ".join(download_cmds)
    print(full_cmd)
    print("\n" + "=" * 60)


if __name__ == "__main__":
    main()
