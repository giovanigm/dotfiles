# nixos/configurations/filesystems.nix — NTFS / filesystem support

{ config, pkgs, lib, ... }:

{
  # ── NTFS driver stack ──────────────────────────────────────
  # ntfs3: in-kernel driver (fast, mature on kernel 6.18); preloaded so
  #        udisks2/libblockdev use it instead of FUSE.
  # ntfs-3g: FUSE fallback + fsck.ntfs/ntfsfix repair tools, pulled in via
  #          boot.supportedFilesystems = [ "ntfs" ].
  boot.kernelModules = [ "ntfs3" ];
  boot.supportedFilesystems = [ "ntfs" ];

  # ── Dynamic mounting (Nautilus → Other Locations) ─────────
  services.udisks2.enable = true;
  services.gvfs.enable = true;   # dbus + systemd-user activation for Nautilus

  # Ensure udisks2 starts after rebuild (systemd.packages alone
  # doesn't create the WantedBy symlink during switch).
  systemd.services.udisks2.wantedBy = [ "multi-user.target" ];

  # Unmark NTFS partitions as "system" so Nautilus shows them.
  # By default, udisks2 sets HintSystem=true for all NTFS partitions,
  # which hides them from file managers.
  services.udev.extraRules = ''
    ENV{ID_FS_TYPE}=="ntfs", ENV{UDISKS_SYSTEM}="0"
  '';

  # ── Passwordless mount/unmount for the desktop user ───────
  # Internal (non-removable) NTFS partitions gate on
  # org.freedesktop.udisks2.filesystem-mount-system, which requires admin
  # auth by default. Allow it for this user without prompting.
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (subject.user == "giovani" &&
          (action.id == "org.freedesktop.udisks2.filesystem-mount" ||
           action.id == "org.freedesktop.udisks2.filesystem-mount-system" ||
           action.id == "org.freedesktop.udisks2.filesystem-unmount-others" ||
           action.id == "org.freedesktop.udisks2.eject-media")) {
        return polkit.Result.YES;
      }
    });
  '';

  # ── Optional: fixed mount for the Windows drive ───────────
  # Find the UUID first:  lsblk -f   (or: blkid /dev/nvme0n1*)
  # Typical layout: nvme0n1p1 = Windows ESP (chainloaded by GRUB from boot.nix),
  #                 nvme0n1p3 = Windows C: (NTFS), p4 = recovery
  # Uncomment once the UUID is known:
  # fileSystems."/mnt/windows" = {
  #   device = "/dev/disk/by-uuid/REPLACE_WITH_NTFS_UUID";
  #   fsType = "ntfs3";
  #   # "ro" protects against Windows Fast Startup / hibernation corruption;
  #   # "noauto" + "x-systemd.automount" = mount on first access, no boot delay.
  #   options = [ "ro" "noatime" "noauto" "x-systemd.automount" ];
  # };
}
