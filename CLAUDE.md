# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a **dotfiles repository** — not an application. It manages user configuration for a NixOS workstation with Hyprland, Neovim, Quickshell, Ghostty, and other tools. Deployment works through two independent mechanisms:
- **`make deploy`** — symlinks `.zshrc` to `~/.zshrc`, `.claude/statusline.sh` to `~/.claude/statusline.sh`, every file under `.local/bin/` into `~/.local/bin/`, and every directory under `.config/` into `~/.config/`, backing up existing files
- **`nixos-rebuild-switch`** — shell function (in `.zshrc`) that runs `sudo nixos-rebuild switch --flake /etc/nixos#nixos`

The NixOS system directory (`nixos/`) is also symlinked from `/etc/nixos` via a systemd tmpfiles rule (set in `configurations/system.nix`).

## Commands

| Command | What it does | Where |
|---------|-------------|-------|
| `make deploy` | Symlink `.zshrc`, `.claude/statusline.sh`, `.local/bin/*`, and all `.config/*` dirs (backups existing) | Makefile |
| `make setup-nixos` | One-time setup: symlink `/etc/nixos` → repo | Makefile |
| `nixos-rebuild-switch` | Rebuild and switch NixOS system | `.zshrc` |
| `nixos-rebuild-boot` | Rebuild NixOS and update boot entries (no live switch) | `.zshrc` |
| `nixos-check` | Syntax-check all `.nix` files in `nixos/` | `.zshrc` |
| `nixos-upgrade` | Update flake.lock + rebuild + switch | `.zshrc` |
| `nixos-clean-broken-generations` | Switch to booted gen, delete newer, gc | `.zshrc` |
| `nixos-build-log` | View last NixOS build log | `.zshrc` |

There are no tests, no linting, no build step — this is purely configuration files.

## Architecture

### NixOS system (`nixos/`)

**Flake-based** with impermanence. The key files and their roles:

| File | Role |
|------|------|
| `flake.nix` | Entry point. Declares inputs (nixpkgs, nixpkgs-master, impermanence, home-manager) and lists top-level modules |
| `configuration.nix` | Thin orchestrator. Imports all modules from `configurations/` and bridges home-manager |
| `configurations/nix.nix` | Nix daemon settings (experimental-features) |
| `configurations/boot.nix` | GRUB + Windows 11 dual-boot (manual chainload entry on separate ESP) |
| `configurations/networking.nix` | Hostname + NetworkManager |
| `configurations/locale.nix` | Timezone, locale/i18n, keyboard layout, Fcitx5 input method |
| `configurations/desktop.nix` | SDDM + Hyprland (UWSM), xdg-portal, env vars, GPU wait |
| `configurations/nvidia.nix` | NVIDIA RTX 3080: proprietary driver, open kernel module, modesetting, power mgmt |
| `configurations/audio.nix` | PipeWire (ALSA, PulseAudio, JACK, WirePlumber) |
| `configurations/docker.nix` | Docker daemon with weekly auto-prune |
| `configurations/filesystems.nix` | NTFS driver (ntfs3 + ntfs-3g), udisks2, gvfs, polkit rules |
| `configurations/fonts.nix` | Font packages (JetBrains Mono Nerd Font) |
| `configurations/packages/apps.nix` | Global GUI apps, media/gaming, desktop environment, Zen Browser |
| `configurations/packages/dev.nix` | Global editor + dev/DB tools, Android CLI |
| `configurations/packages/sdks.nix` | Global runtimes + package managers (Python, Node, Go, Flutter, pnpm) |
| `configurations/packages/cli.nix` | Global core CLI utilities + system monitoring |
| `configurations/printing.nix` | CUPS printing |
| `configurations/users.nix` | User account (giovani), groups, shell, password |
| `configurations/programs.nix` | Git, Direnv, Firefox, Zsh (Oh My Zsh, autosuggestions, syntax highlighting) |
| `configurations/system.nix` | Nixpkgs config, hyprpolkitagent + quickshell user services, impermanence tmpfiles |
| `hardware-configuration.nix` | Filesystem layout: tmpfs root (`/`), `/persist` (ext4), bind mounts for `/nix` and `/home`, ESP for `/boot` |
| `persistence.nix` | Impermanence module: which directories/files persist across tmpfs wipes |
| `home.nix` | Home Manager user config for `giovani`. Imports `home/sdks.nix` (Go + uv module configs). All packages are now system-wide in `configurations/packages/*` |

**Flake inputs**: `nixpkgs` (nixos-26.05), `nixpkgs-master` (unfree), `impermanence`, `home-manager` (follows nixpkgs).

