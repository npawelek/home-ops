{
  description = "NixOS hosts";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Declarative Plasma settings (fonts, ...) as a Home Manager module.
    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
    # SF Pro / SF Mono, fetched from Apple's developer site at build time.
    apple-fonts = {
      url = "github:Lyndeno/apple-fonts.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ nixpkgs, disko, sops-nix, home-manager, ... }: {
    nixosConfigurations = {
      # Gaming box. Dual boots with Talos (pella worker) on separate disks.
      pella = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs; };
        modules = [
          disko.nixosModules.disko
          sops-nix.nixosModules.sops
          home-manager.nixosModules.home-manager
          ./hosts/pella
        ];
      };

      # RAM-only installer for iPXE: SSH with keys.nix, nothing else.
      netboot = nixpkgs.lib.nixosSystem {
        modules = [ ./hosts/netboot ];
      };
    };
  };
}
