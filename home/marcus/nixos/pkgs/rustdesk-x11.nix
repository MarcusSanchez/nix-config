# RustDesk forced through xwayland: keyboard forwarding to the remote
# fails under native Wayland — legacy mode's rdev grab has no backend
# ("Failed to send grab command, no sender" in the client log) and map
# mode drops keys too. The Flutter shell is GTK-based, so GDK_BACKEND
# is honored; GDK_SCALE=2 sizes the raw-pixel xwayland window for a
# high-DPI monitor (integer-only, so slightly larger than native — the
# comfortable direction), and XCURSOR_SIZE=12 halves the cursor base
# that GDK_SCALE doubles, landing back at the standard 24. The .desktop
# Exec resolves `rustdesk` via PATH, so wrapping bin/ covers both
# launch paths.
{
  symlinkJoin,
  makeWrapper,
  rustdesk,
}:

symlinkJoin {
  name = "rustdesk-x11";
  paths = [ rustdesk ];
  nativeBuildInputs = [ makeWrapper ];
  postBuild = ''
    rm $out/bin/rustdesk
    makeWrapper ${rustdesk}/bin/rustdesk $out/bin/rustdesk \
      --set GDK_BACKEND x11 \
      --set GDK_SCALE 2 \
      --set XCURSOR_SIZE 12
  '';
}
