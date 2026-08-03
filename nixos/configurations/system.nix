{ config, pkgs, lib, ... }:

{
  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.permittedInsecurePackages = [
    "electron-39.8.10"
  ];

  # ── Hyprland Polkit Authentication Agent ─────────────────
  systemd.user.services.hyprpolkitagent = {
    description = "Hyprland Polkit Authentication Agent";
    wantedBy = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    unitConfig = {
      ConditionEnvironment = "WAYLAND_DISPLAY";
    };
    serviceConfig = {
      ExecStart = "${pkgs.hyprpolkitagent}/libexec/hyprpolkitagent";
      Slice = "session.slice";
      TimeoutStopSec = 5;
      Restart = "on-failure";
    };
  };

  # ── Impermanence: recreate /etc/nixos symlink on boot ────
  systemd.tmpfiles.rules = [
    "L+ /etc/nixos - - - - /home/giovani/dev/dotfiles/nixos"
  ];
}
