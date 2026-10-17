{ lib, pkgs, ... }:
{
  nixpkgs.config.allowUnfreePredicate =
    pkg:
    lib.hasPrefix "steam" (lib.getName pkg)
    || builtins.elem (lib.getName pkg) [
      "vscode"
      "vscode-extension-anthropic-claude-code"
      "vscode-extension-MS-python-vscode-pylance"
    ];

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "root" "@wheel" ];
    auto-optimise-store = true;
  };
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.loader.systemd-boot = {
    enable = true;
    configurationLimit = 10;
  };
  # Leave NVRAM alone so Talos stays first in firmware boot order. systemd-boot
  # still installs the fallback EFI/BOOT/BOOTX64.EFI, so firmware sees this disk.
  boot.loader.efi.canTouchEfiVariables = false;

  hardware.cpu.intel.updateMicrocode = true;
  hardware.enableRedistributableFirmware = true;
  zramSwap.enable = true;

  networking.networkmanager.enable = true;
  time.timeZone = "America/Chicago";
  i18n.defaultLocale = "en_US.UTF-8";

  # mise downloads prebuilt, dynamically linked binaries (python, node, uv...). NixOS has
  # no /lib64/ld-linux; nix-ld provides one so they run unpatched.
  programs.nix-ld.enable = true;

  # Login shell for npawelek; root keeps the stock bash.
  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      mise activate fish | source
      function fish_prompt
        set -l dir (string replace -r '^.*/' "" (prompt_pwd))
        printf '%s@%s [%s%s%s]$ ' $USER $hostname (set_color red) $dir (set_color normal)
      end
    '';
  };

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  users.users.npawelek = {
    isNormalUser = true;
    shell = pkgs.fish;
    extraGroups = [ "wheel" "networkmanager" "video" "audio" "gamemode" ];
    # SSH is key-only; the console/SDDM/sudo password comes from secrets.nix.
    openssh.authorizedKeys.keys = import ../keys.nix;
  };

  environment.systemPackages = with pkgs; [ git vim htop pciutils usbutils jq mise nvd ];
}
