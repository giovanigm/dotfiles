#!/usr/bin/env bash
# Hyprland headless output used as Sunshine's virtual display.
#
#   setup       write the structural Sunshine settings (capture method, output
#               name, prep commands) and drop a stale headless output
#   connect     create the headless output, make it the only active monitor at
#               the client's requested mode, showing the workspace the user was
#               on (run by Sunshine before launching an app)
#   disconnect  re-enable the physical monitors, restore the local workspace and
#               schedule the removal of the headless output
#   cleanup     remove the headless output once no stream is running
#
# Hyprland 0.55 runs the Lua config manager, where `hyprctl keyword` is not
# available: monitor/workspace changes go through `hyprctl eval` + hl.* API.
#
# The output exists only while a stream is active. Sunshine resolves
# output_name when the capture thread starts (once per stream, after the
# global prep commands ran), not when Sunshine starts, so creating it in
# connect is early enough. An always-enabled virtual monitor is actively
# harmful: when the physical monitor disappears (standby, DPMS, power button)
# Hyprland picks SUNSHINE-1 as the backup output, warps the cursor to its
# center (off the 10000x0 parking spot) and moves every workspace onto it.
# When the physical monitor comes back, focus and cursor stay on the virtual
# output, so SUPER+1..0 (on_current_monitor) move workspaces where they cannot
# be seen.

set -euo pipefail

headless="SUNSHINE-1"
state="${XDG_RUNTIME_DIR:-/tmp}/sunshine-virtual-display.state"
conf="${XDG_CONFIG_HOME:-$HOME/.config}/sunshine/sunshine.conf"
logfile="${XDG_RUNTIME_DIR:-/tmp}/sunshine-virtual-display.log"
self="$(readlink -f "$0")"

log() {
  printf '%s %s\n' "$(date -Is)" "$*" >>"$logfile"
}

wait_hypr() {
  for _ in $(seq 1 100); do
    if hyprctl -j monitors >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.1
  done
  echo "sunshine-virtual-display: Hyprland is not reachable" >&2
  return 1
}

has_headless() {
  hyprctl -j monitors | jq -e --arg h "$headless" '.[] | select(.name == $h)' >/dev/null
}

set_mode() {
  local width="$1" height="$2" fps="$3"
  hyprctl eval "hl.monitor({ output = \"$headless\", mode = \"${width}x${height}@${fps}\", position = \"auto\", scale = 1 })" >/dev/null
}

ensure_headless() {
  wait_hypr
  if ! has_headless; then
    # Drop a stale/disabled output with the same name, then recreate it.
    hyprctl output remove "$headless" >/dev/null 2>&1 || true
    hyprctl output create headless "$headless" >/dev/null
    for _ in $(seq 1 20); do
      has_headless && break
      sleep 0.1
    done
    if ! has_headless; then
      echo "sunshine-virtual-display: could not create $headless" >&2
      return 1
    fi
  fi
  set_mode 1920 1080 60
}

physical_monitor() {
  hyprctl -j monitors | jq -r --arg h "$headless" \
    '[.[] | select(.name != $h)
         | select((.name | startswith("SUNSHINE-") or startswith("HEADLESS-")) | not)
         | select(.disabled != true)][0].name // empty'
}

session_locked() {
  local sid="${XDG_SESSION_ID:-}" id _uid user _seat _leader class
  # Sunshine's user service environment does not carry XDG_SESSION_ID; find
  # the graphical session of this user instead.
  if [[ -z "$sid" ]]; then
    while read -r id _uid user _seat _leader class _; do
      if [[ "$user" == "${USER:-}" && "$class" == "user" ]]; then
        sid="$id"
        break
      fi
    done < <(loginctl list-sessions --no-legend 2>/dev/null || true)
  fi
  [[ -n "$sid" ]] || return 1
  [[ "$(loginctl show-session "$sid" -P LockedHint 2>/dev/null || true)" == "yes" ]]
}

