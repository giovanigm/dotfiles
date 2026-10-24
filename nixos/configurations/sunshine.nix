{ config, pkgs, lib, ... }:

let
  # Creates HEADLESS-1 in Hyprland and maintains Sunshine's structural config.
  # Also used as Sunshine's global prep command (connect/disconnect).
  virtualDisplay = pkgs.writeShellApplication {
    name = "sunshine-virtual-display";
    runtimeInputs = [
      config.programs.hyprland.package
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.gnused
      pkgs.jq
    ];
    text = builtins.readFile ../scripts/sunshine-virtual-display.sh;
  };
in
{
  services.sunshine = {
    enable = true;

    # The nixpkgs build defaults to SUNSHINE_ENABLE_CUDA=OFF, which makes the
    # NVENC path convert frames through software swscale; the bundled ffmpeg
    # rejects that with EINVAL ("Couldn't scale frame: Invalid argument"), so
    # Sunshine falls back to libx264. The CUDA build uses the GPU conversion
    # path (and also pulls in autoAddDriverRunpath).
    package = pkgs.sunshine.override {
      cudaSupport = true;
      cudaPackages = pkgs.cudaPackages;
    };

    autoStart = true;
    openFirewall = true;

    # wlr-screencopy through the Hyprland compositor: no CAP_SYS_ADMIN needed,
    # and it captures compositor-side headless outputs. KMS cannot see them.
    capSysAdmin = false;

    # Intentionally no `settings`/`applications`: the web UI stays editable.
    # The setup service below writes only capture/output_name/encoder/
    # global_prep_cmd into ~/.config/sunshine/sunshine.conf before startup.
  };

  # Must run before Sunshine: wlr capture resolves output_name at startup.
  systemd.user.services.sunshine-headless = {
    description = "Hyprland headless output and Sunshine config for virtual display";
    wantedBy = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    before = [ "sunshine.service" ];
    partOf = [ "graphical-session.target" ];
    unitConfig.ConditionEnvironment = "WAYLAND_DISPLAY";
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${virtualDisplay}/bin/sunshine-virtual-display setup";
    };
  };

  systemd.user.services.sunshine.after = [ "sunshine-headless.service" ];
  systemd.user.services.sunshine.wants = [ "sunshine-headless.service" ];

  # No capSysAdmin wrapper here, so this survives to the process and lets
  # ffmpeg's NVENC dlopen the proprietary driver libraries.
  systemd.user.services.sunshine.environment.LD_LIBRARY_PATH = "/run/opengl-driver/lib";

  # hardware.uinput.enable (set by services.sunshine) does not load uhid, which
  # Sunshine uses for virtual gamepads.
  boot.kernelModules = [ "uhid" ];
}
