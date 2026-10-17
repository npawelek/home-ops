{ pkgs, ... }:
{
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # ntsync: kernel-side Wine/Proton sync primitives, used by Proton-GE when present.
  boot.kernelModules = [ "ntsync" ];
  services.udev.extraRules = ''
    KERNEL=="ntsync", MODE="0666"
  '';

  boot.kernel.sysctl = {
    "kernel.split_lock_mitigate" = 0;
    "vm.max_map_count" = 2147483642;
  };

  programs.steam = {
    enable = true;
    gamescopeSession.enable = true;
    extraCompatPackages = [ pkgs.proton-ge-bin ];
  };
  programs.gamemode.enable = true;
  programs.gamescope.enable = true;

  # Battle.net games: Lutris Battle.net installer, runner GE-Proton via umu.
  environment.systemPackages = with pkgs; [ mangohud lutris umu-launcher ];
}
