# Nix daemon settings — or rather, the deliberate absence of them.
#
# This machine runs Determinate Nix: determinate-nixd owns the daemon,
# /etc/nix/nix.conf, and flakes-on defaults. nix-darwin must not fight it,
# hence nix.enable = false (nix-darwin refuses to build otherwise). Daemon
# tweaks, if ever needed, go in /etc/nix/nix.custom.conf.
#
# What actually lives out there today (unmanaged by this repo — restate it
# by hand after a reinstall):
#  - extra-trusted-users = marcussanchez. devenv sets the
#    restricted `system` setting on every shell eval, which the daemon
#    ignores for untrusted clients — the whole devenv shell then fails to
#    build. Determinate's default is trusted-users = root only.
#  - the cachix substituters the devenv/cachix installers appended.
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
