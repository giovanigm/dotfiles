#!/usr/bin/env bash
# Recover a Logitech G305 mouse that the kernel failed to announce at boot.
#
# The Lightspeed receiver (046d:c53f) enumerates normally, but hid-logitech-dj
# can miss the receiver's HID++ "device connected" notification during probe
# (or the queued work can run before the driver's ready flag is set). The
# driver never retries the query, so the mouse's input node is never created
# and it stays dead until the receiver is physically replugged.
#
# This script performs the same software replug through the USB unbind/bind
# interfaces. It only acts when no mouse input node exists, so it is a no-op
# on normal boots. Run manually as root:
#
#   sudo logitech-mouse-rescan
#
# The boot service logitech-mouse-recover.service runs it automatically.

readonly RECEIVER_VID="046d"
readonly RECEIVER_PID="c53f"
readonly RECEIVER_WAIT=10 # seconds to wait for the receiver at boot
readonly MOUSE_GRACE=5    # seconds the driver gets to announce it by itself
readonly MAX_ATTEMPTS=3   # software replugs before giving up
readonly REPLUG_WAIT=8    # seconds to wait for the mouse after each replug

log() {
  printf '[logitech-mouse-rescan] %s\n' "$*"
}

if [[ ${EUID} -ne 0 ]]; then
  log "execute como root: sudo logitech-mouse-rescan"
  exit 1
fi

mouse_present() {
  grep -qE 'Name="(Logitech G305|Logitech Wireless Mouse PID:4074)"' /proc/bus/input/devices
}

find_receiver() {
  local dev
  for dev in /sys/bus/usb/devices/*/; do
    if [[ "$(cat "${dev}idVendor" 2>/dev/null)" == "$RECEIVER_VID" &&
      "$(cat "${dev}idProduct" 2>/dev/null)" == "$RECEIVER_PID" ]]; then
      basename "$dev"
      return 0
    fi
  done
  return 1
}

wait_for_receiver() {
  local i
  for ((i = 0; i < RECEIVER_WAIT; i++)); do
    if find_receiver; then
      return 0
    fi
    sleep 1
  done
  find_receiver
}

wait_for_mouse() {
  local seconds=$1
  local i
  for ((i = 0; i < seconds; i++)); do
    if mouse_present; then
      return 0
    fi
    sleep 1
  done
  mouse_present
}

receiver=""
if ! receiver=$(wait_for_receiver); then
  log "receptor ${RECEIVER_VID}:${RECEIVER_PID} ausente; nada a fazer"
  exit 0
fi
log "receptor encontrado em ${receiver}"

if wait_for_mouse "$MOUSE_GRACE"; then
  log "mouse presente; nada a fazer"
  exit 0
fi

# A USB unbind/bind makes the receiver announce the paired mouse again, which
# is exactly what a physical replug does (the receiver only re-announces on a
# new enumeration).
for ((attempt = 1; attempt <= MAX_ATTEMPTS; attempt++)); do
  log "mouse ausente; replug virtual do receptor (tentativa ${attempt}/${MAX_ATTEMPTS})"

  if ! echo "$receiver" >/sys/bus/usb/drivers/usb/unbind 2>/dev/null; then
    log "aviso: unbind falhou"
  fi
  sleep 1
  if ! echo "$receiver" >/sys/bus/usb/drivers/usb/bind 2>/dev/null; then
    log "aviso: bind falhou"
  fi

  if wait_for_mouse "$REPLUG_WAIT"; then
    log "mouse recuperado"
    exit 0
  fi
done

log "não foi possível recuperar o mouse; replug físico do receptor é necessário"
exit 1
