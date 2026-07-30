#!/usr/bin/env bash
# Pick a random wallpaper from the Catppuccin Mocha collection
# and set it with awww. Pass "next" to cycle to a different one.

WALLDIR="$HOME/Pictures/walls-catppuccin-mocha-master"
CACHE="$HOME/.cache/current-wallpaper"

# Wait for awww-daemon to be ready (up to 5 seconds)
for i in $(seq 1 50); do
  awww query &>/dev/null && break
  sleep 0.1
done

# If "next" is passed, exclude the current wallpaper
if [ "$1" = "next" ] && [ -f "$CACHE" ]; then
  WALL=$(find "$WALLDIR" -type f \( -iname '*.jpg' -o -iname '*.png' -o -iname '*.jpeg' \) \
    ! -name "$(cat "$CACHE")" | shuf -n1)
else
  WALL=$(find "$WALLDIR" -type f \( -iname '*.jpg' -o -iname '*.png' -o -iname '*.jpeg' \) \
    | shuf -n1)
fi

# If we couldn't find a different one, just pick any
[ -z "$WALL" ] && WALL=$(find "$WALLDIR" -type f \( -iname '*.jpg' -o -iname '*.png' -o -iname '*.jpeg' \) | shuf -n1)

if [ -n "$WALL" ]; then
  awww img "$WALL" \
    --transition-type any \
    --transition-fps 60 \
    --transition-duration 1.5 \
    --transition-bezier .43,1.19,1,.4
  basename "$WALL" > "$CACHE"
fi
