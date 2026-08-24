# nixos/configurations/packages/cli.nix — Core CLI utilities

{ config, pkgs, lib, ... }:

{
  # ── Core CLI Utilities ────────────────────────────────────
  environment.systemPackages = with pkgs; [
    vim
    jq
    efibootmgr

    # ── Screenshots (grim + slurp + satty) ──────────────────
    grim
    slurp
    satty
    wl-clipboard
    libnotify  # notify-send — screenshot notifications

    # ── System monitoring ───────────────────────────────────
    bottom
    ddcutil
  ];
}
