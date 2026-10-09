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
  # as a context-stripped string. Nix warns about that on every eval:
  #
  #   warning: Using 'builtins.derivation' to create a derivation named
  #   'options.json' that references the store path '/nix/store/…-source'
  #   without a proper context.
  #
  # An upstream bug, and cosmetic on its own — but the reference never gets
  # registered, so a GC that collects that nixpkgs source breaks the next
  # rebuild of the manpage. This is the only trigger:
  # nix-darwin's documentation.man/doc.enable and Determinate's lazy-trees are
  # both innocent.
  #
  # Mac only because the warning is mac only: the trigger is Determinate's
  # Nix, not the option — a NixOS eval does not emit it. The NixOS hosts
  # keep their manpages; if a rebuild there ever dies on options.json, this
  # is the fix to copy.
  manual.manpages.enable = false;
}
