# nixos/home/sdks.nix — Global SDK defaults (Python, Node.js, Go, Flutter)
#
# Declarative alternative to asdf/sdkman: runtimes come from nixpkgs and are
# pinned by the flake lock. Per-project versions can be layered on later with
# direnv + nix-direnv (already enabled in configurations/programs.nix).

{ pkgs, ... }:

{
  # Runtime packages (python, node, fvm, etc.) were moved to
  # configurations/packages/sdks.nix as environment.systemPackages.

  # ── Go ────────────────────────────────────────────────────────
  # Installs `go` and manages `~/.config/go/env` declaratively.
  programs.go = {
    enable = true;
    package = pkgs.go_1_26;
  };

  # ── uv — pip/pipx-compatible Python tooling ───────────────────
  # `uv venv` + `uv pip install` work even though nixpkgs python is built
  # with --without-ensurepip (plain `python -m venv` yields pip-less venvs).
  # Settings force uv to reuse the Nix-managed interpreter rather than
  # downloading its own managed pythons.
  programs.uv = {
    enable = true;
    settings = {
      python-preference = "only-system";
      python-downloads = "never";
    };
  };
}
