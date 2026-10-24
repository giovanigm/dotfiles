# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a **dotfiles repository** — not an application. It manages user configuration for a NixOS workstation with Hyprland, Neovim, Quickshell, Ghostty, and other tools. Deployment works through two independent mechanisms:
- **`make deploy`** — symlinks `.zshrc` to `~/.zshrc`, `.XCompose` to `~/.XCompose`, `.claude/statusline.sh` to `~/.claude/statusline.sh`, every file under `.local/bin/` into `~/.local/bin/`, and every directory under `.config/` into `~/.config/`, backing up existing files
- **`nixos-rebuild-switch`** — shell function (in `.zshrc`) that runs `sudo nixos-rebuild switch --flake /etc/nixos#nixos`

The NixOS system directory (`nixos/`) is also symlinked from `/etc/nixos` via a systemd tmpfiles rule (set in `configurations/system.nix`).

## Commands

| Command | What it does | Where |
|---------|-------------|-------|
| `make deploy` | Symlink `.zshrc`, `.XCompose`, `.claude/statusline.sh`, `.local/bin/*`, and all `.config/*` dirs (backups existing) | Makefile |
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
| `configurations/drm-debug.nix` | Logs DRM connector statuses to `/var/log/drm-connectors.log` at boot + hotplug events to journal (tag `drm-hotplug`) — makes blind boots self-diagnosing |
| `configurations/nvidia.nix` | NVIDIA RTX 3080: proprietary driver, closed kernel module, modesetting, power mgmt. kernelParams carry the HDMI TV fixes: `RMConnectToAudio=1` (audio ELD), `hdmi_deepcolor=0` + `disable_hdmi_frl=1` (video sync) — see Known quirks |
| `configurations/audio.nix` | PipeWire (ALSA, PulseAudio, JACK, WirePlumber) + `nvidia-hdmi-profile` user service (forces `output:hdmi-stereo` on the NVIDIA card each boot; WP 0.5.14 never selects it) |
| `configurations/sunshine.nix` | Sunshine (Moonlight/Artemis game stream host) capturing a Hyprland headless output as a virtual display; `sunshine-headless` user service creates `SUNSHINE-1` before Sunshine starts; helper in `scripts/sunshine-virtual-display.sh` — see Known quirks |
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

**Key system details**: Dual-boot with Windows 11 (separate ESP, manual GRUB chainload entry, older generations in a submenu), NVIDIA RTX 3080 with proprietary driver + closed kernel module + modesetting, SDDM + Hyprland (UWSM launcher).

### Dotfiles (`make deploy`)

The `Makefile` symlinks `.zshrc` to `~/.zshrc`, `.XCompose` to `~/.XCompose`, `.claude/statusline.sh` to `~/.claude/statusline.sh`, iterates over `.local/bin/*` to create per-file symlinks in `~/.local/bin/`, and iterates over `.config/*` to create symlinks in `~/.config/` (with a special case: `DankMaterialShell` would only ever deploy its `plugins/*` individually, since the DMS config dir is DMS-owned). Each subdirectory is a standalone app config:

- **`.local/bin/set-wallpaper`** — Unified wallpaper manager. Sets images via awww, videos via mpvpaper, or picks random images from a directory. `--next` cycles wallpapers, `--last` reapplies the last wallpaper (used on Hyprland login and lock/unlock), `--suspend`/`--resume` handle the screen-lock lifecycle (fixes mpvpaper freezing after lock/unlock).
- **`.local/bin/disk-report`** — Disk usage analysis. No args: system overview (df on key mounts, largest dirs under `/persist` and `/mnt/emuladores`, `/nix/store` size + `nix-collect-garbage --dry-run`, biggest files). With `[-d N] [-n N] <dir>`: total + largest entries of a directory. One `/persist` walk counts everything once since `/home` and `/nix` are binds of dirs inside it; probes `/mnt/emuladores` without triggering its automount.
- **`.config/nvim/`** — Neovim with lazy.nvim. `init.lua` bootstraps lazy.nvim then loads `vim-options`, plugin specs, `autocmds`, and `mappings`. Plugins are split under `lua/plugins/` (one file per plugin/concern). Has a VSCode compatibility layer at the top of `init.lua` for Clojure/Calva workflows.
- **`.config/hypr/`** — Hyprland compositor. `hyprland.lua` is the main config (Lua API). Requires `catppuccin-mocha.lua` for the color palette. Scripts in `scripts/`: `focus-or-launch.sh` (launch or focus+maximize an app), `toggle-desktop.sh`, `monitor-brightness.sh`, `focused-volume.sh` (SUPER+volume keys adjust the focused window's PipeWire playback streams in 5% steps, capped at the master volume; shows DMS toast OSD feedback; falls back to DMS global volume when the app has no streams), `force-quit.sh` (SUPER+SHIFT+W — SIGKILL the focused window's process; with a class argument kills all windows of that class; falls back to a close request when the window has no killable PID; DMS toast feedback), `reload-dms.sh` (SUPER+A, restarts the bar service).
- **`.config/quickshell/`** — Status bar (Quickshell QML). `shell.qml` is the entry point (one `Bar` per monitor via `Variants`); `bar.qml` holds the layout; `theme.qml` is a `pragma Singleton` palette; `sysinfo.qml` polls `scripts/sysinfo.sh` (JSON: CPU, temp, RAM, disk, network bitrates) every 2s; `hyprstate.qml` tracks the Hyprland submap; widgets live in `Widget*.qml` files (workspaces, CPU, temp, RAM, disk, network, audio in/out, PipeWire visualizer, clock). Started by the `quickshell.service` UWSM user service (`nixos/configurations/system.nix`); hot-reloads on save.
- **`.config/ghostty/`** — Terminal emulator. `config.ghostty` is the main config; `themes/` has Catppuccin variants.
- **`.config/wezterm/`** — Legacy terminal config (maximized, Github Dark theme, font-size 16).
- **`.config/mako/`** — Notification daemon. 5-second auto-dismiss, peach border on high urgency.
- **`.config/yay/`** — AUR helper security hooks. Scans PKGBUILDs for dangerous patterns (curl | bash, rm -rf /, chmod 777), flags SKIP checksums, warns about unfamiliar source domains, and logs all installs.
- **`.claude/statusline.sh`** — Claude Code statusline. Renders folder, git branch, model name, token usage, and credits in the terminal status bar. Catppuccin Mocha themed.
- **`.XCompose`** — Compose table override so `'+c` produces `ç` on the us alt-intl layout (see Known quirks below). Loaded by fcitx5 via libxkbcommon.

