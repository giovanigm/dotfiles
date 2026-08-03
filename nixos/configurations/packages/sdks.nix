# nixos/configurations/packages/sdks.nix — Global runtimes + package managers
#
# Previously `home.packages` in home/sdks.nix; moved here as part of making all
# packages system-wide via `environment.systemPackages`.
#
# Declarative alternative to asdf/sdkman: runtimes come from nixpkgs and are
# pinned by the flake lock. Per-project versions can be layered on later with
# direnv + nix-direnv (already enabled in configurations/programs.nix).

{ config, pkgs, lib, ... }:

{
  # ── Global runtimes + package managers ────────────────────
  environment.systemPackages = with pkgs; [
    # Python 3.13 (default) → provides `python3` / `python3.13`.
    # nixpkgs ships a PEP 668 EXTERNALLY-MANAGED marker, so `pip install`
    # outside a venv fails by design. Use uv (in home/sdks.nix) for pip-style installs.
    python3

    # Node.js 22 with bundled `npm` → provides `node` / `npm`.
    nodejs_22

    # fvm — Flutter Version Management (like asdf for Flutter).
    fvm

    # Required by Flutter to extract the Dart SDK.
    unzip

    # pnpm 10 (top-level; runs on the default node 24 since nixpkgs 25.x).
    pnpm

    # Needed by mason.nvim to build Go packages with cgo (gopls, gofumpt, etc.)
    gcc
  ];
}