# Move every user workspace off the virtual output and park it on workspace 99.
# Needed after a stream (Hyprland moves the physical monitor's workspaces onto
# the headless while it is disabled) and as manual recovery after a cable swap
# (the headless can receive stray workspaces while it exists).
rehome() {
  local target previous id
  target="$(physical_monitor)"
  [[ -n "$target" ]] || return 0
  previous="$(hyprctl activeworkspace -j | jq -r '.id')"

  while IFS= read -r id; do
    [[ -n "$id" ]] || continue
    hyprctl eval "hl.dispatch(hl.dsp.workspace.move({ workspace = $id, monitor = \"$target\" }))" >/dev/null 2>&1 || true
  done < <(hyprctl -j workspaces | jq -r --arg h "$headless" \
    '.[] | select(.monitor == $h and .id > 0 and .id != 99) | .id')

  # A disabled output cannot be captured, so SUNSHINE-1 stays enabled; parking
  # it on 99 (and off-grid) keeps it from stealing workspace numbers or focus.
  hyprctl eval "hl.dispatch(hl.dsp.focus({ monitor = \"$headless\" }))" >/dev/null 2>&1 || true
  hyprctl eval "hl.dispatch(hl.dsp.focus({ workspace = 99 }))" >/dev/null 2>&1 || true
  hyprctl eval "hl.dispatch(hl.dsp.focus({ monitor = \"$target\" }))" >/dev/null 2>&1 || true
  hyprctl eval "hl.dispatch(hl.dsp.focus({ workspace = $previous }))" >/dev/null 2>&1 || true
}

park_offscreen() {
  hyprctl eval "hl.monitor({ output = \"$headless\", position = \"10000x0\" })" >/dev/null 2>&1 || true
}

upsert() {
  local key="$1" value="$2"
  mkdir -p "$(dirname "$conf")"
  touch "$conf"
  if grep -qE "^[[:space:]]*${key}[[:space:]]*=" "$conf"; then
    sed -i -E "s|^[[:space:]]*${key}[[:space:]]*=.*|${key} = ${value}|" "$conf"
  else
    printf '%s = %s\n' "$key" "$value" >>"$conf"
  fi
}

save_state() {
  local workspace monitors
  workspace="$(hyprctl activeworkspace -j | jq -c '{workspace: .id, monitor: .monitor}')"
  monitors="$(hyprctl -j monitors | jq -c '[.[] | select(.name | startswith("SUNSHINE-") | not) | {name, width, height, refreshRate, x, y, scale}]')"
  jq -n --argjson w "$workspace" --argjson m "$monitors" '$w + {monitors: $m}' >"$state"
}

setup() {
  log "setup: config only (the output is created on connect)"
  # Older generations created the output at login. Drop it unless a stream is
  # running right now (restarting this unit mid-stream must not kill capture).
  if [[ ! -f "$state" ]] && hyprctl -j monitors >/dev/null 2>&1 && has_headless; then
    hyprctl output remove "$headless" >/dev/null 2>&1 || true
    log "setup: removed stale $headless"
  fi
  upsert capture wlr
  upsert output_name "$headless"
  upsert encoder nvenc
  upsert global_prep_cmd "[{\"do\":\"$0 connect\",\"undo\":\"$0 disconnect\"}]"
}

connect() {
  log "connect client=${SUNSHINE_CLIENT_WIDTH:-?}x${SUNSHINE_CLIENT_HEIGHT:-?}@${SUNSHINE_CLIENT_FPS:-?} hdr=${SUNSHINE_CLIENT_HDR:-?}"

  ensure_headless

  local width="${SUNSHINE_CLIENT_WIDTH:-1920}"
  local height="${SUNSHINE_CLIENT_HEIGHT:-1080}"
  local fps="${SUNSHINE_CLIENT_FPS:-60}"

  # Remember the local layout only on the first app of a session.
  if [[ ! -f "$state" ]]; then
    save_state
  fi

  set_mode "$width" "$height" "$fps"

  # Disable every physical monitor: the headless output becomes the only one,
  # so newly launched games cannot land on the physical display.
  while IFS= read -r mon; do
    [[ -n "$mon" ]] || continue
    hyprctl eval "hl.monitor({ output = \"$mon\", disabled = true })" >/dev/null
  done < <(jq -r '.monitors[].name' "$state")

  # Hyprland moves the disabled monitors' workspaces here; show the one the
  # user was looking at (its windows, including running games, come along).
  local previous
  previous="$(jq -r .workspace "$state")"
  hyprctl eval "hl.dispatch(hl.dsp.focus({ workspace = $previous }))" >/dev/null 2>&1 || \
    hyprctl eval "hl.dispatch(hl.dsp.focus({ monitor = \"$headless\" }))" >/dev/null 2>&1 || true

  log "connect done: ${width}x${height}@${fps}, physical monitors disabled"
}

