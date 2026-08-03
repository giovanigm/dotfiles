# nixos/configurations/nix-ld.nix — Run generic Linux binaries on NixOS
#
# NixOS lacks the standard FHS dynamic linker paths (/lib64/ld-linux-x86-64.so.2).
# nix-ld intercepts the "Could not start dynamically linked executable" error and
# provides the linker + libraries those binaries expect.
#
# Needed by: FVM (Flutter/Dart SDK), AppImages, prebuilt Node.js native addons,
#            uvx, or any third-party binary not packaged for Nix.

{ pkgs, ... }:

{
  programs.nix-ld = {
    enable = true;

    libraries = with pkgs; [
      # ── Base / C runtime ──────────────────────────────────
      stdenv.cc.cc          # libstdc++.so.6, libgcc_s.so.1
      zlib                  # libz.so.1
      zstd                  # libzstd.so.1
      bzip2                 # libbz2.so.1
      xz                    # liblzma.so.5
      libxcrypt-legacy      # libcrypt.so.1 (legacy hash)

      # ── TLS / crypto / networking ─────────────────────────
      openssl               # libssl.so.3, libcrypto.so.3
      curl                  # libcurl.so.4
      libssh                # libssh.so.4
      libsodium             # libsodium.so.23
      nss                   # libnss3.so, libsmime3.so (Android emulator)
      nspr                  # libnspr4.so, libplds4.so, libplc4.so (Android emulator)

      # ── System libraries ──────────────────────────────────
      systemd               # libsystemd.so.0
      util-linux            # libuuid.so.1, libblkid.so.1, libmount.so.1
      e2fsprogs             # libcom_err.so.2
      acl                   # libacl.so.1
      attr                  # libattr.so.1
      keyutils              # libkeyutils.so.1
      expat                 # libexpat.so.1 (Android emulator QEMU)
      libbsd                # libbsd.so.0 (Android emulator launcher)

      # ── GLib / GIO ────────────────────────────────────────
      glib                  # libglib-2.0.so.0, libgio-2.0.so.0, libgobject-2.0.so.0
      dbus                  # libdbus-1.so.3

      # ── Graphics / GPU (Flutter uses Skia via OpenGL/Vulkan) ─
      libGL                 # libGL.so.1
      vulkan-loader         # libvulkan.so.1
      libpng                # libpng16.so.16 (Android emulator QEMU)
      libdrm                # libdrm.so.2
      libva                 # libva.so.2

      # ── GTK / UI (for GUI Flutter apps, file dialogs, etc.) ─
      gtk3                  # libgtk-3.so.0
      pango                 # libpango-1.0.so.0
      cairo                 # libcairo.so.2
      gdk-pixbuf            # libgdk_pixbuf-2.0.so.0
      atk                   # libatk-1.0.so.0
      fontconfig            # libfontconfig.so.1
      freetype              # libfreetype.so.6

      # ── X11 / Wayland (xorg.* deprecated → top-level in nixpkgs 26.05) ─
      libx11                # libX11.so.6
      libxext               # libXext.so.6
      libxrandr             # libXrandr.so.2
      libxrender            # libXrender.so.1
      libxdamage            # libXdamage.so.1
      libxfixes             # libXfixes.so.3
      libxcomposite         # libXcomposite.so.1
      libxi                 # libXi.so.6
      libxcursor            # libXcursor.so.1
      libxcb                # libxcb.so.1
      libxxf86vm            # libXxf86vm.so.1
      libxinerama           # libXinerama.so.1
      libxscrnsaver         # libXss.so.1
      libsm                 # libSM.so.6
      libice                # libICE.so.6
      libxft                # libXft.so.2
      libxt                 # libXt.so.6
      libxtst               # libXtst.so.6
      libxkbfile            # libxkbfile.so.1 (Android emulator QEMU)

      # ── Audio (Flutter apps may need this) ────────────────
      alsa-lib              # libasound.so.2
      libpulseaudio         # libpulse.so.0 (Android emulator QEMU)
      pipewire              # libpipewire-0.3.so.0

      # ── ICU (Unicode, often needed) ───────────────────────
      icu                   # libicuuc.so, libicui18n.so, libicudata.so
    ];
  };
}
