{ config, pkgs, lib, inputs, ... }:

{
  users.mutableUsers = false;

  users.users."giovani" = {
    isNormalUser = true;
    description = "giovani";
    extraGroups = [ "networkmanager" "wheel" "docker" "i2c" ];
    shell = pkgs.zsh;
    hashedPasswordFile = "/persist/passwords/giovani";
    packages = with pkgs; [
      # Already installed
      kdePackages.kate
      ghostty
      claude-code

      # Apps
      bitwarden-desktop
      brave
      (discord.overrideAttrs (old: {
        postInstall = (old.postInstall or "") + ''
          gappsWrapperArgs+=("--add-flags" "--enable-features=WebRTCPipeWireCapturer")
        '';
      }))
      obsidian
      spotify

      # Media / Gaming
      vlc
      steam
      gimp
      qbittorrent
      qalculate-gtk
      pavucontrol

      # Dev / DB
      dbeaver-bin
      postman
      android-studio
      android-tools
      gnumake

      # System monitoring
      bottom
      ddcutil

      # Editor
      neovim

      # Launcher
      rofi

      # Notification daemon (prevents Electron apps from freezing)
      mako

      # Desktop environment (was in home.packages, moved here)
      awww
      cava
      waybar
      hyprlock
      networkmanagerapplet
      networkmanager_dmenu
      hyprpolkitagent

      inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];
  };
}
