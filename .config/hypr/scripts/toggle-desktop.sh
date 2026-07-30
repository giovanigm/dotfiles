#!/usr/bin/env bash
# Toggle "Show Desktop" — hides all windows on the current workspace
# into the special:showdesktop workspace, or restores them.
#
# Bound in hyprland.lua to: SUPER + D

SPECIAL_NAME="showdesktop"
SPECIAL_FULL="special:$SPECIAL_NAME"

# Is the special workspace currently visible on any monitor?
if hyprctl monitors -j | jq -e '.[] | select(.specialWorkspace.name == "'"$SPECIAL_FULL"'")' > /dev/null 2>&1; then
  # Already visible → hide it (windows snap back to their original workspaces)
  hyprctl dispatch "hl.dsp.workspace.toggle_special(\"$SPECIAL_NAME\")"
else
  # Not visible → move all windows from current workspace into the special workspace
  CURRENT_WS=$(hyprctl activeworkspace -j | jq -r '.id')
  hyprctl clients -j | jq -r --arg ws "$CURRENT_WS" \
    '.[] | select(.workspace.id == ($ws | tonumber)) | .address' | while read -r addr; do
    hyprctl dispatch "hl.dsp.window.move({workspace = \"$SPECIAL_FULL\", address = \"address:$addr\"})"
  done
  # Reveal the special workspace (all windows disappear → desktop shown)
  hyprctl dispatch "hl.dsp.workspace.toggle_special(\"$SPECIAL_NAME\")"
fi
