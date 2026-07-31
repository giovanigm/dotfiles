#!/usr/bin/env bash
# DDC/CI brightness control for the external monitor (DP-5, NVIDIA RTX 3080)
# Usage: monitor-brightness.sh up|down
set -euo pipefail

# ddcutil holds the I2C bus for ~0.5 s per call; serialize concurrent
# invocations from key-repeat so a held key doesn't spawn overlapping
# processes (causes I2C bus contention).
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/ddcutil-brightness.lock"
flock -n 9 || exit 0

case "${1:-}" in
  up)   ddcutil --display 1 --sleep-multiplier 0.04 --noverify setvcp 10 + 5 ;;
  down) ddcutil --display 1 --sleep-multiplier 0.04 --noverify setvcp 10 - 5 ;;
  *)    echo "usage: $0 up|down" >&2; exit 1 ;;
esac
