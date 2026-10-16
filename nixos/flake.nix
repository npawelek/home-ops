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
  };

  outputs = { nixpkgs, disko, sops-nix, ... }: {
    nixosConfigurations = {
      # Gaming box. Dual boots with Talos (pella worker) on separate disks.
      pella = nixpkgs.lib.nixosSystem {
        modules = [
          disko.nixosModules.disko
          sops-nix.nixosModules.sops
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
