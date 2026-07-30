#!/usr/bin/env bash
# Reload Waybar: try graceful SIGUSR2, fall back to full restart
pid=""
for name in waybar waybar-wrapped .waybar-wrapped; do
    pid=$(pgrep -x "$name" 2>/dev/null | head -1)
    [ -n "$pid" ] && break
done

if [ -n "$pid" ]; then
    kill -USR2 "$pid" 2>/dev/null
    sleep 0.3
    if kill -0 "$pid" 2>/dev/null; then
        exit 0  # graceful reload succeeded
    fi
fi
waybar &  # restart (wasn't running or crashed on reload)
