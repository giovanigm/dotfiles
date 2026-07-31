{ config, pkgs, lib, ... }:

{
  # ── DDC/CI monitor brightness control ─────────────────────
  # Loads the i2c-dev kernel module, creates the "i2c" group,
  # and adds a udev rule granting /dev/i2c-* access. Required
  # by ddcutil to drive the external monitor's DDC/CI channel
  # (NVIDIA registers the DP connector as an i2c adapter).
  hardware.i2c.enable = true;
}
