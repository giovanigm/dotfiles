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
  };

  outputs = { self, nixpkgs, nixpkgs-master, impermanence, home-manager }@inputs: {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        impermanence.nixosModules.impermanence
        home-manager.nixosModules.home-manager
        ./configuration.nix
        ./hardware-configuration.nix
        ./persistence.nix
      ];
    };
  };
}
