{ config, pkgs, lib, inputs, ... }:

let
  grubTheme = inputs.distro-grub-themes.packages.${pkgs.system}.nixos-grub-theme;
in
{
  # ── GRUB (EFI) ─────────────────────────────────────────────
  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    # EFI-only machine: `nodev` skips the BIOS install only; the EFI
    # install still runs (grub-install targets the ESP mount point).
    # Required: the `mirroredBoots` assertion needs device/devices set.
    device = "nodev";
    # Windows is chainloaded manually — os-prober would add duplicate
    # or oddly-named entries from the separate Windows ESP.
    useOSProber = false;
    # Menu order (install-grub.pl): 0=NixOS (current gen),
    # 1=Windows 11 (extraEntries), 2="NixOS - All configurations"
    # submenu. Index is positional — recheck if extra entries change.
    # (String defaults are emitted unquoted by install-grub.pl — broken.)
    default = 0;
    # distro-grub-themes: NixOS variant (github:AdisonCavani/distro-grub-themes)
    theme = grubTheme;
    splashImage = "${grubTheme}/splash_image.jpg";
    gfxmodeEfi = "2560x1440"; # monitor native res (theme docs recommend fixed res over "auto")
    extraEntries = ''
      menuentry "Windows 11" {
        search --fs-uuid --set=root FAB7-2B63
        chainloader /EFI/Microsoft/Boot/bootmgfw.efi
      }
    '';
  };
  boot.loader.timeout = 5; # show the menu, then boot NixOS
  boot.loader.efi.canTouchEfiVariables = true;
}
