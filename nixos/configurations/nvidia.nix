{ config, pkgs, lib, ... }:

{
  # ── NVIDIA Proprietary Driver (for RTX 3080 LHR) ──────────
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      nvidia-vaapi-driver      # VA-API hardware video acceleration
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
