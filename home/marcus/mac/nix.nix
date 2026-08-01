# User-level nix + Home Manager housekeeping on the mac. System-side nix
# management is off (Determinate Nix owns the daemon — see
# modules/darwin/nix.nix), so GC runs as the user (launchd agent); the
# daemon still deletes unreferenced store paths on its behalf.
{ ... }:

{
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 10d";
  };

  # HM's own manual stays off, mac only:
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
  # both innocent.
  #
  # Mac only because the warning is mac only: checked from WSL the same day —
  # neither a full toplevel eval nor `nix flake check` emits it there — so the
  # trigger is Determinate's Nix, not the option. The WSL hosts keep their
  # manpages. If a WSL rebuild ever does die on options.json, this file is the
  # fix to copy (GC runs daily there vs weekly here, so it would bite sooner).
  manual.manpages.enable = false;
}
