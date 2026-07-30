{ config, pkgs, lib, ... }:

{
  # ── Git ─────────────────────────────────────────────────
  programs.git = {
    enable = true;
    config = {
      user.name = "Giovani Granero";
      user.email = "ggmelone@gmail.com";
      init.defaultBranch = "main";
      push.autoSetupRemote = true;
    };
  };

  # ── Direnv (per-project shells for Node.js, etc.) ────────
  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };

  # ── Shell ────────────────────────────────────────────────
  programs.firefox.enable = true;
  programs.zsh = {
    enable = true;
    autosuggestions.enable = true;
    syntaxHighlighting.enable = true;
    ohMyZsh = {
      enable = true;
      theme = "robbyrussell";
      plugins = [ "git" ];
    };
  };
}
