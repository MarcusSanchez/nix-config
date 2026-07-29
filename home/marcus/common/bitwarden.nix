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
      # Per platform, because rbw-agent is reached differently on each.
      # WSL is headless, so a graphical prompt just fails to draw — curses
      # there, invoked from the terminal the agent can still reach. On the
      # mac the agent is a detached daemon with no controlling terminal, so
      # pinentry-curses has no TTY it owns: it spins at 100% CPU forever
      # retrying a read that returns EIO (and `--timeout 0` means it never
      # gives up), one stuck process per terminal that triggered an unlock.
      # A native Cocoa dialog needs no TTY.
      pinentry = if pkgs.stdenv.isDarwin then pkgs.pinentry_mac else pkgs.pinentry-curses;
      lock_timeout = 3600;
    };
  };
}
