#!/usr/bin/env bash
# focused-volume.sh — adjust the focused window's PipeWire playback streams.
# Bound to SUPER + volume keys in hyprland.lua; the plain volume keys keep
# controlling global volume via DMS.
#
# Usage: focused-volume.sh up|down|mute
#
# Streams are matched to the focused window by process PID first, then by
# fuzzy name matching against application.name / media.name / binary.
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
# Upper bound for raising a stream. Software gain allows >100%, and a stream
# must stay raisable even when the master (sink) volume is lower — capping at
# the sink made SUPER+up a no-op for any app at/above it. 1.5 mirrors
# pavucontrol's ~153% ceiling.
MAX_VOL=1.5

# Serialize rapid key-repeat invocations (the bindings use repeating = true)
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/focused-volume.lock"
flock -n 9 || exit 0

# Normalize a name for fuzzy matching: lowercase, alphanumeric only
norm() {
  tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9'
}

# Lowercased words of >= 3 chars, minus reverse-DNS boilerplate
words() {
  tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '\n' |
    grep -vE '^(info|com|org|net|io|app|www)$' | grep -E '.{3,}' || true
}

# Fuzzy match between two raw names: full-string contains-either-way on the
# normalized forms ("discord" vs "discordwrapped"), then any-word
# contains-either-way on the raw forms ("info.cemu.Cemu" vs "Cemu Cubeb").
matches() {
  local a="$1" b="$2" an bn aw bw
  an="$(printf '%s' "$a" | norm)"
  bn="$(printf '%s' "$b" | norm)"
  [[ -n "$an" && -n "$bn" ]] || return 1
  case "$an" in *"$bn"*) return 0 ;; esac
  case "$bn" in *"$an"*) return 0 ;; esac
  for aw in $(printf '%s' "$a" | words); do
    for bw in $(printf '%s' "$b" | words); do
      case "$aw" in *"$bw"*) return 0 ;; esac
      case "$bw" in *"$aw"*) return 0 ;; esac
    done
  done
  return 1
}

# Focused window class and pid (empty when nothing is focused)
focused_class="$(hyprctl activewindow -j 2>/dev/null | jq -r '.class // empty' 2>/dev/null || true)"
focused_pid="$(hyprctl activewindow -j 2>/dev/null | jq -r '.pid // empty' 2>/dev/null || true)"
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
      new="$(awk -v v="$vol" -v s="$STEP" -v m="$MAX_VOL" 'BEGIN { printf "%.2f", (v >= m ? v : (v + s > m ? m : v + s)) }')"
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
    # Authoritative PID match first: the focused window's own process owns the
    # stream, which covers apps whose stream names share nothing with the
    # window class (e.g. Azahar's "Azahar Output" under the Dekui frontend,
    # window class "io.github.tgacquin.dekui").
    match=0
    stream_pid="$(printf '%s\n' "$props" | awk -F' = ' '
      /^[[:space:]]*\*?[[:space:]]*application.process.id[[:space:]]*=/ {
        sub(/^[[:space:]]*"/, "", $2); sub(/"$/, "", $2); print $2; exit
      }')"
    if [[ -n "$focused_pid" && -n "$stream_pid" && "$stream_pid" == "$focused_pid" ]]; then
      match=1
    fi
    # Fall back to matching every name the stream exposes, not just
    # application.name: Discord's stream is "WEBRTC VoiceEngine" and only its
    # process binary (.Discord-wrapped) matches the window class "discord";
    # Cemu's window class is the reverse-DNS "info.cemu.Cemu" and only
    # word-level matching against "Cemu Cubeb" catches it.
    if [[ "$match" == 0 ]]; then
      while IFS= read -r candidate; do
        [[ -n "$(printf '%s' "$candidate" | norm)" ]] || continue
        if matches "$candidate" "$focused_class"; then
          # Display name for the OSD toast; candidates are printed in
          # application.name, media.name, binary order, so the first match
          # prefers the friendliest name
          [[ -n "$app_name" ]] || app_name="$candidate"
          match=1
          break
        fi
      done < <(printf '%s\n' "$props" | awk -F' = ' '
        /^[[:space:]]*\*?[[:space:]]*application.name[[:space:]]*=/ ||
        /^[[:space:]]*\*?[[:space:]]*media.name[[:space:]]*=/ ||
        /^[[:space:]]*\*?[[:space:]]*application.process.binary[[:space:]]*=/ {
          sub(/^[[:space:]]*"/, "", $2); sub(/"$/, "", $2); print $2
        }')
    fi
    # PID matches never went through the candidate loop: take the friendliest
    # prop directly (same preference order) for the OSD toast
    if [[ "$match" == 1 && -z "$app_name" ]]; then
      app_name="$(printf '%s\n' "$props" | awk -F' = ' '
        /^[[:space:]]*\*?[[:space:]]*application.name[[:space:]]*=/ ||
        /^[[:space:]]*\*?[[:space:]]*media.name[[:space:]]*=/ ||
        /^[[:space:]]*\*?[[:space:]]*application.process.binary[[:space:]]*=/ {
          sub(/^[[:space:]]*"/, "", $2); sub(/"$/, "", $2); print $2; exit
        }')"
    fi
    [[ "$match" == 1 ]] || continue
    matching_ids="$matching_ids $id"
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
