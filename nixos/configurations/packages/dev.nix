# nixos/configurations/packages/dev.nix — Editor + dev tools

{ config, pkgs, lib, ... }:

{
  # ── Development Tools ─────────────────────────────────────
  environment.systemPackages = with pkgs; [
    # Editor
    neovim

    # Dev / DB
    dbeaver-bin
    postman
    android-studio
    android-tools
    gnumake
    ripgrep
    heroku
    jdk21

    # Android CLI (agent-first CLI for Android development)
    (stdenvNoCC.mkDerivation {
      pname = "android-cli";
      version = "1.0";
      src = fetchurl {
        url = "https://dl.google.com/android/cli/latest/linux_x86_64/android";
        sha256 = "7d0f4b41e6511ab6eeeaec4b885442f02aded270cf83cb75f521aca2c03d593d";
      };
      dontUnpack = true;
      installPhase = ''
        mkdir -p $out/bin
        cp $src $out/bin/android
        chmod +x $out/bin/android
      '';
    })
  ];
}
