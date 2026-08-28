{ config, pkgs, lib, ... }:

{
  # ── NVIDIA Proprietary Driver (for RTX 3080 LHR) ──────────
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.graphics = {
    enable = true;
    enable32Bit = true;              # Required for Steam (32-bit client + games)
    extraPackages = with pkgs; [
      nvidia-vaapi-driver      # VA-API hardware video acceleration
    ];
    extraPackages32 = with pkgs.pkgsi686Linux; [
      nvidia-vaapi-driver      # 32-bit VA-API for 32-bit games
    ];
  };

  hardware.nvidia = {
    open = true;                   # Open kernel module (Turing/Ampere+, works on RTX 3080)
    modesetting.enable = true;     # Required for Wayland compositors
    powerManagement.enable = true; # Proper suspend/resume
    nvidiaSettings = true;         # nvidia-settings GUI tool
  };

  # Preserve video memory across suspend/resume
  boot.kernelParams = [ "nvidia.NVreg_PreserveVideoMemoryAllocations=1" ];

  # Stable /dev/dri/nvidia-card symlink. Card numbering (card0/card1) races
  # between the NVIDIA and AMD GPUs at boot; aquamarine's AQ_DRM_DEVICES
  # (desktop.nix) pins Hyprland to the NVIDIA card via this name. udev keeps
  # the symlink correct regardless of which number the card gets.
  services.udev.extraRules = ''
    SUBSYSTEM=="drm", KERNEL=="card*", KERNELS=="0000:01:00.0", SYMLINK+="dri/nvidia-card"
  '';
}
