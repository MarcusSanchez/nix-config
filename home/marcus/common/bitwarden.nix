# rbw: Bitwarden from the terminal, without the web vault.
#
# Holds the personal age key, which is the identity for *editing*
# secrets/secrets.yaml — machines decrypt with their own SSH host keys and
# never need it (see modules/nixos/secrets.nix). Lose it and you can re-key
# from any machine that still decrypts; it is not a path to lockout.
# Day to day this is just a password lookup that doesn't need a browser.
#
# Unlike the credentials in secrets.nix, this one deliberately isn't
# automated: it's unlocked by the master password marcus actually
# remembers, which is what makes it the root of the whole chain.
#
# On a box that hasn't rebuilt yet this package doesn't exist — use
# `nix shell nixpkgs#rbw`, which needs nothing installed.
#
#   rbw login    # once per machine
#   rbw unlock   # once per agent lifetime (lock_timeout below)
#   rbw get <name>
{ pkgs, ... }:

{
  programs.rbw = {
    enable = true;
    settings = {
      email = "marcussanchez031@gmail.com";
      # pinentry-curses, not a GUI one: the WSL boxes are headless, and a
      # graphical prompt there just fails to draw
      pinentry = pkgs.pinentry-curses;
      lock_timeout = 3600;
    };
  };
}
