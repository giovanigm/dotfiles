{
  description = "NixOS configuration with impermanence";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    # Allow unfree packages via nixpkgs config
    nixpkgs-master.url = "github:NixOS/nixpkgs/master";

    impermanence.url = "github:nix-community/impermanence";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    qylock = {
      url = "github:Darkkal44/qylock";
      inputs.nixpkgs.follows = "nixpkgs-master";  # quickshell not in stable yet
    };

    zen-browser = {
      url = "github:youwen5/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-master, impermanence, home-manager, qylock, zen-browser }@inputs: {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        impermanence.nixosModules.impermanence
        home-manager.nixosModules.home-manager
        qylock.nixosModules.default
        ./configuration.nix
        ./hardware-configuration.nix
        ./persistence.nix
      ];
    };
  };
}
