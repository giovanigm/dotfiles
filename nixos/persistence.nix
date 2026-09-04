{ ... }: {
  environment.persistence."/persist" = {
    hideMounts = true;

    directories = [
      # /etc/nixos is now a symlink → ~/dev/dotfiles/nixos (recreated by tmpfiles rule)
      "/etc/NetworkManager/system-connections"
      "/var/log"
      "/var/lib/nixos"
      "/var/lib/bluetooth"
      "/var/lib/systemd/coredump"
      "/var/lib/systemd/timers"
      "/var/lib/docker"
      "/var/db/sudo"
      # Greeter memory (last session/user, light/dark mode) — tmpfs otherwise,
      # tmpfiles creates it 0750 dms-greeter:dms-greeter, match that on the
      # persisted copy so the greeter can write memory.json
      { directory = "/var/lib/dms-greeter"; user = "dms-greeter"; group = "dms-greeter"; mode = "0750"; }
    ];

    files = [
      "/etc/machine-id"
      "/etc/ssh/ssh_host_ed25519_key"
      "/etc/ssh/ssh_host_ed25519_key.pub"
      "/etc/ssh/ssh_host_rsa_key"
      "/etc/ssh/ssh_host_rsa_key.pub"
    ];
  };
}
