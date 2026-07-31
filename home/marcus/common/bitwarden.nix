# rbw: Bitwarden from the terminal, without the web vault.
#
# Holds the personal age key — the ONE identity: machines decrypt with a
# root-owned copy at /var/lib/sops-nix/key.txt, and the same key at
# ~/.config/sops/age/keys.txt is what edits secrets/secrets.yaml (see
# modules/common/secrets.nix). This vault entry is the master backup.
# Day to day this is just a password lookup that doesn't need a browser.
#
# Unlike the credentials in secrets.nix, this one deliberately isn't
# automated: it's unlocked by the master password marcus actually
# remembers, which is what makes it the root of the whole chain.
#
# This is also what lets a new machine enroll itself with no second machine
# on hand. Enrolling runs `sops updatekeys`, which has to decrypt — and a box
# that isn't a recipient yet can't. The personal key breaks that cycle, and
# rbw is how it gets there over a terminal alone (no browser, which is the
# nixos-lite case). The first switch installs rbw already configured even
# though secrets don't decrypt yet — that's the harmless `setupSecrets
# failed` — so the whole loop closes on the one machine in front of you.
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
