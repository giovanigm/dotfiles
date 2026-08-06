{ config, pkgs, lib, ... }:

{
  services.xserver.enable = true;

  services.displayManager.sddm.enable = true;
  # ── Hyprland ──────────────────────────────────────────────
  programs.hyprland = {
    enable = true;
    withUWSM = true;       # Recommended launcher on NixOS 24.11+
    xwayland.enable = true;
  };

  # Hyprlock PAM authentication (required for unlocking)
  security.pam.services.hyprlock = {};

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
}
