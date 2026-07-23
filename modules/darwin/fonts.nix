# Fonts, installed to /Library/Fonts/Nix Fonts. Replaces the manually
# downloaded copies in ~/Library/Fonts.
{ pkgs, ... }:

{
  fonts.packages = [ pkgs.nerd-fonts.jetbrains-mono ];
}
