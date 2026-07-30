{ config, pkgs, ... }:

{
  imports = [
    ./configurations/nix.nix
    ./configurations/boot.nix
    ./configurations/networking.nix
    ./configurations/locale.nix
    ./configurations/desktop.nix
    ./configurations/nvidia.nix
    ./configurations/audio.nix
    ./configurations/docker.nix
    ./configurations/fonts.nix
    ./configurations/printing.nix
    ./configurations/users.nix
    ./configurations/programs.nix
    ./configurations/system.nix
  ];

  # ── Home Manager ─────────────────────────────────────────
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup";
    users.giovani = import ./home.nix;
  };

  system.stateVersion = "26.05";
}
