{ config, pkgs, lib, ... }:

{
  # ── Docker ───────────────────────────────────────────────
  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
    autoPrune.dates = "weekly";
  };
}
