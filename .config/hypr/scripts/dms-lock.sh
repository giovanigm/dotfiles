#!/usr/bin/env bash
# DMS lock screen — Quickshell layers destroy mpvpaper's surface on
# lock/unlock, freezing the video wallpaper. Suspend before locking and
# resume only after the lock is released (same dance the old
# qylock-lock-wrapped did).
SW="$HOME/.local/bin/set-wallpaper"
[ -x "$SW" ] && "$SW" --suspend || true

dms ipc call lock lock

# lock returns immediately; wait until the lock screen is gone
sleep 0.3
while dms ipc call lock isLocked | grep -q "true"; do
	sleep 0.5
done

[ -x "$SW" ] && "$SW" --resume || true
