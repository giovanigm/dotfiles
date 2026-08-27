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

    # DankMaterialShell — all-in-one desktop shell (bar, launcher, lock, idle)
    dms = {
      url = "github:AvengeMedia/DankMaterialShell";
      inputs.nixpkgs.follows = "nixpkgs"; # its modules build dms-shell with the caller's pkgs
    };

    zen-browser = {
      url = "github:youwen5/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    distro-grub-themes = {
      url = "github:AdisonCavani/distro-grub-themes";
      inputs.nixpkgs.follows = "nixpkgs"; # their default is nixos-unstable — avoid a second nixpkgs
    };
  };

  outputs = { self, nixpkgs, nixpkgs-master, impermanence, home-manager, dms, zen-browser, distro-grub-themes }@inputs: {
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
