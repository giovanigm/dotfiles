#!/usr/bin/env bash
# focused-volume.sh — adjust the focused window's PipeWire playback streams.
# Bound to SUPER + volume keys in hyprland.lua; the plain volume keys keep
# controlling global volume via DMS.
#
# Usage: focused-volume.sh up|down|mute
#
# Falls back to the DMS global volume commands when nothing is focused or the
# focused app has no playback stream, so SUPER+volume never silently no-ops.

set -euo pipefail

mode="${1:-}"
case "$mode" in
  up | down | mute) ;;
  *)
    echo "Usage: focused-volume.sh up|down|mute" >&2
    exit 1
    ;;
esac

STEP=0.05
# Per-app streams never surpass the master (default sink) volume; fall back to
# 1.0 if the sink volume can't be read.
CAP_FALLBACK=1.0

# Serialize rapid key-repeat invocations (the bindings use repeating = true)
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/focused-volume.lock"
flock -n 9 || exit 0

# Normalize a name for fuzzy matching: lowercase, alphanumeric only
norm() {
  tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9'
}

# Focused window class (empty when nothing is focused)
focused_class="$(hyprctl activewindow -j 2>/dev/null | jq -r '.class // empty' 2>/dev/null || true)"
class_norm="$(printf '%s' "$focused_class" | norm)"

apply_stream() {
  local id="$1" cur vol muted new cap
  cur="$(wpctl get-volume "$id" 2>/dev/null || true)"
  [[ "$cur" == *"[MUTED]"* ]] && muted=1
  vol="$(printf '%s' "$cur" | grep -oE '[0-9]+\.[0-9]+' | head -1 || true)"
  vol="${vol:-0}"
  case "$mode" in
    up)
      # Raising volume unmutes the stream
      [[ -n "${muted:-}" ]] && wpctl set-mute "$id" 0 >/dev/null 2>&1 || true
      # Cap at the current master (default sink) volume; if the stream is
      # already at or above the cap, leave it untouched
      cap="$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null \
        | grep -oE '[0-9]+\.[0-9]+' | head -1 || true)"
      cap="${cap:-$CAP_FALLBACK}"
      new="$(awk -v v="$vol" -v s="$STEP" -v m="$cap" 'BEGIN { printf "%.2f", (v >= m ? v : (v + s > m ? m : v + s)) }')"
      wpctl set-volume "$id" "$new" >/dev/null 2>&1 || true
      report="${app_name} $(awk -v v="$new" 'BEGIN { printf "%.0f", v * 100 }')%"
      ;;
    down)
      new="$(awk -v v="$vol" -v s="$STEP" 'BEGIN { printf "%.2f", (v - s < 0 ? 0 : v - s) }')"
      wpctl set-volume "$id" "$new" >/dev/null 2>&1 || true
      report="${app_name} $(awk -v v="$new" 'BEGIN { printf "%.0f", v * 100 }')%"
      ;;
    mute)
      # Absolute, not toggle: derived from current state
      if [[ -n "${muted:-}" ]]; then
        wpctl set-mute "$id" 0 >/dev/null 2>&1 || true
        report="${app_name} unmuted"
      else
        wpctl set-mute "$id" 1 >/dev/null 2>&1 || true
        report="${app_name} muted"
      fi
      ;;
  esac
}

matching_ids=""
app_name=""
report=""
if [[ -n "$class_norm" ]]; then
  # Enumerate playback stream node ids from the Streams section of `wpctl status`.
  # Section entries are indented once; their sub-entries (ports) are indented
  # deeper and are skipped. A media.class check below filters anything else out
  # (e.g. capture/video streams and stray ports without a link marker).
  while IFS= read -r id; do
    [[ -n "$id" ]] || continue
    props="$(wpctl inspect "$id" 2>/dev/null || true)"
    media_class="$(printf '%s\n' "$props" | awk -F' = ' '
      /^[[:space:]]*\*?[[:space:]]*media.class[[:space:]]*=/ {
        sub(/^[[:space:]]*"/, "", $2); sub(/"$/, "", $2); print $2; exit
      }')"
    [[ "$media_class" == "Stream/Output/Audio" ]] || continue
    candidate="$(printf '%s\n' "$props" | awk -F' = ' '
      /^[[:space:]]*\*?[[:space:]]*application.name[[:space:]]*=/ && !app {
        sub(/^[[:space:]]*"/, "", $2); sub(/"$/, "", $2); app = $2
      }
      /^[[:space:]]*\*?[[:space:]]*media.name[[:space:]]*=/ && !media {
        sub(/^[[:space:]]*"/, "", $2); sub(/"$/, "", $2); media = $2
      }
      /^[[:space:]]*\*?[[:space:]]*application.process.binary[[:space:]]*=/ && !bin {
        sub(/^[[:space:]]*"/, "", $2); sub(/"$/, "", $2); bin = $2
      }
      END { print (app ? app : (media ? media : bin)) }')"
    candidate_norm="$(printf '%s' "$candidate" | norm)"
    [[ -n "$candidate_norm" ]] || continue
    # Contains-either-way fuzzy match: "discord" matches "Discord",
    # "brave-browser" matches "Brave", etc.
    match=0
    case "$candidate_norm" in
      *"$class_norm"*) match=1 ;;
      *)
        case "$class_norm" in
          *"$candidate_norm"*) match=1 ;;
        esac
        ;;
    esac
    if [[ "$match" == 1 ]]; then
      matching_ids="$matching_ids $id"
      # Display name for the OSD toast (all matched streams share the app)
      [[ -n "$app_name" ]] || app_name="$candidate"
    fi
  done < <(wpctl status 2>/dev/null | awk '
    /Streams:/ { in_s = 1; base = -1; next }
    in_s && /^[[:space:]]*[A-Za-z]/ { in_s = 0 }
    in_s && match($0, /^[[:space:]]*[0-9]+\./) {
      ind = RSTART
      if (base == -1) base = ind
      if (ind != base) next
      id = $0
      sub(/^[[:space:]]*/, "", id)
      sub(/\..*/, "", id)
      print id
    }')
fi

if [[ -n "${matching_ids// /}" ]]; then
  for id in $matching_ids; do
    apply_stream "$id"
  done
  # OSD-style feedback via DMS toasts: hide + show updates in place on key
  # repeat, like the master volume OSD
  if [[ -n "$report" ]]; then
    dms ipc call toast hide >/dev/null 2>&1 || true
    dms ipc call toast info "$report" >/dev/null 2>&1 || true
  fi
else
  # Fallback: behave exactly like the plain volume keys (same step, same OSD)
  case "$mode" in
    up) exec dms ipc call audio increment 3 ;;
    down) exec dms ipc call audio decrement 3 ;;
    mute) exec dms ipc call audio mute ;;
  esac
fi
