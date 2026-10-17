{
  services.desktopManager.plasma6.enable = true;
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };

  # Plasma's Bluedevil applet only appears when this is on.
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Electron apps (VS Code) run native Wayland instead of XWayland: sharp text on Plasma.
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  # Extensions install from AMO on first start and auto-update; force_installed means
  # they cannot be removed in the UI, only here. Keys are the add-on IDs.
  programs.firefox = {
    enable = true;
    policies.ExtensionSettings =
      let
        amo = slug: {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/${slug}/latest.xpi";
          installation_mode = "force_installed";
        };
      in
      {
        "{446900e4-71c2-419f-a6a7-df9c091e268b}" = amo "bitwarden-password-manager";
        "uBlock0@raymondhill.net" = amo "ublock-origin";
        "{73a6fe31-595d-460b-a920-fcc0f8843232}" = amo "noscript";
        "sponsorBlocker@ajay.app" = amo "sponsorblock";
      };
  };
}
