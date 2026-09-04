# nixos/configurations/packages/emulators.nix — emulators for the Windows
# "Emuladores" NTFS partition (see home.nix for data-dir symlinks)

{ config, pkgs, lib, inputs, ... }:

{
  environment.systemPackages = with pkgs; [
    rpcs3          # PS3 — needs nixpkgs.config.allowUnfree (already in system.nix)
    dolphin-emu    # Wii/GC
    # Eden (Switch) from nixpkgs-master for the newer 0.2.1 (26.05 channel has 0.1.1)
    inputs.nixpkgs-master.legacyPackages.${pkgs.stdenv.hostPlatform.system}.eden
  ];
}
