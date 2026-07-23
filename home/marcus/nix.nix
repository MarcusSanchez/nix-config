# User-level garbage collection (launchd agent). System-side nix management
# is off (Determinate Nix owns the daemon — see modules/darwin/nix.nix), so
# GC runs as the user; the daemon still deletes unreferenced store paths on
# its behalf.
{ ... }:

{
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 10d";
  };
}
