{ config, pkgs, ... }: {
  imports = [ ./home/sdks.nix ];

  home.username = "giovani";
  home.homeDirectory = "/home/giovani";
  home.stateVersion = "26.05";

  programs.mpvpaper = {
    enable = true;
    package = pkgs.mpvpaper.overrideAttrs (old: {
      version = "1.9";
      src = pkgs.fetchFromGitHub {
        owner = "GhostNaN";
        repo = "mpvpaper";
        rev = "1.9";
        hash = "sha256-FpwMhzYmbjwvbpJd6xDRka6h2bvgsqdopqP5deQKXSA=";
      };
    });
    pauseList = ''
      firefox
      steam
    '';
  };
}