disconnect() {
  local previous="" previous_monitor=""
  if [[ -f "$state" ]]; then
    previous="$(jq -r .workspace "$state")"
    previous_monitor="$(jq -r .monitor "$state")"
  fi
  log "disconnect previous_ws=${previous:-none} previous_monitor=${previous_monitor:-none}"

  # Re-enable the physical monitors with the modes/positions they had.
  if [[ -f "$state" ]]; then
    while IFS=$'\t' read -r name mode pos scale; do
      [[ -n "$name" ]] || continue
      hyprctl eval "hl.monitor({ output = \"$name\", mode = \"$mode\", position = \"$pos\", scale = $scale, disabled = false })" >/dev/null 2>&1 || true
    done < <(jq -r '.monitors[] | [.name, "\(.width)x\(.height)@\(.refreshRate)", "\(.x)x\(.y)", .scale] | @tsv' "$state")
    rm -f "$state"
  fi

  # Reload the Lua config to restore the fields the monitor JSON does not
  # expose (HDR/cm, bitdepth, sdr_eotf, vrr) and the SUNSHINE-1 default mode.
  hyprctl reload >/dev/null 2>&1 || true

  # Move anything still on the headless output back to the physical monitor.
  local target="${previous_monitor:-}"
  if [[ -z "$target" ]]; then
    target="$(hyprctl -j monitors | jq -r --arg h "$headless" '[.[] | select(.name != $h)][0].name // empty')"
  fi
  if [[ -n "$target" ]]; then
    while IFS= read -r id; do
      [[ -n "$id" ]] || continue
      hyprctl eval "hl.dispatch(hl.dsp.workspace.move({ workspace = $id, monitor = \"$target\" }))" >/dev/null 2>&1 || true
    done < <(hyprctl -j workspaces | jq -r --arg h "$headless" '.[] | select(.monitor == $h and .id > 0) | .id')
  fi

  set_mode 1920 1080 60 >/dev/null 2>&1 || true

  if [[ -n "$previous" ]]; then
    hyprctl eval "hl.dispatch(hl.dsp.focus({ workspace = $previous }))" >/dev/null 2>&1 || true
  fi

  # set_mode above forces position=auto; restore the off-grid position and
  # park the headless again so it cannot keep any workspace or be reached
  # during the short window before cleanup removes it.
  rehome >/dev/null 2>&1 || true
  park_offscreen

  # SUNSHINE-1 must not outlive the stream: an idle virtual monitor becomes
  # Hyprland's backup output when the physical monitor disappears, which warps
  # the cursor off-screen and moves workspaces onto it. Removing it right here
  # would race the capture thread that is still winding down, so defer.
  schedule_cleanup

  log "disconnect done: physical monitors restored"
}

# Remove the virtual output once every stream has torn down. Runs detached a
# few seconds after disconnect, because Sunshine's undo command can fire while
# its capture thread is still running. Returns 1 when it should be retried.
cleanup() {
  # A new stream already started (connect re-created the state file).
  [[ -f "$state" ]] && return 0

  has_headless || return 0

  # Removing an output while the session is locked can break the
  # ext-session-lock surfaces; retry later.
  if session_locked; then
    log "cleanup deferred: session locked"
    return 1
  fi

  # SUNSHINE-1 is the only monitor while the physical one is away; removing it
  # would leave Hyprland without outputs. Retry later.
  if [[ -z "$(physical_monitor)" ]]; then
    log "cleanup deferred: no physical monitor"
    return 1
  fi

  local cursor x y
  cursor="$(hyprctl cursorpos 2>/dev/null || true)"

  if ! hyprctl output remove "$headless" >/dev/null 2>&1; then
    log "cleanup: could not remove $headless"
    return 0
  fi

  # Removing a monitor warps the cursor to the backup monitor's center; put it
  # back where it was.
  if [[ "$cursor" =~ ^(-?[0-9]+),[[:space:]]*(-?[0-9]+)$ ]]; then
    x="${BASH_REMATCH[1]}"
    y="${BASH_REMATCH[2]}"
    hyprctl eval "hl.dispatch(hl.dsp.cursor.move({ x = $x, y = $y }))" >/dev/null 2>&1 || true
  fi

  log "cleanup: removed $headless"
  return 0
}

schedule_cleanup() {
  setsid "$self" cleanup-after >/dev/null 2>&1 &
}

cleanup-after() {
  local delay="${1:-10}"
  sleep "$delay"
  for _ in $(seq 1 20); do
    cleanup && return 0
    sleep 30
  done
  log "cleanup: giving up for now (will retry on the next stream/setup)"
}

case "${1:-}" in
  setup) setup ;;
  connect) connect ;;
  disconnect) disconnect ;;
  cleanup) cleanup ;;
  cleanup-after) cleanup-after "${2:-10}" ;;
  rehome) rehome ;;
  *)
    echo "usage: $0 {setup|connect|disconnect|cleanup|cleanup-after [delay]|rehome}" >&2
    exit 2
    ;;
esac
