{ config, pkgs, ... }: {
  imports = [ ./home/sdks.nix ];

  home.username = "giovani";
  home.homeDirectory = "/home/giovani";
  home.stateVersion = "26.05";

  # ── Cursor theme (Breeze Dark) ───────────────────────────
  home.pointerCursor = {
    gtk.enable = true;
    name = "breeze_cursors";
    package = pkgs.kdePackages.breeze;
    size = 24;
  };

  # ── GTK (required for cursor + theming) ──────────────────
  gtk = {
    enable = true;
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.catppuccin-papirus-folders;
    };
  };

  # ── Default apps ────────────────────────────────────────
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "image/jpeg" = [ "imv-dir.desktop" ];
      "image/png" = [ "imv-dir.desktop" ];
      "image/gif" = [ "imv-dir.desktop" ];
      "image/webp" = [ "imv-dir.desktop" ];
      "image/svg+xml" = [ "imv-dir.desktop" ];
      "image/tiff" = [ "imv-dir.desktop" ];
      "image/bmp" = [ "imv-dir.desktop" ];
      "image/avif" = [ "imv-dir.desktop" ];
      "image/heic" = [ "imv-dir.desktop" ];
      "image/*" = [ "imv-dir.desktop" ];
    };
  };

  programs.mpvpaper = {
    enable = true;
    package = pkgs.mpvpaper.overrideAttrs (old: {
      version = "1.9";
      src = pkgs.fetchFromGitHub {
        owner = "GhostNaN";
        repo = "mpvpaper";
        rev = "1.9";
        hash = "sha256-FpwMhzYmbjwvbpJd6xDRka6h2bvgsqdopqP5deQKXSA=";
      };
    });
    # No pauseList: mpvpaper pauses whenever a listed process runs. The
    # Steam client (and Firefox) stay open in the background, so the
    # wallpaper was effectively always paused/frozen. If a game needs the
    # GPU later, list its binary here instead of the launcher (e.g. cs2).
  };
}
