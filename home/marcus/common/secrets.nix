# User-side wiring for the credentials that modules/common/secrets.nix
# decrypts. The sops module itself is the SYSTEM one, not the home-manager
# one — that choice matters:
#
#   * the HM module registers its activation entry as a bare string, which
#     home-manager coerces to entryAnywhere — no ordering guarantees at
#     all (sops-nix#581, open). Consumers routinely run before the secrets
#     exist. The system module decrypts before any user activation.
#
# So this file holds only the parts that are genuinely user-scoped.
{ pkgs, ... }:

{
  # ── rbw: Bitwarden from the terminal ─────────────────────────────────
  # Holds the personal age key — the ONE identity: machines decrypt with a
  # root-owned copy at /var/lib/sops-nix/key.txt, and the same key at
  # ~/.config/sops/age/keys.txt is what edits secrets/secrets.yaml (see
  # modules/common/secrets.nix). This vault entry is the master backup.
  # Day to day this is just a password lookup that doesn't need a browser.
  #
  # Unlike the credentials below, this one deliberately isn't automated:
  # it's unlocked by the master password marcus actually remembers, which
  # is what makes it the root of the whole chain. It's also what lets a
  # new machine enroll itself alone: the first switch installs rbw already
  # configured even though secrets don't decrypt yet (the harmless
  # setupSecrets failure), so `age:place` closes the loop on the one
  # machine in front of you.
  #
  #   rbw login    # once per machine (age:place runs it for you)
  #   rbw unlock   # once per agent lifetime (lock_timeout below)
  #   rbw get <name>
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

  # flyctl reads FLY_API_TOKEN ahead of its config file, which leaves
  # ~/.fly/config.yml entirely to flyctl — free to persist wireguard peer
  # state and refresh its own tokens without us clobbering them. Installing
  # the token isn't an option: `fly auth login -t <token>` lists the flag in
  # --help but ignores it and opens a browser (tested 2026-07-29).
  #
  # Guarded so a machine whose secrets aren't decrypted yet starts without
  # the variable rather than erroring. Bare token since 2026-07-31 — the
  # old fly_config held a whole config.yml and needed sed.
  # croc takes its code phrase from CROC_SECRET, so with the same value
  # exported everywhere, bare `croc send <file>` and bare `croc` pair up
  # across machines with no code to read out. $(cat) drops the trailing
  # newline, which would otherwise make the phrases not match.
  home.sessionVariablesExtra = ''
    if [ -r /run/secrets/fly_token ]; then
      export FLY_API_TOKEN="$(cat /run/secrets/fly_token)"
    fi
    if [ -r /run/secrets/croc_secret ]; then
      export CROC_SECRET="$(cat /run/secrets/croc_secret)"
    fi
  '';

  # atuin's per-machine login is deliberately NOT here: HM activation
  # can't do it reliably on either platform (darwin runs HM's text before
  # sops decrypts; NixOS skips the unchanged HM oneshot on a no-change
  # switch, i.e. every re-arm after secrets:drop). It lives in
  # modules/common/secrets.nix as system-activation text instead, which
  # both platforms re-run on every switch.
}
