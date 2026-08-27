{ config, pkgs, lib, ... }:

{
  users.mutableUsers = false;

  users.users."giovani" = {
    isNormalUser = true;
    description = "giovani";
    extraGroups = [ "networkmanager" "wheel" "docker" "i2c" "input" ];
    shell = pkgs.zsh;
    hashedPasswordFile = "/persist/passwords/giovani";
  };
}
