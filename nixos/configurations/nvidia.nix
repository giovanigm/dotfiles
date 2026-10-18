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
    # Closed kernel module. Chosen during HDMI-TV debugging: the open
    # module also never produced a working ELD on this setup, and
    # NVreg_EnableGpuFirmware=0 (below) is closed-only. HDMI audio works
    # now via the RMConnectToAudio regkey — re-test before ever flipping
    # this back to open.
    open = false;
    modesetting.enable = true;     # Required for Wayland compositors
    powerManagement.enable = true; # Proper suspend/resume
    nvidiaSettings = true;         # nvidia-settings GUI tool
  };

  # Preserve video memory across suspend/resume.
  # hdmi_deepcolor=0 + disable_hdmi_frl=1: HDMI TVs on Ampere request deep
  # color / HDMI 2.1 FRL the driver can't sync, giving "no signal" (the TV
  # was never even detected). Falls back to HDMI 2.0 / 8-bit — DP
  # unaffected. Untested which of the two is the decisive one; remove
  # selectively to re-test someday.
  # RMConnectToAudio=1: THE HDMI audio fix. RM dword forcing the
  # display-to-audio hookup — without it the ELD is never written to the
  # HDA codec (pin sense stays empty, kernel rejects HDMI playback with
  # EINVAL) even though the EDID is valid. Verified on 595.71.05 and
  # 615.78.08, kernels 6.12 and 6.18.
  # EnableGpuFirmware=0 (GSP off): added during the same debugging; never
  # proven necessary once the regkey was found. Closed driver only.
  # Candidate for re-testing with GSP on.
  boot.kernelParams = [
    "nvidia.NVreg_PreserveVideoMemoryAllocations=1"
    "nvidia.NVreg_EnableGpuFirmware=0"
    "nvidia.NVreg_RegistryDwords=RMConnectToAudio=1"
    "nvidia_modeset.hdmi_deepcolor=0"
    "nvidia_modeset.disable_hdmi_frl=1"
  ];

  # Stable /dev/dri/nvidia-card symlink. Card numbering (card0/card1) races
  # between the NVIDIA and AMD GPUs at boot; aquamarine's AQ_DRM_DEVICES
  # (desktop.nix) pins Hyprland to the NVIDIA card via this name. udev keeps
  # the symlink correct regardless of which number the card gets.
  services.udev.extraRules = ''
    SUBSYSTEM=="drm", KERNEL=="card*", KERNELS=="0000:01:00.0", SYMLINK+="dri/nvidia-card"
  '';
}
