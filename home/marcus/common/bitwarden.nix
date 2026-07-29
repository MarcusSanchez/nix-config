# rbw: Bitwarden from the terminal, without the web vault.
#
# `rbw get "sops age key — nix-config (all machines)"` is the recovery path
# when no machine that already has the age key is alive — the one case
# secrets.nix can't bootstrap itself out of (see its header). Day to day
# it's just a password lookup that doesn't need a browser.
#
# Unlike the credentials in secrets.nix, this one deliberately isn't
# automated: it's unlocked by the master password marcus actually
# remembers, which is what makes it the root of the whole chain.
#
# Note the bootstrap order — this package arrives WITH the rebuild, and a
# machine missing the age key can't complete one. So on a fresh box rbw
# comes from `nix shell nixpkgs#rbw` instead; see the README's Secrets
# section. Installing it here is for every day after that.
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
