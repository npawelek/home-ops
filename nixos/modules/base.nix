{ pkgs, ... }:
{
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

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  users.users.npawelek = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "video" "audio" "gamemode" ];
    # SSH is key-only; the console/SDDM/sudo password comes from secrets.nix.
    openssh.authorizedKeys.keys = import ../keys.nix;
  };

  environment.systemPackages = with pkgs; [ git vim htop pciutils usbutils ];
}
