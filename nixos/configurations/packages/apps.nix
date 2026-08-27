# nixos/configurations/packages/apps.nix — GUI apps + desktop environment

{ config, pkgs, lib, inputs, ... }:

{
  # ── GUI Applications ──────────────────────────────────────
  environment.systemPackages = with pkgs; [
    ghostty
    claude-code
    nautilus
    ffmpegthumbnailer
    sushi
    bitwarden-desktop
    brave
    (discord.overrideAttrs (old: {
      postInstall = (old.postInstall or "") + ''
        gappsWrapperArgs+=("--add-flags" "--enable-features=WebRTCPipeWireCapturer")
      '';
    }))
    obsidian
    spotify

    # Zen Browser (flake input)
    inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default

    # ── Media / Gaming ──────────────────────────────────────
    vlc
    steam
    cemu
    gimp
    qbittorrent
    qalculate-gtk
    pavucontrol

    # ── Desktop environment ─────────────────────────────────
    awww
    quickshell
    hyprlock
    networkmanagerapplet
    networkmanager_dmenu
    hyprpolkitagent

    # ── Icons ───────────────────────────────────────────────
    catppuccin-papirus-folders

    # ── Image viewer ────────────────────────────────────────
    imv

    # ── Launcher ────────────────────────────────────────────
    rofi

    # ── Notification daemon (prevents Electron apps from freezing) ──
    mako
  ];
}