### Key conventions

- The repo has no `.gitignore` — all files are tracked
- When modifying NixOS config, the CLAUDE.md at `/etc/nixos/` (user's home) says to write to `/tmp/configuration.nix` and let the user copy it — **but** this repo's files under `nixos/` can be edited directly since they're the source of truth
- Neovim plugins reference: leader is `<Space>`, localleader is `,`, tabs are 2 spaces, clipboard is `unnamedplus`
- Everything is themed with Catppuccin Mocha/Mauve

## Known quirks (survives reformats — do not regress)

### Eden emulator wrapper (`nixos/configurations/packages/emulators.nix`)

The `eden` package is wrapped with `symlinkJoin` + `wrapProgram` for three reasons — **do not simplify the wrapper away**:

1. Eden's Wayland UI is broken upstream (Qt file dialogs crash); `QT_QPA_PLATFORM=xcb` + `SDL_VIDEODRIVER=x11` force XWayland.
2. The file dialog is a GTK3 dialog (session-wide `QT_QPA_PLATFORMTHEME=gtk3`), and apps launched from **DMS spotlight** inherit an `XDG_DATA_DIRS` with **no GSettings schemas** — GTK3 aborts with `No GSettings schemas are installed on the system` (SIGABRT when opening Load File/Folder). The wrapper prepends the gtk3 + gsettings-desktop-schemas schema dirs (both 26.05 and nixpkgs-master builds, since the dialog loads gtk3 from the session's qt6gtk3 plugin *and* Eden's own deps) to `XDG_DATA_DIRS`.
3. Terminal launches were unaffected because shell env has the schemas; only DMS-spotlight launches crashed. The crash looks like a Wayland problem but isn't.

The underlying gap is DMS spotlight's env: other GTK-dialog apps launched from spotlight can hit the same abort. The systemic fix (not yet applied) is enriching the DMS service env with the schema dirs.

### Cedilla compose override (`.XCompose`)

`'+c` must produce `ç` on the us alt-intl layout, but the en_US compose table maps `<dead_acute> <c>` to `ć` (compose-table behavior — an XKB symbols variant cannot fix this). All text input routes through fcitx5, whose dead-key handling is libxkbcommon's `xkb_compose_table_new_from_locale`, so `.XCompose` (deployed by `make deploy`) is the single override point. Two non-obvious facts: fcitx5 loads the compose table **only at startup** (restart it or re-login after edits), and `~/.XCompose` **replaces** the system table — the `include "%L"` line is mandatory or every other dead-key sequence (é, à, ñ, ...) breaks.

### HDMI TV support (`nvidia.nix` kernelParams + `audio.nix` service)

A Samsung TV on the RTX 3080's HDMI needs three kernel params to work at all — **do not "clean up" any of them without re-testing at the TV**:

1. `nvidia_modeset.hdmi_deepcolor=0` + `nvidia_modeset.disable_hdmi_frl=1` — without them the TV is **never detected** (connector stays `disconnected`, no video, not even at GRUB). The driver can't sync the TV's deep-color/HDMI 2.1 FRL request; these cap it to HDMI 2.0/8-bit. Untested which one is decisive.
2. `nvidia.NVreg_RegistryDwords=RMConnectToAudio=1` — without it video works but audio is dead: the RM never writes the ELD to the HDA codec (`/proc/asound/card0/eld#*` all `monitor_present 0`), the kernel rejects HDMI playback with EINVAL, and no sink can be created. Verified on drivers 595.71.05 + 615.78.08, kernels 6.12 + 6.18. The TV's EDID is perfectly valid (LPCM/AC-3/E-AC3 + HDMI VSDB) — the gate is purely the regkey.
3. `nvidia.NVreg_EnableGpuFirmware=0` (GSP off) — added during the same debugging, never proven necessary; candidate for re-testing with GSP on. Closed driver only.

Audio also needs the `nvidia-hdmi-profile` user service (`audio.nix`): WirePlumber 0.5.14 (DMS) sets `api.acp.auto-profile=false` and never selects a profile for the NVIDIA card, so the HDMI sink only exists when the service forces `output:hdmi-stereo` via pactl (newer `wpctl set-profile` silently fails against WP 0.5.14). The card name is `alsa_card.pci-0000_01_00.1` (PCI address of the GPU's HDA controller). `drm-debug.nix` logs connector statuses to `/var/log/drm-connectors.log` at every boot, which is how blind TV-boot attempts stay diagnosable.

### Sunshine virtual display (`sunshine.nix` + `scripts/sunshine-virtual-display.sh`)

Sunshine streams a Hyprland headless output (`SUNSHINE-1`) as an Apollo-style virtual display. Apollo's own virtual display is Windows-only, and upstream Sunshine is far more current than the fork, so this is the Linux path. Non-obvious constraints:

1. **Capture must be `wlr`, not `kms`** (`capture = wlr`, `output_name = SUNSHINE-1`). KMS cannot see compositor-side headless outputs. wlr-screencopy goes through Hyprland, so `capSysAdmin = false` — deliberately, because the `security.wrappers` wrapper would strip `LD_LIBRARY_PATH`, which ffmpeg's NVENC `dlopen` needs. The service env keeps `/run/opengl-driver/lib`.
   **And the package must be built with CUDA** (`pkgs.sunshine.override { cudaSupport = true; cudaPackages = pkgs.cudaPackages; }`). The default nixpkgs build is CUDA-less: its NVENC path converts frames through software swscale, which the bundled ffmpeg rejects with `Couldn't scale frame: Invalid argument` (EINVAL), silently falling back to `libx264`. With CUDA the probe reports `h264_nvenc`/`hevc_nvenc` and the stream uses NVENC.
2. **Hyprland 0.55 runs the Lua config manager**: `hyprctl keyword` fails with `keyword can't work with non-legacy parsers. Use eval.` Monitor/workspace changes must use `hyprctl eval` with `hl.monitor({...})` and `hl.dispatch(hl.dsp...)`. `hl.monitor` applies immediately to an active output; focus the headless monitor *before* focusing workspace 11 so the workspace is created on it.
3. **wlr capture caches `output_name` at startup.** The `sunshine-headless` user service is ordered `Before=sunshine.service` and creates the output before Sunshine starts; recreating it later would require a Sunshine restart. A matching `hl.monitor` rule for `SUNSHINE-1` lives in `hyprland.lua` so config reloads do not drop the output; the per-client mode is applied at runtime by the helper. On `connect` the helper **disables every non-headless monitor** (`hl.monitor({ output = "...", disabled = true })`), so the headless output is the only active one and games cannot land on the physical display; on `disconnect` it re-enables them with the saved modes/positions and runs `hyprctl reload` to restore the fields `hyprctl monitors -j` does not expose (HDR/`cm`, `bitdepth`, `sdr_eotf`, `vrr`).
4. The setup service writes only the structural keys (`capture`, `output_name`, `encoder`, `global_prep_cmd`) into `~/.config/sunshine/sunshine.conf`, so the web UI remains editable for everything else. `global_prep_cmd` runs the helper's `connect` (resize to `SUNSHINE_CLIENT_WIDTH/HEIGHT/FPS`, disable physical monitors, show the workspace the user was on) and `disconnect` (restore monitors/workspace). Sunshine runs prep commands with an **empty PATH**, so the command (and every app command) must use absolute paths. A command-less app (the default `Desktop`) is treated as a **placebo**: Sunshine never calls `terminate()` for it, so the global `undo`/`disconnect` never runs and the local workspace stays on the headless output. Give such apps a dummy long-running command (`/run/current-system/sw/bin/sleep infinity`) so the lifecycle hooks fire. The `DekUI` app in `~/.config/sunshine/apps.json` wraps `run-dekui.sh` in `/usr/bin/env PATH=...` for the same reason.
5. `services.sunshine` enables `hardware.uinput.enable`, which wins over Apollo/Sunshine's own `GROUP="input"` udev rule with a `GROUP="uinput"` rule; the user is therefore in the `uinput` group. `uhid` is loaded separately for virtual gamepads.
