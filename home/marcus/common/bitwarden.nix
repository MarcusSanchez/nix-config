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
      # pinentry-curses on BOTH platforms — one prompt, drawn on the tty of
      # whatever terminal ran the rbw command (rbw forwards it to the
      # agent-spawned pinentry). marcus's call, 2026-07-31.
      #
      # The one mac landmine: Ctrl-C mid-prompt orphans the pinentry, which
      # then spins at 100% CPU retrying an EIO read (2026-07-29). Abort with
      # Ctrl-D instead; recovery is `pkill pinentry-curses`. (A Touch ID
      # route via pinentry-touchid was explored and works only behind a
      # protocol shim — it gates on gpg-agent-only commands, see its issue
      # #17 — dropped as not worth the machinery.)
      pinentry = pkgs.pinentry-curses;
      lock_timeout = 3600;
    };
  };
}
