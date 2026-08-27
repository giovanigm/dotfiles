#!/usr/bin/env bash
# Reload the Quickshell bar.
# Under UWSM the bar is a systemd user service; before the first rebuild
# (or outside UWSM) fall back to a plain process restart.
if systemctl --user is-active --quiet quickshell.service 2>/dev/null; then
  systemctl --user restart quickshell.service
elif command -v quickshell >/dev/null 2>&1; then
  pkill -x quickshell 2>/dev/null || true
  sleep 0.3
  nohup quickshell >/dev/null 2>&1 &
fi
