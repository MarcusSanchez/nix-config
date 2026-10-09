# Nix daemon settings — or rather, the deliberate absence of them.
#
# Both Macs run Determinate Nix: determinate-nixd owns the daemon,
# /etc/nix/nix.conf, and flakes-on defaults. nix-darwin must not fight it,
# hence nix.enable = false (nix-darwin refuses to build otherwise). Daemon
# tweaks, if ever needed, go in /etc/nix/nix.custom.conf.
#
# What lives out there (unmanaged by this repo — restate it by hand
# after a reinstall):
#  - extra-trusted-users = the Mac's account (marcussanchez on the Air,
#    marcus on the mini). devenv sets the restricted `system` setting
#    on every shell eval, which the daemon ignores for untrusted
#    clients — the whole devenv shell then fails to build.
#    Determinate's default is trusted-users = root only.
#  - the claude-code and devenv cachix substituters and their keys,
#    hand-written in (the same lines the nixos/wsl nix.nix files set
#    declaratively; the README has the printf).
#  - keep-derivations = false. Determinate's default (true) keeps every
#    live output's .drv and source inputs alive across GC, pinning
#    source tarballs the store never serves again.
#
# Consequences:
#  - nix.settings / nix.gc / nix.optimise are unavailable here; user-level
#    GC lives in home/marcus/darwin/nix.nix instead.
#  - No system.autoUpgrade on darwin anyway — bump inputs with
#    `nix flake update` and rebuild.
{ ... }:

{
  nix.enable = false;
}
