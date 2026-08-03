# nixos/configurations/packages/cli.nix — Core CLI utilities

{ config, pkgs, lib, ... }:

{
  # ── Core CLI Utilities ────────────────────────────────────
  environment.systemPackages = with pkgs; [
    vim
    jq
    efibootmgr

    # ── System monitoring ───────────────────────────────────
    bottom
    ddcutil
  ];
}