**Key system details**: Dual-boot with Windows 11 (separate ESP, manual GRUB chainload entry, older generations in a submenu), NVIDIA RTX 3080 with proprietary driver + open kernel module + modesetting, SDDM + Hyprland (UWSM launcher).

### Dotfiles (`make deploy`)

The `Makefile` symlinks `.zshrc` to `~/.zshrc`, `.claude/statusline.sh` to `~/.claude/statusline.sh`, iterates over `.local/bin/*` to create per-file symlinks in `~/.local/bin/`, and iterates over `.config/*` to create symlinks in `~/.config/` (with a special case: `DankMaterialShell` would only ever deploy its `plugins/*` individually, since the DMS config dir is DMS-owned). Each subdirectory is a standalone app config:

- **`.local/bin/set-wallpaper`** — Unified wallpaper manager. Sets images via awww, videos via mpvpaper, or picks random images from a directory. `--next` cycles wallpapers, `--last` reapplies the last wallpaper (used on Hyprland login and lock/unlock), `--suspend`/`--resume` handle the screen-lock lifecycle (fixes mpvpaper freezing after lock/unlock).
- **`.local/bin/disk-report`** — Disk usage analysis. No args: system overview (df on key mounts, largest dirs under `/persist` and `/mnt/emuladores`, `/nix/store` size + `nix-collect-garbage --dry-run`, biggest files). With `[-d N] [-n N] <dir>`: total + largest entries of a directory. One `/persist` walk counts everything once since `/home` and `/nix` are binds of dirs inside it; probes `/mnt/emuladores` without triggering its automount.
- **`.config/nvim/`** — Neovim with lazy.nvim. `init.lua` bootstraps lazy.nvim then loads `vim-options`, plugin specs, `autocmds`, and `mappings`. Plugins are split under `lua/plugins/` (one file per plugin/concern). Has a VSCode compatibility layer at the top of `init.lua` for Clojure/Calva workflows.
- **`.config/hypr/`** — Hyprland compositor. `hyprland.lua` is the main config (Lua API). Requires `catppuccin-mocha.lua` for the color palette. Scripts in `scripts/`: `focus-or-launch.sh` (launch or focus+maximize an app), `toggle-rofi.sh`, `toggle-desktop.sh`, `monitor-brightness.sh`, `focused-volume.sh` (SUPER+volume keys adjust the focused window's PipeWire playback streams in 5% steps, capped at the master volume; shows DMS toast OSD feedback; falls back to DMS global volume when the app has no streams), `reload-quickshell.sh` (SUPER+A, restarts the bar service).
- **`.config/quickshell/`** — Status bar (Quickshell QML). `shell.qml` is the entry point (one `Bar` per monitor via `Variants`); `bar.qml` holds the layout; `theme.qml` is a `pragma Singleton` palette; `sysinfo.qml` polls `scripts/sysinfo.sh` (JSON: CPU, temp, RAM, disk, network bitrates) every 2s; `hyprstate.qml` tracks the Hyprland submap; widgets live in `Widget*.qml` files (workspaces, CPU, temp, RAM, disk, network, audio in/out, PipeWire visualizer, clock). Started by the `quickshell.service` UWSM user service (`nixos/configurations/system.nix`); hot-reloads on save.
- **`.config/ghostty/`** — Terminal emulator. `config.ghostty` is the main config; `themes/` has Catppuccin variants.
- **`.config/wezterm/`** — Legacy terminal config (maximized, Github Dark theme, font-size 16).
- **`.config/mako/`** — Notification daemon. 5-second auto-dismiss, peach border on high urgency.
- **`.config/yay/`** — AUR helper security hooks. Scans PKGBUILDs for dangerous patterns (curl | bash, rm -rf /, chmod 777), flags SKIP checksums, warns about unfamiliar source domains, and logs all installs.
- **`.claude/statusline.sh`** — Claude Code statusline. Renders folder, git branch, model name, token usage, and credits in the terminal status bar. Catppuccin Mocha themed.

### Key conventions

- The repo has no `.gitignore` — all files are tracked
- When modifying NixOS config, the CLAUDE.md at `/etc/nixos/` (user's home) says to write to `/tmp/configuration.nix` and let the user copy it — **but** this repo's files under `nixos/` can be edited directly since they're the source of truth
- Neovim plugins reference: leader is `<Space>`, localleader is `,`, tabs are 2 spaces, clipboard is `unnamedplus`
- Everything is themed with Catppuccin Mocha/Mauve
