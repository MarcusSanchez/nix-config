# The two shims that make FOREIGN (non-nix) binaries run — both here
# for the JetBrains/Toolbox story, though they serve any outside binary.
#
# 1) nix-ld ADDITIONS (enabled in modules/nixos/nix-ld.nix; list options
# CONCATENATE, so these merge with the base set). Desktop-wide concerns
# only — anything a specific project needs goes in that project's
# devenv.nix.
#
# The bulk below is what JetBrains IDEs need — do not trim it. Their
# bundled JBR dlopens the whole X11/GTK/NSS stack, and the base set
# (zlib, libstdc++, systemd, curl...) covers none of it — an IDE launched
# outside Toolbox dies with "Failed to initialize the window toolkit:
# libX11.so.6: cannot open shared object file". Toolbox's own launcher
# masks this by injecting a library path, which is why IDEs start from
# Toolbox but not from a launcher/desktop entry. Derived empirically:
#   find <ide-tree> -name '*.so' | while read f; do
#     ldd "$f" 2>/dev/null | grep 'not found'; done | awk '{print $1}' | sort -u
# It covers AWT (windowing), JCEF (the embedded browser used by Markdown
# preview and the login flow), fonts, audio, printing and the a11y bus.
#
# 2) envfs: a FUSE filesystem at /bin and /usr/bin resolving any
# interpreter against the caller's PATH, so scripts with hardcoded
# shebangs run on NixOS. Toolbox generates its CLI launchers
# (~/.local/share/JetBrains/Toolbox/scripts/*) with `#!/bin/bash`, which
# NixOS doesn't have — only /bin/sh — and it rewrites them on every IDE
# update, so patching the shebang by hand never sticks.
#
# Desktop flavor only, deliberately: the WSL boxes rebuild themselves
# unattended from pushed main every week, and a FUSE mount over /bin is
# not something to hand them without testing on a machine someone is
# looking at. Promote envfs to modules/nixos if the WSL side ever wants it.
{ pkgs, ... }:


{
  services.envfs.enable = true;

  programs.nix-ld.libraries = with pkgs; [
    # JetBrains IDEs dlopen libsecret for the native keychain; without
    # it they fall back to "in memory password storage" with a warning
    libsecret

    # AWT / windowing
    libx11
    libxext
    libxi
    libxrender
    libxtst
    libxrandr
    libxcursor
    libxcomposite
    libxdamage
    libxfixes
    libxcb
    libxkbcommon
    wayland

    # GTK stack (file dialogs, JCEF chrome)
    glib
    gtk3
    cairo
    pango
    atk
    at-spi2-atk
    at-spi2-core
    gdk-pixbuf
    expat
    dbus

    # JCEF (embedded Chromium)
    nss
    nspr
    libgbm
    libdrm

    # rendering, fonts, sound, printing
    libGL
    freetype
    fontconfig
    alsa-lib
    cups
  ];
}
