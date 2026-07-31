# nixos/home/sdks.nix — Global SDK defaults (Python, Node.js, Go, Flutter)
#
# Declarative alternative to asdf/sdkman: runtimes come from nixpkgs and are
# pinned by the flake lock. Per-project versions can be layered on later with
# direnv + nix-direnv (already enabled in configurations/programs.nix).

{ pkgs, ... }:

{
  # ── Global runtimes + package managers ────────────────────────
  home.packages = [
    # Python 3.12 → provides `python3` / `python3.12`.
    # nixpkgs ships a PEP 668 EXTERNALLY-MANAGED marker, so `pip install`
    # outside a venv fails by design. Use uv (below) for pip-style installs.
    pkgs.python312

    # Node.js 22 with bundled `npm` → provides `node` / `npm`.
    pkgs.nodejs_22

    # fvm — Flutter Version Management (like asdf for Flutter).
    # Use `fvm install 3.44` to install Flutter 3.44, then `fvm use 3.44`
    # per project (managed via `.fvmrc` or `fvm use`).
    pkgs.fvm

    # Required by Flutter to extract the Dart SDK.
    pkgs.unzip

    # pnpm 10 (top-level; runs on the default node 24 since nixpkgs 25.x —
    # it is no longer in the `nodejs_22.pkgs` set). For a strict node-22
    # match, replace with: pkgs.pnpm.override { nodejs = pkgs.nodejs_22; }
    pkgs.pnpm

    # Needed by mason.nvim to build Go packages with cgo (gopls, gofumpt, etc.)
    pkgs.gcc
  ];

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
