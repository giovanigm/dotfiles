{ config, pkgs, lib, ... }:

let
  # ── it87 driver: rev with MMIO bridge for IT8689E ─────────
  # nixpkgs pins frankcrawford/it87 at a9eb249 (2025-12-26), whose [it8689]
  # entry lacks FEAT_BRIDGE_MMIO and whose `mmio` param defaults to false.
  # Without the MMIO bridge the chip is not detected at all on this board.
  # Rev 490f76f (2026-07-24) adds FEAT_BRIDGE_MMIO and flips the default to
  # mmio=true; upstream's README calls the MMIO bridge "necessary for fan
  # control with newer Gigabyte motherboards".
  #
  # `name` is recomputed explicitly: upstream builds it inside a `rec` block as
  # "${pname}-${version}-${kernel.version}", so overriding `version` alone would
  # leave the derivation still labelled 2025-12-26 and hide that the pin moved.
  it87 = config.boot.kernelPackages.it87.overrideAttrs (old: rec {
    version = "unstable-2026-07-24";
    name = "${old.pname}-${version}-${config.boot.kernelPackages.kernel.version}";
    src = pkgs.fetchFromGitHub {
      owner = "frankcrawford";
      repo = "it87";
      rev = "490f76f61900c163fac5328506c49969bd716dc6";
      hash = "sha256-f+Tbyapfz0zuD0CGmb3TucqVeSF6OJL9V5MBMlkHsbw=";
    };
  });

  # ── Quiet mode ────────────────────────────────────────────
  # This board does NOT honour the PWM duty register: writes to pwmN,
  # pwmN_auto_start, pwmN_auto_slope and pwmN_auto_point*_temp are all accepted
  # and read back correctly, but none of them reach the fan output. Gigabyte
  # routes actual fan control through a separate controller, so it87 gets full
  # read access and inert writes. A fan-curve daemon (fan2go, fancontrol) has
  # nothing to drive here.
  #
  # The one register that *does* take effect is pwmN_enable. Switching from 2
  # (firmware curve) to 1 drops idle RPM substantially while leaving the
  # hardware's temperature ramp intact. Measured on this machine:
  #
  #   channel     1      2      3      4      5      6
  #   idle auto  1333   1901   1318   1934   1923   1516
  #   idle man.  1285   1326   1005   1347   1280   1486
  #                    -30%   -24%   -30%   -33%
  #
  # Fans still ramp under load (ch1/5/6 reach ~1900 RPM at 90 C, same as auto),
  # and sustained all-core load plateaus 1 C higher than stock: 92 C vs 91 C on
  # a CPU rated to 95 C.
  fanQuiet = pkgs.writeShellApplication {
    name = "fan-quiet";
    text = ''
      # hwmonN numbering is not stable across boots — match on the chip name.
      for d in /sys/class/hwmon/hwmon*; do
        [ "$(cat "$d/name" 2>/dev/null)" = "it8689" ] || continue
        for i in 1 2 3 4 5 6; do
          [ -e "$d/pwm''${i}_enable" ] || continue
          echo 1 > "$d/pwm''${i}_enable"
        done
        echo "fan-quiet: pinned $(basename "$d") pwm1-6 to manual mode"
        exit 0
      done
      echo "fan-quiet: no it8689 hwmon device found (is the it87 module loaded?)" >&2
      exit 1
    '';
  };
in
{
  # ── Fan control: IT8689E Super I/O ────────────────────────
  # The in-tree it87 driver only covers IT8705F/IT871xF/IT872xF, so it never
  # binds to this board's IT8689E and no pwm* channels are created at all.
  boot.extraModulePackages = [ it87 ];
  boot.kernelModules = [ "it87" ];

  # Module parameters must live here — boot.kernelModules takes bare names only.
  #   mmio=1                     already the default at this rev; explicit so a
  #                              future rev bump can't silently disable it.
  #   ignore_resource_conflict=1 ACPI claims the Super-I/O ports on Gigabyte
  #                              boards, which otherwise fails the probe.
  boot.extraModprobeConfig = ''
    options it87 mmio=1 ignore_resource_conflict=1
  '';

  systemd.services.fan-quiet = {
    description = "Pin IT8689E fan channels to manual mode for quieter idle";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-modules-load.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = lib.getExe fanQuiet;
    };
  };

  # The chip is reprogrammed by firmware across a suspend cycle, so re-assert.
  powerManagement.resumeCommands = ''
    ${config.systemd.package}/bin/systemctl restart fan-quiet.service
  '';

  # ── Sensor tooling ────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    lm_sensors               # `sensors` — read temps, fan RPM, PWM state
  ];
}
