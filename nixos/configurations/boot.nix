{ config, pkgs, lib, ... }:

{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Windows is on a separate ESP (nvme0n1p1) — make it visible to systemd-boot
  fileSystems."/boot/efi-windows" = {
    device = "/dev/disk/by-partuuid/5954f994-0d27-453d-983e-e4954f3535df";
    fsType = "vfat";
    options = [ "ro" "noauto" "noatime" ];
  };

  boot.loader.systemd-boot.extraInstallCommands = ''
    ${pkgs.coreutils}/bin/mkdir -p /boot/EFI /tmp/win-esp
    ${pkgs.util-linux}/bin/mount /dev/disk/by-partuuid/5954f994-0d27-453d-983e-e4954f3535df /tmp/win-esp
    if [ -d /tmp/win-esp/EFI/Microsoft ]; then
      ${pkgs.coreutils}/bin/cp -r /tmp/win-esp/EFI/Microsoft /boot/EFI/
      echo "Copied Windows boot files → /boot/EFI/Microsoft"
    fi
    ${pkgs.util-linux}/bin/umount /tmp/win-esp
    # Disable auto-detected entries so we control ordering via manual entries
    ${pkgs.gnused}/bin/sed -i '1i auto-entries 0' /boot/loader/loader.conf
    # Make Windows the default (focused) entry
    ${pkgs.gnused}/bin/sed -i 's/^default .*/default windows.conf/' /boot/loader/loader.conf
  '';

  # Manual Windows entry with sort-key that comes before NixOS entries
  boot.loader.systemd-boot.extraEntries = {
    "windows.conf" = ''
      title Windows 11
      efi /EFI/Microsoft/Boot/bootmgfw.efi
      sort-key a_windows
    '';
  };
}
