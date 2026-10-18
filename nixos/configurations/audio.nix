{ config, pkgs, lib, ... }:

{
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
    wireplumber.enable = true;
  };

  # ── NVIDIA HDMI audio profile ─────────────────────────────
  # WirePlumber 0.5.14 (DMS) sets api.acp.auto-profile=false on every card
  # and never selects a profile for the NVIDIA HDMI card, so its sink
  # doesn't exist unless someone forces output:hdmi-stereo. wpctl (1.6.6)
  # can't talk to WP 0.5.14 for this, but pactl can. Retry loop: the card
  # appears a moment after wireplumber starts. Without this, TV HDMI audio
  # is dead after every reboot (kernel ELD is fine; the sink just never
  # gets created).
  systemd.user.services.nvidia-hdmi-profile = {
    description = "Force HDMI stereo profile on the NVIDIA audio card";
    wantedBy = [ "default.target" ];
    after = [ "wireplumber.service" "pipewire-pulse.service" ];
    wants = [ "wireplumber.service" "pipewire-pulse.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = toString (pkgs.writeShellScript "nvidia-hdmi-profile" ''
        for i in $(seq 1 40); do
          ${pkgs.pulseaudio}/bin/pactl set-card-profile \
            alsa_card.pci-0000_01_00.1 output:hdmi-stereo && exit 0
          sleep 0.5
        done
        exit 1
      '');
    };
  };
}
