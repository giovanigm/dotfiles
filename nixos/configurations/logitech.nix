{ pkgs, ... }:

let
  # Software replug for a Logitech G305 whose Lightspeed receiver did not
  # announce the mouse at boot. See scripts/logitech-mouse-rescan.sh.
  logitech-mouse-rescan = pkgs.writeShellApplication {
    name = "logitech-mouse-rescan";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnugrep
    ];
    text = builtins.readFile ../scripts/logitech-mouse-rescan.sh;
  };
in
{
  environment.systemPackages = [ logitech-mouse-rescan ];

  # hid-logitech-dj can miss the receiver's "device connected" notification
  # during probe (timing-dependent; the mouse then stays dead until the
  # receiver is replugged). This oneshot only acts when the input node is
  # missing, so it is a no-op on normal boots. Remove once the kernel fix
  # lands.
  systemd.services.logitech-mouse-recover = {
    description = "Recover Logitech G305 if the receiver missed it at boot";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${logitech-mouse-rescan}/bin/logitech-mouse-rescan";
      TimeoutStartSec = 90;
      SyslogIdentifier = "logitech-mouse-recover";
    };
  };
}
