#!/bin/sh
# Runs on the netboot.xyz host (piped over ssh by `task ipxe:deploy-nixos`).
# Adds a NixOS entry to the main menu next to the hand-added Talos one. Idempotent.
# -custom suffix, like talos-custom.ipxe: netboot.xyz ships its own nixos.ipxe (stock
# Linux Network Installs → NixOS); never overwrite it.
# local/ holds the overrides netboot.xyz copies over menus/ on upgrade, so patch both.
set -eu

menus="${1:?usage: $0 <netboot menu path>}"

# dnsmasq runs --tftp-secure: it only serves files owned by its user (nbxyz, 1000).
cp "$menus/nixos-custom.ipxe" "$menus/local/nixos-custom.ipxe"
chown 1000:1000 "$menus/local/nixos-custom.ipxe"

for f in "$menus/local/menu.ipxe" "$menus/menu.ipxe"; do
  grep -q '^:nixos_netboot$' "$f" && continue
  # ${space} is iPXE syntax, written literally into the menu.
  # shellcheck disable=SC2016
  sed -i \
    -e '/^item talos_custom /a item nixos_netboot ${space} NixOS Netboot Installer ||' \
    -e '/^:error$/i :nixos_netboot\nchain nixos-custom.ipxe || goto error\ngoto main_menu\n' \
    "$f"
  if ! grep -q '^item nixos_netboot ' "$f" || ! grep -q '^:nixos_netboot$' "$f"; then
    echo "hook failed: $f" >&2
    exit 1
  fi
  echo "hooked: $f"
done
