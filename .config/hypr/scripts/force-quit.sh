#!/usr/bin/env bash
# Force-quit an application (SIGKILL).
#   no args: kill the focused window's process
#   CLASS:   kill every window whose class matches CLASS

kill_pid() {
    local pid="$1"
    if [[ "$pid" =~ ^[0-9]+$ ]] && [ "$pid" -gt 0 ]; then
        kill -9 "$pid" 2>/dev/null
    else
        return 1
    fi
}

# Class given as argument: kill all windows of that class
if [ -n "$1" ]; then
    COUNT=0
    while read -r pid title; do
        kill_pid "$pid" && COUNT=$((COUNT + 1))
    done < <(hyprctl clients -j | jq -r ".[] | select(.class == \"$1\") | \"\(.pid) \(.title // \"$1\")\"")
    if [ "$COUNT" -eq 0 ]; then
        dms ipc call toast info "No '$1' windows found" >/dev/null 2>&1 || true
    else
        dms ipc call toast info "Killed $COUNT '$1' window(s)" >/dev/null 2>&1 || true
    fi
    exit 0
fi

# No args: kill the focused window's process
WINDOW=$(hyprctl activewindow -j 2>/dev/null)
PID=$(echo "$WINDOW" | jq -r '.pid // 0' 2>/dev/null)
TITLE=$(echo "$WINDOW" | jq -r '.title // "window"' 2>/dev/null)

if kill_pid "$PID"; then
    dms ipc call toast info "Killed: $TITLE" >/dev/null 2>&1 || true
elif [ -n "$WINDOW" ]; then
    # Window exposes no killable PID (XWayland edge cases) — fall back to a close request
    hyprctl dispatch "hl.dsp.window.close()"
else
    dms ipc call toast info "No focused window" >/dev/null 2>&1 || true
fi
