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
}
