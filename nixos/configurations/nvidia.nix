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
    # Closed kernel module. The open one never binds the HDA audio component
    # on this setup: ELD stays monitor_present=0, the kernel rejects HDMI
    # playback (EINVAL) and TV audio is dead (video is fine). Only the
    # amdgpu iGPU binds its audio component. Re-test HDMI audio before
    # ever flipping this back to open.
    open = false;
    # 615.78.08 from nixpkgs-master (hashes below): the 26.05 channel's
    # 595.71.05 never registers the DRM audio component at runtime on any
    # tested combo (6.18/6.12 × open/closed × GSP on/off) — the binary has
    # the code but the registration is silently gated, so snd_hda_intel
    # never binds and HDMI audio is dead. mkDriver builds it against our
    # kernel. Drop this override when the channel catches up.
    package = config.boot.kernelPackages.nvidiaPackages.mkDriver {
      version = "615.78.08";
      sha256_64bit = "sha256-Pj9t3cLudnoIGFMAr3vjyyhuznZpjS3eNSRZl4LQf/4=";
      sha256_aarch64 = "sha256-UHYBE1AYHoGgMfD9AS/jX+S+N8eCDWUft6qolK9Eejc=";
      openSha256 = "sha256-HBINiOjL0ZJLIAJeNIBYHBnwgUXtNwPPtnFpAI1YwF4=";
      settingsSha256 = "sha256-inDRpG02sdDgHmlqgu/DsgK8OFdOt1fZIYyXdhlGC/c=";
      persistencedSha256 = "sha256-RzeR6Ldct6MUxjnXRyThdh5Y3jjMehTVg85MtwuWNX4=";
    };
    modesetting.enable = true;     # Required for Wayland compositors
    powerManagement.enable = true; # Proper suspend/resume
    nvidiaSettings = true;         # nvidia-settings GUI tool
  };

  # Preserve video memory across suspend/resume.
  # hdmi_deepcolor=0 + disable_hdmi_frl=1: HDMI TVs on Ampere often request
  # deep color / HDMI 2.1 FRL the driver can't sync, giving "no signal"
  # (TV never detected). Falls back to HDMI 2.0 / 8-bit — DP unaffected.
  # If a future TV trip works with these, remove selectively to re-test.
  # EnableGpuFirmware=0: GSP firmware breaks the DRM audio component path
  # (no bind with snd_hda_intel -> ELD monitor_present=0 -> kernel rejects
  # HDMI playback). Closed driver only — re-test HDMI audio before
  # re-enabling GSP or switching back to the open module.
  # RMConnectToAudio=1: RM dword that forces the display-to-audio hookup —
  # without it the ELD is never written to the HDA codec (pin sense stays
  # empty) and HDMI audio is dead even though the EDID is valid.
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
