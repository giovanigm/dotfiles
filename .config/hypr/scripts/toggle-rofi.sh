#!/usr/bin/env bash
# Toggle rofi: launch if not running, kill if it is
if pgrep -x rofi >/dev/null; then
    pkill rofi
else
    rofi -show drun
fi
