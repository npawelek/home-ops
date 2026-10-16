{ modulesPath, pkgs, ... }:
{
  imports = [ "${modulesPath}/installer/netboot/netboot-minimal.nix" ];

  nixpkgs.hostPlatform = "x86_64-linux";
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  services.openssh.enable = true;
  users.users.root.openssh.authorizedKeys.keys = import ../../keys.nix;

  # Clone the flake straight from the installer.
  environment.systemPackages = [ pkgs.git ];

  system.stateVersion = "26.05";
}
