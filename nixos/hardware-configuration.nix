{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [ (modulesPath + "/installer/scan/not-detected.nix")
    ];

  boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "ahci" "usbhid" "usb_storage" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  # ── Tmpfs root (ephemeral, wiped every boot) ───────
  fileSystems."/" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = [ "defaults" "mode=755" ];
  };

  # ── Persistence partition (was root, same UUID) ────
  fileSystems."/persist" = {
    device = "/dev/disk/by-uuid/511923aa-8a7f-4597-a6fb-be305937f22e";
    fsType = "ext4";
    neededForBoot = true;
  };

  # ── Nix store (bind mount from persist) ────────────
  fileSystems."/nix" = {
    device = "/persist/nix";
    fsType = "none";
    options = [ "bind" ];
    neededForBoot = true;
  };

  # ── Home (bind mount, fully persistent) ────────────
  fileSystems."/home" = {
    device = "/persist/home";
    fsType = "none";
    options = [ "bind" ];
    neededForBoot = true;
  };

  # ── Boot (ESP, unchanged) ──────────────────────────
  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/B482-E14E";
    fsType = "vfat";
    options = [ "fmask=0077" "dmask=0077" ];
  };

  swapDevices = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
