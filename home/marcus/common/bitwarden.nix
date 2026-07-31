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
      # Per platform. WSL: curses, drawn on the client's tty (rbw forwards
      # it). The mac got curses too originally; a Ctrl-C mid-prompt orphans
      # the pinentry, which then spins at 100% CPU retrying an EIO read
      # (2026-07-29 — survivable in normal flows, marcus was right, but the
      # landmine plus macOS tty semantics made a GUI prompt the safe call).
      #
      # On the mac that GUI is now Touch ID: pinentry-touchid (brew, see
      # homebrew.nix) behind a protocol shim. Stock pinentry-touchid gates
      # its Touch ID path on two things only gpg-agent sends — a nonempty
      # SETKEYINFO and OPTION allow-external-password-cache (main.go; its
      # issue #17) — so with rbw it would fall back to a pinentry-mac
      # dialog every time. The shim speaks those two lines on rbw's behalf,
      # then bridges the rest verbatim. First unlock: keychain miss, one
      # pinentry-mac dialog, touchid stores the password under the injected
      # key id. Every unlock after: the Touch ID sheet.
      #
      # If the brew formula isn't installed yet (fresh mac, pre-switch
      # ordering), the shim execs pinentry-mac directly — degraded to the
      # old dialog, never broken.
      pinentry =
        if pkgs.stdenv.isDarwin then
          pkgs.writeShellScriptBin "pinentry-rbw-touchid" ''
            TOUCHID=/opt/homebrew/bin/pinentry-touchid
            # touchid's own first-run fallback spawns pinentry-mac from PATH
            export PATH=${pkgs.pinentry_mac}/bin:/opt/homebrew/bin:$PATH
            [ -x "$TOUCHID" ] || exec ${pkgs.pinentry_mac}/bin/pinentry-mac "$@"
            coproc TP {
              exec "$TOUCHID"
            }
            # coproc fds are invisible to subshells: dup onto plain fds, then close the
            # originals via eval — the {var}<&- form can't take array subscripts, so
            # without eval the parent silently keeps a handle on touchid's stdin and
            # nothing ever sees EOF
            exec 5<&"''${TP[0]}" 6>&"''${TP[1]}"
            eval "exec ''${TP[0]}<&- ''${TP[1]}>&-"
            IFS= read -r greeting <&5
            printf '%s\n' "$greeting"
            printf 'OPTION allow-external-password-cache\n' >&6
            IFS= read -r _ <&5
            printf 'SETKEYINFO n/rbw-master\n' >&6
            IFS= read -r _ <&5
            # touchid->client in the background (fd6 closed there — an inherited copy
            # would keep touchid's stdin alive); client->touchid holds the foreground
            # so a client hangup closes fd6 and takes touchid down — no orphaned
            # pinentry after a Ctrl-C
            cat <&5 6>&- &
            BG=$!
            cat >&6 5<&-
            exec 6>&-
            wait "$BG"
          ''
        else
          pkgs.pinentry-curses;
      lock_timeout = 3600;
    };
  };
}
