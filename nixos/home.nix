{ config, pkgs, inputs, ... }: {
  imports = [
    ./home/sdks.nix
    inputs.dms.homeModules.dank-material-shell
  ];

  home.username = "giovani";
  home.homeDirectory = "/home/giovani";
  home.stateVersion = "26.05";

  # ── DankMaterialShell — all-in-one shell (bar, launcher, lock, idle) ──
  programs.dank-material-shell = {
    enable = true;
    systemd.enable = true; # dms.service bound to graphical-session.target (UWSM)
    enableDynamicTheming = false; # matugen can't sample the mpvpaper video wallpaper
    # No settings declared: DMS's Settings GUI owns ~/.config/DankMaterialShell/settings.json
  };

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
      # Images → imv
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
      # Web → Zen
      "text/html" = [ "zen.desktop" ];
      "application/xhtml+xml" = [ "zen.desktop" ];
      "x-scheme-handler/http" = [ "zen.desktop" ];
      "x-scheme-handler/https" = [ "zen.desktop" ];
      "x-scheme-handler/chrome" = [ "zen.desktop" ];
      # PDF / comics → GIMP
      "application/pdf" = [ "gimp.desktop" ];
      "application/vnd.comicbook+zip" = [ "gimp.desktop" ];
      "application/vnd.comicbook-rar" = [ "gimp.desktop" ];
      "application/x-bzpdf" = [ "gimp.desktop" ];
      "application/x-ext-pdf" = [ "gimp.desktop" ];
      "application/x-gzpdf" = [ "gimp.desktop" ];
      # Text / code → Neovim
      "application/json" = [ "nvim.desktop" ];
      "application/x-zerosize" = [ "nvim.desktop" ];
      "text/markdown" = [ "nvim.desktop" ];
      "text/plain" = [ "nvim.desktop" ];
      "text/x-c++src" = [ "nvim.desktop" ];
      "text/x-csrc" = [ "nvim.desktop" ];
      "text/x-python" = [ "nvim.desktop" ];
      "text/x-shellscript" = [ "nvim.desktop" ];
      # Claude Code URL handler (claude.ai links)
      "x-scheme-handler/claude-cli" = [ "claude-code-url-handler.desktop" ];
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
