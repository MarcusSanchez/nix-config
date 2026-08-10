# Spotify forced native-Wayland instead of xwayland-satellite, where
# its CEF drew an ugly fallback frame — and no decoration feature flag:
# CEF's own CSD is a retro blue titlebar (default-ON in this CEF, hence
# the explicit disable), and a tiled window needs none. The .desktop
# Exec resolves `spotify` via PATH, so wrapping bin/ covers both launch
# paths.
{
  symlinkJoin,
  makeWrapper,
  spotify,
}:

symlinkJoin {
  name = "spotify-wayland";
  paths = [ spotify ];
  nativeBuildInputs = [ makeWrapper ];
  postBuild = ''
    rm $out/bin/spotify
    makeWrapper ${spotify}/bin/spotify $out/bin/spotify \
      --add-flags "--ozone-platform=wayland --disable-features=WaylandWindowDecorations"
  '';
}
