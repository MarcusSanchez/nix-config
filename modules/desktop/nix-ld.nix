# The desktop's ADDITIONS to nix-ld (enabled in modules/nixos/nix-ld.nix).
# Extra libraries listed here MERGE with the module's base set (list
# options concatenate) and should stay desktop-wide concerns — anything a
# specific project needs goes in that project's devenv.nix.
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
{ pkgs, ... }:

{
  programs.nix-ld.libraries = with pkgs; [
    # JetBrains IDEs dlopen libsecret for the native keychain; without
    # it they fall back to "in memory password storage" with a warning
    libsecret

    # AWT / windowing
    xorg.libX11
    xorg.libXext
    xorg.libXi
    xorg.libXrender
    xorg.libXtst
    xorg.libXrandr
    xorg.libXcursor
    xorg.libXcomposite
    xorg.libXdamage
    xorg.libXfixes
    xorg.libxcb
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
