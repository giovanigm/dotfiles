{ config, pkgs, lib, ... }:

{
  # ── Fonts ────────────────────────────────────────────────
  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
  ];
}
