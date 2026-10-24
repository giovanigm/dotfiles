#!/usr/bin/env bash
# Hyprland headless output used as Sunshine's virtual display.
#
#   setup       create the headless output and enforce the structural Sunshine
#               settings (capture method, output name, prep commands)
#   connect     make the headless output the only active monitor, at the
#               client's requested mode, showing the workspace the user was on
#               (run by Sunshine before launching an app)
#   disconnect  re-enable the physical monitors and restore the local workspace
#               (run by Sunshine after the app exits)
#
# Hyprland 0.55 runs the Lua config manager, where `hyprctl keyword` is not
# available: monitor/workspace changes go through `hyprctl eval` + hl.* API.
# The headless output must exist before Sunshine starts: wlr capture resolves
# output_name only once, at startup.

set -euo pipefail

headless="SUNSHINE-1"
state="${XDG_RUNTIME_DIR:-/tmp}/sunshine-virtual-display.state"
conf="${XDG_CONFIG_HOME:-$HOME/.config}/sunshine/sunshine.conf"
logfile="${XDG_RUNTIME_DIR:-/tmp}/sunshine-virtual-display.log"

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
  log "setup output=$headless"
  ensure_headless
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

  log "disconnect done: physical monitors restored"
}

case "${1:-}" in
  setup) setup ;;
  connect) connect ;;
  disconnect) disconnect ;;
  *)
    echo "usage: $0 {setup|connect|disconnect}" >&2
    exit 2
    ;;
esac
