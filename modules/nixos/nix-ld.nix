# nix-ld lets unpatched dynamically-linked binaries (Electron apps,
# npm-downloaded tools, Mason-installed LSPs, ...) run on NixOS.
{ pkgs, ... }:

{
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      stdenv.cc.cc
      zlib
      glib
      nspr
      nss
      dbus
      atk
      at-spi2-atk
      at-spi2-core
      cairo
      cups
      expat
      fontconfig
      freetype
      gdk-pixbuf
      gtk3
      libdrm
      mesa
      libgbm
      pango
      libxkbcommon
      alsa-lib
      libpulseaudio
      libnotify
      libx11
      libxcomposite
      libxcursor
      libxdamage
      libxext
      libxfixes
      libxi
      libxrandr
      libxrender
      libxtst
      libxscrnsaver
      libxcb
      libxshmfence
    ];
  };
}
