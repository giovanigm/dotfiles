{ config, pkgs, lib, ... }:

{
  # ── DRM connector logging (HDMI TV debugging) ────────────
  # The NVIDIA driver stays silent in the kernel log, and the greeter's
  # Hyprland log lives in /tmp (wiped on this tmpfs-root system), so a
  # blind boot (only the TV connected) left no trace of whether the TV
  # was ever detected. This logs connector state to /var/log (persisted)
  # at boot and on every hotplug event, making blind boots
  # self-diagnosing: boot at the TV, come back, read the log.
  systemd.services.drm-status-log = {
    description = "Log DRM connector statuses to /var/log/drm-connectors.log";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-modules-load.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      log=/var/log/drm-connectors.log
      {
        echo "[$(date '+%F %T')] boot"
        for status in /sys/class/drm/card*-*/status; do
          dir=''${status%/status}
          conn=''${dir##*/}
          bytes=0
          [ -f "$dir/edid" ] && bytes=$(wc -c < "$dir/edid")
          echo "  $conn: $(cat "$status") (edid $bytes bytes)"
        done
      } >> "$log"
      chmod 644 "$log"
    '';
  };

  # Hotplug events: DRM connectors emit a "change" uevent when a display
  # is plugged/unplugged. Log the connector name + new status to the
  # journal (tag drm-hotplug), which the user can read without root.
  # Note: no shell in RUN — udev parses $( ) as an invalid substitution;
  # $sysfs{status} reads the attribute natively.
  services.udev.extraRules = ''
    ACTION=="change", SUBSYSTEM=="drm", KERNEL=="card*-*", RUN+="${pkgs.util-linux}/bin/logger -t drm-hotplug 'connector %k status=$sysfs{status}'"
  '';
}
