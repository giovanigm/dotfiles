{ config, pkgs, lib, ... }:

{
  services.xserver.enable = true;

  # ── Login: SDDM with the qylock theme (see configurations/qylock.nix) ──
  services.displayManager.sddm.enable = true;
  services.displayManager.defaultSession = "hyprland-uwsm"; # .desktop basename of the UWSM-wrapped session

  # ── Hyprland ──────────────────────────────────────────────
  programs.hyprland = {
    enable = true;
    withUWSM = true;       # Recommended launcher on NixOS 24.11+
    xwayland.enable = true;
  };

  # ── DMS backend services ─────────────────────────────────
  # DankMaterialShell's power profile / battery widgets and
  # location-based auto light/dark theming need these D-Bus
  # services (DMS's own NixOS module enables them by default).
  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;
  services.geoclue2.enable = true;
  services.accounts-daemon.enable = true; # DMS lock-screen user accounts

  # ── XDG menu for the Hyprland session ─────────────────────
  # UWSM sets XDG_MENU_PREFIX=hyprland-, but no
  # hyprland-applications.menu exists → KDE apps' "Open with…"
  # dialogs would be empty (flagged by `dms doctor`).
  environment.etc."xdg/menus/hyprland-applications.menu".text = ''
    <?xml version="1.0" ?>
    <!DOCTYPE Menu PUBLIC "-//freedesktop//DTD Menu 1.0//EN"
      "http://www.freedesktop.org/standards/menu-spec/1.0/menu.dtd">
    <Menu>
      <Name>Applications</Name>
      <Menu>
        <Name>Accessories</Name>
        <Include>
          <And>
            <Category>Utility</Category>
            <Not><Category>System</Category></Not>
          </And>
        </Include>
      </Menu>
      <Menu>
        <Name>Development</Name>
        <Include><Category>Development</Category></Include>
      </Menu>
      <Menu>
        <Name>Games</Name>
        <Include><Category>Game</Category></Include>
      </Menu>
      <Menu>
        <Name>Graphics</Name>
        <Include><Category>Graphics</Category></Include>
      </Menu>
      <Menu>
        <Name>Internet</Name>
        <Include>
          <And>
            <Category>Network</Category>
            <Not><Category>System</Category></Not>
          </And>
        </Include>
      </Menu>
      <Menu>
        <Name>Multimedia</Name>
        <Include><Category>AudioVideo</Category></Include>
      </Menu>
      <Menu>
        <Name>Office</Name>
        <Include><Category>Office</Category></Include>
      </Menu>
      <Menu>
        <Name>System</Name>
        <Include><Category>System</Category></Include>
      </Menu>
      <DefaultLayout inline="false"/>
      <Layout>
        <Merge type="menus"/>
        <Separator/>
        <Merge type="all"/>
      </Layout>
    </Menu>
  '';

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-hyprland ];
  };

  environment.sessionVariables = {
    # NVIDIA + Wayland
    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    LIBVA_DRIVER_NAME = "nvidia";
    # If cursor becomes invisible
    WLR_NO_HARDWARE_CURSORS = "1";
    # Hint Electron apps to use Wayland
    NIXOS_OZONE_WL = "1";
    # GTK4: force NVIDIA OpenGL backend (Vulkan default is buggy on NVIDIA)
    GSK_RENDERER = "ngl";
  };

  # ── Wait for GPU before starting SDDM (prevents Wayland race) ─
  systemd.services.display-manager = {
    after = [ "dev-dri-renderD128.device" ];
    preStart = ''
      for i in $(seq 1 50); do
        [ -e /dev/dri/renderD128 ] && break
        sleep 0.1
      done
    '';
  };

  # Cursor theme package available system-wide for the pre-login greeter
  environment.systemPackages = [ pkgs.kdePackages.breeze ];
}
