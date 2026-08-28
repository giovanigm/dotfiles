{ config, pkgs, lib, ... }:

{
  services.xserver.enable = true;

  # ── Login: greetd + DMS greeter (replaces SDDM, qylock removed) ──
  # DankGreeter: DMS-look login screen. The nixpkgs module wires greetd
  # itself (dms-greeter user, cache dir, PAM, fonts) and syncs the DMS
  # theme/settings/wallpaper from configHome. qylock is fully removed —
  # DMS owns the lock screen (dms-lock.sh bind in hyprland.lua).
  services.displayManager.sddm.enable = false;
  services.displayManager.dms-greeter = {
    enable = true;
    compositor.name = "hyprland"; # niri | hyprland | sway — hyprland is proven on this NVIDIA box
    configHome = "/home/giovani"; # copy DMS settings/theme/wallpaper into the greeter
    logs.save = true;             # TESTING: /tmp/dms-greeter.log — remove after boot-test passes
  };
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
    # Hyprland (aquamarine): NVIDIA card only. The AMD iGPU is the boot VGA,
    # so it becomes primary DRM — compositing lands on the iGPU and frames
    # are copied to NVIDIA (multigpu/linear), capping the desktop at ~60fps
    # even though the mode is 144Hz. The name is a stable udev symlink
    # (see nvidia.nix) — AQ_DRM_DEVICES splits on ':' so by-path won't work.
    AQ_DRM_DEVICES = "/dev/dri/nvidia-card";
    # If cursor becomes invisible
    WLR_NO_HARDWARE_CURSORS = "1";
    # Cursor theme (Breeze Dark, same as home.nix pointerCursor) — for the
    # user session AND the pre-login greeter. greetd 0.10 execs the greeter
    # with ONLY the PAM envlist (pam_env → /etc/pam/environment), it does
    # NOT propagate the greetd service's Environment= lines. So this block
    # is the only channel that reaches the greeter's Hyprland.
    # HYPRCURSOR_* mirrors DMS's auto-generated cursor.lua (hyprcursor
    # falls back to the xcursor theme when no hyprcursor theme exists).
    XCURSOR_THEME = "breeze_cursors";
    XCURSOR_SIZE = "24";
    HYPRCURSOR_THEME = "breeze_cursors";
    HYPRCURSOR_SIZE = "24";
    # Hint Electron apps to use Wayland
    NIXOS_OZONE_WL = "1";
    # GTK4: force NVIDIA OpenGL backend (Vulkan default is buggy on NVIDIA)
    GSK_RENDERER = "ngl";
  };

  # ── Wait for GPU before starting greetd (prevents Wayland race) ─
  # NOTE on env: greetd 0.10 execs the greeter with ONLY the PAM envlist
  # (pam_env → /etc/pam/environment, generated from
  # environment.sessionVariables above) — it does NOT propagate this
  # service's Environment= lines. The greeter already receives the NVIDIA
  # vars through that channel; the list below is redundant and kept only
  # for reference.
  systemd.services.greetd = {
    after = [ "dev-dri-renderD128.device" ];
    serviceConfig = {
      # ExecStartPre is a list, so this merges with the dms-greeter
      # module's preStart (its own ExecStartPre job script).
      # Do NOT use preStart here — a second string definition conflicts.
      ExecStartPre = [
        "${pkgs.bash}/bin/bash -c 'for i in $(seq 1 50); do [ -e /dev/dri/renderD128 ] && exit 0; sleep 0.1; done'"
      ];
      # NVIDIA env vars for the pre-login greeter compositor (Hyprland).
      # AQ_DRM_DEVICES pins the greeter's Hyprland to the NVIDIA card via
      # the stable udev symlink (nvidia.nix) — the AMD iGPU is boot VGA and
      # would otherwise become primary DRM. THIS is the fix missing in
      # 89a857b (AQ_DRM_DEVICES postdates it, added in e2ea713).
      Environment = [
        "GBM_BACKEND=nvidia-drm"
        "__GLX_VENDOR_LIBRARY_NAME=nvidia"
        "LIBVA_DRIVER_NAME=nvidia"
        "AQ_DRM_DEVICES=/dev/dri/nvidia-card"
        "WLR_NO_HARDWARE_CURSORS=1"
        "GSK_RENDERER=ngl"
        # Video wallpaper in the greeter: pkgs.quickshell has no qtmultimedia
        # buildInputs; qt wrappers use --prefix so these survive the qs
        # wrapper and let the greeter decode .mp4 wallpapers.
        "NIXPKGS_QT6_QML_IMPORT_PATH=${pkgs.qt6.qtmultimedia}/${pkgs.qt6.qtbase.qtQmlPrefix}"
        "QT_PLUGIN_PATH=${pkgs.qt6.qtmultimedia}/${pkgs.qt6.qtbase.qtPluginPrefix}"
      ];
    };
  };

  # Cursor theme package available system-wide for the pre-login greeter
  environment.systemPackages = [ pkgs.kdePackages.breeze ];
}
