# GTK icon/cursor theme NAMES, owned declaratively: GTK only scans the
# theme it's named, so an unset or orphaned name renders every named
# icon as a broken-image placeholder and leaves the cursor a themeless
# default.
#
# Adwaita, not Papirus, by PREFERENCE: with Adwaita named, apps fall
# through to their own hicolor icons (native look, like macOS);
# Papirus replaces them with its restyled set and stays off purely on
# looks. Flip catppuccin.gtk.icon.enable in common/shell.nix to re-try
# it.
{ pkgs, ... }:

{
  gtk = {
    enable = true;
    iconTheme = {
      name = "Adwaita";
      package = pkgs.adwaita-icon-theme;
    };
  };
  # libadwaita apps (ghostty) read gsettings/dconf, not settings.ini;
  # Home Manager writes icon-theme, cursor-theme and cursor-size there
  # from gtk.iconTheme and home.pointerCursor.gtk.

  # Cursor theme everywhere: HM covers GTK settings, ~/.icons and the
  # XCURSOR_* session vars; the niri config's cursor block covers the
  # compositor's own cursor and what it exports to spawned apps.
  # Without a named theme, apps fall back to one oversized default with
  # no hover/text/resize variants.
  home.pointerCursor = {
    enable = true;
    # plain Adwaita arrow — the catppuccin set's pointer reads as an
    # odd purple triangle
    package = pkgs.adwaita-icon-theme;
    name = "Adwaita";
    size = 24;
    gtk.enable = true;
    x11.enable = true;
  };
}
