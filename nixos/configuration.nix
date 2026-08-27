{ config, pkgs, inputs, ... }:

{
  imports = [
    ./configurations/nix.nix
    ./configurations/boot.nix
    ./configurations/networking.nix
    ./configurations/locale.nix
    ./configurations/desktop.nix
    ./configurations/filesystems.nix
    ./configurations/nvidia.nix
    ./configurations/ddcutil.nix
    ./configurations/fans.nix
    ./configurations/audio.nix
    ./configurations/docker.nix
    ./configurations/fonts.nix
    ./configurations/packages/apps.nix
    ./configurations/packages/dev.nix
    ./configurations/packages/sdks.nix
    ./configurations/packages/cli.nix
    ./configurations/printing.nix
    ./configurations/users.nix
    ./configurations/programs.nix
    ./configurations/nix-ld.nix
    ./configurations/system.nix
  ];

  # ── Home Manager ─────────────────────────────────────────
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup";
    extraSpecialArgs = { inherit inputs; }; # home.nix needs inputs.dms
    users.giovani = import ./home.nix;
  };

  system.stateVersion = "26.05";
}
