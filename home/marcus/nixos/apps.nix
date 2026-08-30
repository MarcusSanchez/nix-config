# GUI apps — the Linux render of the mac's homebrew casks (minus stremio,
# minus raycast, which has no Linux build; DMS's spotlight covers that
# slot).
{
  inputs,
  lib,
  pkgs,
  ...
}:

{
  home.packages = with pkgs; [
    google-chrome

    # config rides the dotfiles links (common/dotfiles.nix); the mac's
    # app is a brew cask, so the package here is desktop-only by nature
    ghostty

    # IDE manager only; the JetBrains IDEs themselves are installed and
    # updated inside Toolbox (into ~/.local — nix-ld makes them run)
    jetbrains-toolbox

    # firewall port 53317 is opened in modules/nixos/networking.nix
    localsend

    # GNOME Files — the GUI file explorer (yazi remains the terminal
    # one); gvfs in modules/nixos/system.nix backs its trash,
    # USB and phone mounting
    nautilus

    # remote desktop (TeamViewer-style, self-hostable) — used OUTBOUND,
    # to control other machines; nothing here runs at startup, and
    # RECEIVING cannot work on this desktop: niri's screencast offers
    # dmabuf-only buffers with the modifier marked MANDATORY
    # (pw_utils.rs, unchanged on niri main), while the capture pipeline
    # here (pipewiresrc ! videoconvert) speaks only mappable system
    # memory — the format intersection is empty, "no more input
    # formats" on every connect. Input was never the problem
    # (/dev/uinput worked). Graphical access INTO this box needs a
    # KMS-capture tool (sunshine-class) instead.
    # `rustdesk`, not `rustdesk-flutter`: same upstream app, newer
    # release (the unfree mark is upstream's relicense, and unfree is
    # allowed here anyway).
    #
    # Forced through xwayland: keyboard forwarding to the remote fails
    # under native Wayland — legacy mode's rdev grab has no backend
    # ("Failed to send grab command, no sender" in the client log) and
    # map mode drops keys too. The Flutter shell is GTK-based, so
    # GDK_BACKEND is honored; GDK_SCALE=2 sizes the raw-pixel xwayland
    # window for a high-DPI monitor (integer-only, so slightly larger
    # than native — the comfortable direction). The .desktop Exec
    # resolves `rustdesk` via PATH, so wrapping bin/ covers both launch
    # paths.
    (symlinkJoin {
      name = "rustdesk-x11";
      paths = [ rustdesk ];
      nativeBuildInputs = [ makeWrapper ];
      postBuild = ''
        rm $out/bin/rustdesk
        makeWrapper ${rustdesk}/bin/rustdesk $out/bin/rustdesk \
          --set GDK_BACKEND x11 \
          --set GDK_SCALE 2
      '';
    })

    # forced native-Wayland instead of xwayland-satellite, where its
    # CEF drew an ugly fallback frame — and no decoration feature flag:
    # CEF's own CSD is a retro blue titlebar (default-ON in this CEF,
    # hence the explicit disable), and a tiled window needs none. The
    # .desktop Exec resolves `spotify` via PATH, so wrapping bin/
    # covers both launch paths.
    (symlinkJoin {
      name = "spotify-wayland";
      paths = [ spotify ];
      nativeBuildInputs = [ makeWrapper ];
      postBuild = ''
        rm $out/bin/spotify
        makeWrapper ${spotify}/bin/spotify $out/bin/spotify \
          --add-flags "--ozone-platform=wayland --disable-features=WaylandWindowDecorations"
      '';
    })

    # media center (torrent-streaming frontend). stremio-linux-shell is
    # the current packaging — plain `stremio` was removed from nixpkgs
    # over its outdated qt5 webengine.
    stremio-linux-shell

    zed-editor

    # zen isn't in nixpkgs; the flake input repackages official binaries
    inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default

    # (No Wootility app: the web Wootility in Chrome covers it — WebHID
    # plus the udev rules from modules/nixos/system.nix. zen can't;
    # firefox-based, no WebHID.)
  ];

  # Launcher hygiene: terminal apps and system plumbing ship .desktop
  # entries that clutter the DMS spotlight. A user-level entry with the
  # SAME id and NoDisplay shadows the package's copy (XDG precedence) —
  # the binaries stay on PATH, only the launcher rows disappear. Delete
  # a line to bring one back; DMS reindexes on shell restart.
  xdg.desktopEntries =
    let
      hide = name: {
        inherit name;
        noDisplay = true;
      };
    in
    {
      btop = hide "btop";
      htop = hide "htop";
      yazi = hide "Yazi";
      nvim = hide "Neovim wrapper";
      satty = hide "Satty";
      cups = hide "Manage Printing";
      nixos-manual = hide "NixOS Manual";
      "org.quickshell" = hide "Quickshell";
    };

  # zen as the DEFAULT browser, declaratively: HM renders the
  # mimeapps.list that xdg-open and the portals consult, so links from
  # any app land in zen on every desktop machine — instead of the
  # mutable file zen's own "make default" prompt writes, which dies
  # with each install. The flake package ships beta-channel naming:
  # zen-beta.desktop / the zen-beta binary.
  xdg.mimeApps = {
    enable = true;
    defaultApplications = lib.genAttrs [
      "text/html"
      "application/xhtml+xml"
      "x-scheme-handler/http"
      "x-scheme-handler/https"
      "x-scheme-handler/about"
      "x-scheme-handler/unknown"
    ] (_: "zen-beta.desktop");
  };

  # the zed-editor package names its CLI `zeditor`; muscle memory says zed
  home.shellAliases.zed = "zeditor";
}
