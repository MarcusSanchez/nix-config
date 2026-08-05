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
    # firewall port 53317 is opened in modules/nixos/desktop.nix
    localsend
    # native Wayland instead of xwayland-satellite, where its CEF drew
    # an ugly fallback frame — and no decoration feature flag: CEF's
    # own CSD is a retro blue titlebar (default-ON in this CEF, hence
    # the explicit disable), and a tiled window needs none.
    # The .desktop Exec resolves `spotify` via PATH, so wrapping bin/
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
    # zen isn't in nixpkgs; the flake input repackages official binaries
    inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];
}
