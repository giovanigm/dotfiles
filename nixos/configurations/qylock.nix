{ config, pkgs, ... }:

{
  programs.qylock = {
    enable = true;
    theme = "enfield";
    sddm.enable = true;         # Install & activate SDDM theme
    quickshell.enable = true;   # Add qylock-lock to PATH
  };

  # H.264 video decode for SDDM theme backgrounds (bg.mp4)
  # The qylock module only adds qt6.qtmultimedia — GStreamer codec
  # plugins and gst-libav are needed at the greeter level to actually
  # decode video. qtmultimedia in nixpkgs ships both ffmpeg + gstreamer
  # backends; we force ffmpeg which is more reliable.
  services.displayManager.sddm.extraPackages = with pkgs; [
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    gst_all_1.gst-plugins-bad
    gst_all_1.gst-plugins-ugly
    gst_all_1.gst-libav
  ];

  systemd.services.display-manager.environment.QT_MEDIA_BACKEND = "ffmpeg";

  # ── Quickshell lock screen: inject qtmultimedia plugin path ──────
  # quickshell's wrapper sets QT_PLUGIN_PATH for qtbase/qtdeclarative/
  # qtsvg/qtwayland but NOT qtmultimedia, so libffmpegmediaplugin.so
  # is never found and video backgrounds (bg.mp4) don't play.
  # This wrapper prepends the qtmultimedia plugin dir so the lock
  # screen can find the ffmpeg media backend.
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "qylock-lock-wrapped" ''
      export QT_PLUGIN_PATH="${pkgs.qt6.qtmultimedia}/lib/qt-6/plugins''${QT_PLUGIN_PATH:+:$QT_PLUGIN_PATH}"
      export QT_MEDIA_BACKEND="ffmpeg"

      # mpvpaper's layer surface is destroyed on screen lock/unlock,
      # leaving the video wallpaper frozen or dead. Suspend before
      # locking and reapply the last wallpaper afterwards so it's fresh.
      SW="$HOME/.local/bin/set-wallpaper"
      [ -x "$SW" ] && "$SW" --suspend || true

      qylock-lock "$@"
      status=$?

      [ -x "$SW" ] && "$SW" --last || true
      exit $status
    '')
  ];
}
