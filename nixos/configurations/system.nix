{ config, pkgs, lib, ... }:

{
  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.permittedInsecurePackages = [
    "electron-39.8.10"
  ];

  # ── Expose thumbnailer definitions for Nautilus ────────────
  environment.pathsToLink = [ "share/thumbnailers" ];

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

  # ── Sushi video preview: fix OpenGL init on NVIDIA + Wayland ─
  # Sushi runs as a D-Bus service, so shell env vars don't reach it.
  systemd.user.extraConfig = ''
    DefaultEnvironment=GDK_GL=gles SUSHI_USE_GST_GTKSINK=1
  '';

  # ── Impermanence: recreate /etc/nixos symlink on boot ────
  systemd.tmpfiles.rules = [
    "L+ /etc/nixos - - - - /home/giovani/dev/dotfiles/nixos"
  ];
}
