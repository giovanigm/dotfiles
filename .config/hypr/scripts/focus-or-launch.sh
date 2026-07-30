#!/usr/bin/env bash
CLASS="$1"
CMD="$2"

# Check if there's already a focused window of this class that is maximized
CURRENT=$(hyprctl activewindow -j 2>/dev/null)
CURRENT_CLASS=$(echo "$CURRENT" | jq -r '.class // empty')
CURRENT_MAXED=$(echo "$CURRENT" | jq -r '.fullscreenClient // 0')

if [ "$CURRENT_CLASS" = "$CLASS" ] && [ "$CURRENT_MAXED" = "1" ]; then
    # Already focused and maximized — cycle to next window of same class
    CURRENT_ADDR=$(echo "$CURRENT" | jq -r '.address')
    ADDRS=($(hyprctl clients -j | jq -r ".[] | select(.class == \"$CLASS\") | .address"))
    if [ ${#ADDRS[@]} -gt 1 ]; then
        for i in "${!ADDRS[@]}"; do
            if [ "${ADDRS[$i]}" = "$CURRENT_ADDR" ]; then
                NEXT=$(( (i + 1) % ${#ADDRS[@]} ))
                hyprctl dispatch "hl.dsp.focus({window = \"address:${ADDRS[$NEXT]}\"})"
                hyprctl dispatch "hl.dsp.window.fullscreen({ mode = 1 })"
                break
            fi
        done
    fi
elif hyprctl clients -j | jq -e ".[] | select(.class == \"$CLASS\")" > /dev/null 2>&1; then
    # App exists but not focused — focus and maximize
    hyprctl dispatch "hl.dsp.focus({window = \"class:$CLASS\"})"
    if [ "$(hyprctl activewindow -j | jq -r '.fullscreenClient')" = "0" ]; then
        hyprctl dispatch "hl.dsp.window.fullscreen({ mode = 1 })"
    fi
else
    # App not running — launch and maximize
    hyprctl dispatch "hl.dsp.exec_cmd(\"$CMD\")"
    for i in $(seq 1 20); do
        sleep 0.1
        if hyprctl clients -j | jq -e ".[] | select(.class == \"$CLASS\")" > /dev/null 2>&1; then
            hyprctl dispatch "hl.dsp.window.fullscreen({ mode = 1 })"
            break
        fi
    done
fi
