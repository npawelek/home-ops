{
  imports = [
    ./disko.nix
    ./hardware-configuration.nix
    ./network.nix
    ../../modules/base.nix
    ../../modules/desktop.nix
    ../../modules/gaming.nix
    ../../modules/home.nix
    ../../modules/nfs.nix
    ../../modules/secrets.nix
    ../../modules/streaming.nix
  ];

  networking.hostName = "pella";

  systemd.tmpfiles.rules = [
    "d /games 0755 npawelek users -"
    # Plain `nixos-rebuild` (no --flake) follows this link to the repo checkout.
    "L+ /etc/nixos/flake.nix - - - - /home/npawelek/github/home-ops/nixos/flake.nix"
  ];
  services.btrfs.autoScrub.enable = true;
  nixpkgs.hostPlatform = "x86_64-linux";

  # Release of first install. Never bump after install.
  system.stateVersion = "26.05";
}
