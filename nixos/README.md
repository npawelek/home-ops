# NixOS

Flake for NixOS hosts. Lives here for now; may move to its own repo (with sops-nix).

| Host | What |
|---|---|
| `pella` | Gaming box (i7-14700K, RX 9070 XT). Dual boots with the Talos `pella` worker. |
| `netboot` | RAM-only installer for iPXE. SSH as root with `keys.nix`. |

```
flake.nix
keys.nix                 SSH public keys (user + netboot root)
hosts/pella/             host config, disko layout, generated hardware config
hosts/netboot/           netboot installer
modules/                 base, desktop (Plasma 6), gaming (Steam, Lutris, ntsync)
```

## Dual boot with Talos

Three NVMe disks: Talos OS, Talos data, NixOS. Each OS owns its disk and its own ESP.

- NixOS never writes NVRAM (`canTouchEfiVariables = false`). Firmware boots it via the
  fallback `EFI/BOOT/BOOTX64.EFI`. Keep Talos first in boot order so the node returns
  after a power loss; pick NixOS from the firmware boot menu (F11) to game.
- Every disk selector must use a serial / by-id path, never `/dev/nvmeXn1`. That
  applies to `hosts/pella/disko.nix` and the Talos patches in `talos/node/pella/`.
- Drain the Talos node before switching (`kubectl drain pella --ignore-daemonsets
  --delete-emptydir-data`), or Longhorn starts rebuilding replicas elsewhere.

## Install

Flakes only see git-tracked files. `git add` new files (staging is enough) before any
`nix` command, or they are silently missing.

1. Boot the `netboot` image (netboot.xyz main menu → NixOS Netboot Installer) and
   `ssh root@<ip>`. Fallbacks: the stock netboot.xyz NixOS entry or a USB installer (set a
   root password on console).
2. Find the NixOS disk: `ls -l /dev/disk/by-id/ | grep nvme`. Set it in
   `hosts/pella/disko.nix`. Double check it is not a Talos disk; disko wipes it.
3. Install, from a machine with Nix. `extra/nix/persist/sops-nix/key.txt` holds the host
   age key (see Secrets):
   ```sh
   nix run github:nix-community/nixos-anywhere -- \
     --flake .#pella \
     --generate-hardware-config nixos-generate-config ./hosts/pella/hardware-configuration.nix \
     --extra-files ./extra \
     --build-on remote \
     root@<ip>
   ```
   Or on the live installer itself:
   ```sh
   git clone https://github.com/npawelek/home-ops /tmp/home-ops && cd /tmp/home-ops/nixos
   # edit hosts/pella/disko.nix, then:
   nixos-generate-config --no-filesystems --show-hardware-config > hosts/pella/hardware-configuration.nix
   git add -A
   nix --extra-experimental-features 'nix-command flakes' run github:nix-community/disko/latest -- \
     --mode destroy,format,mount --flake .#pella
   # host age key (see Secrets): paste it, then Ctrl-D
   install -D -m 0600 /dev/stdin /mnt/nix/persist/sops-nix/key.txt
   nixos-install --flake .#pella --no-root-passwd
   # before reboot, copy back flake.lock, disko.nix, hardware-configuration.nix and commit them
   ```
4. Reboot into NixOS and log in with the password from `secrets/pella.sops.yaml`.

## Secrets

[sops-nix](https://github.com/Mic92/sops-nix) decrypts `secrets/<hostname>.sops.yaml` at
activation into `/run/secrets*` (`modules/secrets.nix`). Recipients are set in the repo's
`.sops.yaml`: the `nixos_admin` key (workstation, never in the cluster) and the host key.

- Host key: `/nix/persist/sops-nix/key.txt` (0600). It lives in `@nix`, so rebuilds and
  reinstalls keep it; only a fresh disk needs it copied in (Install step 3). Back it up in
  the password manager.
- User password: `npawelek-password`, a `mkpasswd -m yescrypt` hash. `users.mutableUsers`
  is off, so `passwd` does not persist; edit with `sops nixos/secrets/pella.sops.yaml`
  and rebuild. SSH (keys.nix) works even if decryption fails.
- New host: `age-keygen -pq`, add its public key to `.sops.yaml`, create
  `secrets/<hostname>.sops.yaml`, then `sops updatekeys` any shared file.

## Reinstall without losing data

Rebuilds never touch `/home` or `/games`. A full reinstall with disko wipes the disk, so
recreate only `@root` instead. `@nix` stays, and with it the sops host key. From the live installer:
```sh
mount -o subvol=/ /dev/disk/by-partlabel/disk-nixos-root /mnt
btrfs subvolume delete /mnt/@root && btrfs subvolume create /mnt/@root && umount /mnt
nix --extra-experimental-features 'nix-command flakes' run github:nix-community/disko/latest -- \
  --mode mount --flake .#pella
nixos-install --flake .#pella --no-root-passwd
```

## Iterate

On the box: `sudo nixos-rebuild switch --flake ~/home-ops/nixos#pella`.
Update inputs: `nix flake update`, rebuild, commit `flake.lock`. Bad change: pick the
previous generation in the systemd-boot menu.

## Netboot image

Built in-cluster by the Flux-managed Job `kubernetes/apps/nix-build/builder`. It builds
`nixos#netboot` from `main` and writes `bzImage`, `initrd` and `netboot.ipxe` to nas
over NFS (NixOS version, e.g. `26.11.20261011.7fd4004`), keeps the 2 newest
(latest + one rollback), and points `latest` at the newest. `task ipxe:deploy-nixos`
copies one of them on the NAS into the netboot.xyz assets (`http://192.168.0.9/nixos/`)
and syncs the menu, like `task ipxe:deploy` does for Talos.

- Rebuilds run when `flake.nix`, `flake.lock`, `keys.nix` or `hosts/netboot/default.nix`
  change on `main`. Renovate opens a weekly `flake.lock` maintenance PR; merging it rebuilds.
  A new `flake.lock` gives a new version folder; other inputs replace the current one.
- Publish after the Job completes: `task ipxe:deploy-nixos` (publishes `latest`).
  Roll back: `task ipxe:deploy-nixos VERSION=<version>`.
- Build logs: `kubectl -n nix-build logs job/nixos-netboot`.
- Rebuild without a change: `kubectl -n nix-build delete job nixos-netboot`, then
  `task reconcile` (Flux re-creates the Job).
