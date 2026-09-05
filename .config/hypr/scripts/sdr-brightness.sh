#!/usr/bin/env bash
# sdr-brightness.sh — adjust Hyprland's SDR brightness (SDR→HDR tone-mapping
# in HDR mode). Bound to SUPER + brightness keys in hyprland.lua; the plain
# brightness keys keep controlling the monitor's hardware backlight via
# DDC/CI. `restore` re-applies the saved level at Hyprland start.
#
# Usage: sdr-brightness.sh up|down|restore
#
# Level persists in ~/.cache/hypr/sdr-brightness and is seeded from the
# running compositor (the hyprland.lua default) on first use, so it survives
# restarts without fighting config edits.

set -euo pipefail

mode="${1:-}"
case "$mode" in
  up | down | restore) ;;
  *)
    echo "Usage: $0 up|down|restore" >&2
    exit 1
    ;;
esac

# Serialize rapid key-repeat invocations (the bindings use repeating = true)
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/sdr-brightness.lock"
flock -n 9 || exit 0

STATE="${XDG_CACHE_HOME:-$HOME/.cache}/hypr/sdr-brightness"
MONITOR="desc:ASUSTek COMPUTER INC VG27AQL1A M1LMQS012381"
STEP=0.1
MIN=0.5
MAX=2.5
DEFAULT=1.2

current="$(cat "$STATE" 2>/dev/null || true)"
if [[ -z "$current" ]]; then
  # Seed from the running compositor (hyprland.lua default on first use)
  current="$(hyprctl monitors all -j 2>/dev/null | jq -r '.[0].sdrBrightness // empty' 2>/dev/null || true)"
  current="${current:-$DEFAULT}"
fi

case "$mode" in
  up)   new="$(awk -v v="$current" -v s="$STEP" -v m="$MAX" 'BEGIN { printf "%.1f", (v + s > m ? m : v + s) }')" ;;
  down) new="$(awk -v v="$current" -v s="$STEP" -v m="$MIN" 'BEGIN { printf "%.1f", (v - s < m ? m : v - s) }')" ;;
  restore) new="$current" ;;
esac

# Partial rule: eval merges only the fields given, leaving mode/bitdepth/cm
# untouched (verified against Hyprland 0.55.4's Lua config parser).
hyprctl eval "hl.monitor({ output = '$MONITOR', sdrbrightness = $new })" >/dev/null

mkdir -p "$(dirname "$STATE")"
printf '%s\n' "$new" > "$STATE"

[[ "$mode" == "restore" ]] && exit 0

# OSD-style feedback via DMS toasts: hide + show updates in place on key
# repeat, like the master volume OSD
pct="$(awk -v v="$new" 'BEGIN { printf "%.0f", v * 100 }')"
dms ipc call toast hide >/dev/null 2>&1 || true
dms ipc call toast info "SDR brightness ${pct}%" >/dev/null 2>&1 || true
