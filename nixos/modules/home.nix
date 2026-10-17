{
  # Home Manager as a NixOS module: user config builds with nixos-rebuild, no separate
  # home-manager command.
  home-manager = {
    # Same nixpkgs (and unfree list in base.nix) as the system.
    useGlobalPkgs = true;
    useUserPackages = true;
    # A file HM would replace (e.g. settings.json VS Code wrote) is renamed, not an error.
    backupFileExtension = "hm-bak";
    users.npawelek = import ../home/npawelek.nix;
  };
}
