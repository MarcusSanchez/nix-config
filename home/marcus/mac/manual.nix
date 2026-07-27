# Home Manager's own documentation, mac only.
#
# manual.manpages (default true) builds `man home-configuration.nix` through
# nixpkgs' nixosOptionsDoc, whose options.json embeds the nixpkgs source path
# as a context-stripped string. Nix 2.34 warns about that on every eval:
#
#   warning: Using 'builtins.derivation' to create a derivation named
#   'options.json' that references the store path '/nix/store/…-source'
#   without a proper context.
#
# An upstream bug, and cosmetic today — but the reference never gets
# registered, so a GC that collects that nixpkgs source breaks the next
# rebuild of the manpage. Verified 2026-07-27 that this is the only trigger:
# nix-darwin's documentation.man/doc.enable and Determinate's lazy-trees are
# both innocent. Off here, left ON in home/marcus/wsl — that machine keeps
# the local option reference and just wears the warning.
{ ... }:

{
  manual.manpages.enable = false;
}
