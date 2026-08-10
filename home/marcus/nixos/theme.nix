# GTK icon/cursor theme NAMES, owned declaratively: Plasma wrote
# breeze-dark/breeze_cursors into settings.ini and dconf for
# cross-toolkit consistency, and the DE teardown orphaned them — GTK
# only scans the theme it's named, so every named icon rendered as a
# broken-image placeholder and the cursor stayed a themeless default.
# (Plasma's old files land in .hm-backup on first switch.)
#
# Adwaita, not Papirus, by PREFERENCE: with Adwaita named, apps fall
# through to their own hicolor icons (native look, like macOS);
# Papirus replaces them with its restyled set. Papirus itself works
# (ghostty's tab bar renders — the breakage once blamed on it was
# Plasma-leftover fallout); it stays off purely on looks. Flip
# catppuccin.gtk.icon.enable in common/shell.nix to re-try it.
{ config, pkgs, ... }:

{
  gtk = {
    enable = true;
    iconTheme = {
      name = "Adwaita";
      package = pkgs.adwaita-icon-theme;
    };
  };
  # libadwaita apps (ghostty) read gsettings/dconf, not settings.ini —
  # icon-theme follows whichever theme won gtk.iconTheme above
  dconf.settings."org/gnome/desktop/interface" = {
    icon-theme = config.gtk.iconTheme.name;
    cursor-theme = "Adwaita";
    cursor-size = 24;
  };

  # Cursor theme everywhere: HM covers GTK settings, ~/.icons and the
  # XCURSOR_* session vars; the niri config's cursor block covers the
  # compositor's own cursor and what it exports to spawned apps. The DE
  # teardown left NO cursor theme — apps fell back to one oversized
  # default with no hover/text/resize variants.
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
