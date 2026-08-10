# GUI apps — the Linux render of the mac's homebrew casks (minus stremio,
# minus raycast, which has no Linux build; DMS's spotlight covers that
# slot).
{ inputs, pkgs, ... }:

{
  home.packages = with pkgs; [
    google-chrome
    zed-editor
    # IDE manager only; the JetBrains IDEs themselves are installed and
    # updated inside Toolbox (into ~/.local — nix-ld makes them run)
    jetbrains-toolbox
    # firewall port 53317 is opened in modules/nixos/networking.nix
    localsend
    # forced native-Wayland — the why lives in the wrapper's header
    (pkgs.callPackage ./pkgs/spotify-wayland.nix { })
    # zen isn't in nixpkgs; the flake input repackages official binaries
    inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default

    # (No Wootility app: the web Wootility in Chrome covers it — WebHID
    # plus the udev rules from modules/nixos/system.nix. zen can't;
    # firefox-based, no WebHID.)

    # GNOME Files — the GUI file explorer (yazi remains the terminal
    # one); gvfs in modules/nixos/system.nix backs its trash,
    # USB and phone mounting
    nautilus

    # media center (torrent-streaming frontend). stremio-linux-shell is
    # the current packaging — plain `stremio` was removed from nixpkgs
    # over its outdated qt5 webengine.
    pkgs.stremio-linux-shell

    # remote desktop (TeamViewer-style, self-hostable) — used OUTBOUND,
    # to control other machines; nothing here runs at startup, so this
    # box is only controllable while the app is deliberately open.
    # Should receiving ever matter: capture goes through the GNOME
    # portal + PipeWire (already in place for screen sharing), input
    # through /dev/uinput (group membership already exists for xremap).
    # `rustdesk`, not `rustdesk-flutter`: same upstream app, newer
    # release (the unfree mark is upstream's relicense, and unfree is
    # allowed here anyway). Forced through xwayland — the why lives in
    # the wrapper's header.
    (pkgs.callPackage ./pkgs/rustdesk-x11.nix { })
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

  # the zed-editor package names its CLI `zeditor`; muscle memory says zed
  home.shellAliases.zed = "zeditor";
}
