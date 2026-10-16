{
  imports = [
    ./disko.nix
    ./hardware-configuration.nix
    ./network.nix
    ../../modules/base.nix
    ../../modules/desktop.nix
    ../../modules/gaming.nix
    ../../modules/secrets.nix
  ];

  networking.hostName = "pella";

  systemd.tmpfiles.rules = [ "d /games 0755 npawelek users -" ];
  services.btrfs.autoScrub.enable = true;
  nixpkgs.hostPlatform = "x86_64-linux";

  # Release of first install. Never bump after install.
  system.stateVersion = "26.05";
}
