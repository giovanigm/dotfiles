{ config, pkgs, lib, ... }:

{
  users.mutableUsers = false;

  users.users."giovani" = {
    isNormalUser = true;
    description = "giovani";
    extraGroups = [ "networkmanager" "wheel" "docker" ];
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
      discord
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

      # zen-browser not in nixpkgs — install via flatpak:
      #   flatpak install io.github.zen_browser.zen
    ];
  };
}
