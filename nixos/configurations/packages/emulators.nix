# nixos/configurations/packages/emulators.nix — emulators for the Windows
# "Emuladores" NTFS partition (see home.nix for data-dir symlinks)

{ config, pkgs, lib, inputs, ... }:

let
  inherit (pkgs.stdenv.hostPlatform) system;
  master = inputs.nixpkgs-master.legacyPackages.${system};

  # Eden (Switch) from nixpkgs-master for the newer 0.2.1 (26.05 channel has 0.1.1).
  # Two fixes on top of the plain package:
  # 1. Eden's Wayland UI is known-broken upstream, so force xcb/XWayland for
  #    every launch path (DMS spotlight, terminal, ...).
  # 2. The file dialog is a GTK3 dialog (QT_QPA_PLATFORMTHEME=gtk3), but apps
  #    launched from DMS spotlight inherit an XDG_DATA_DIRS without any
  #    GSettings schemas — GTK3 aborts with "No GSettings schemas are
  #    installed on the system" (SIGABRT on Load File/Folder). Prepend the
  #    gtk3 + gsettings-desktop-schemas schema dirs from both channels: the
  #    dialog loads gtk3 from the session's qt6gtk3 plugin and Eden's own deps.
  eden = pkgs.symlinkJoin {
    name = "eden-wrapped";
    paths = [ master.eden ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      for bin in eden eden-cli eden-room; do
        wrapProgram $out/bin/$bin \
          --set QT_QPA_PLATFORM xcb \
          --set SDL_VIDEODRIVER x11 \
          --prefix XDG_DATA_DIRS : ${pkgs.gtk3}/share/gsettings-schemas/gtk+3-${pkgs.gtk3.version} \
          --prefix XDG_DATA_DIRS : ${master.gtk3}/share/gsettings-schemas/gtk+3-${master.gtk3.version} \
          --prefix XDG_DATA_DIRS : ${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/gsettings-desktop-schemas-${pkgs.gsettings-desktop-schemas.version}
      done
    '';
  };
in
{
  environment.systemPackages = with pkgs; [
    rpcs3          # PS3 — needs nixpkgs.config.allowUnfree (already in system.nix)
    dolphin-emu    # Wii/GC
    eden
  ];
}
