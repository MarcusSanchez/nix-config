# swaylock is the fallback locker (DMS's is primary); it authenticates
# via PAM, and without this entry unlocking fails. Pairs with
# programs.swaylock in home/marcus/desktop/niri.nix.
{ ... }:

{
  security.pam.services.swaylock = { };
}
