# Nix daemon settings — or rather, the deliberate absence of them.
#
# This machine runs Determinate Nix: determinate-nixd owns the daemon,
# /etc/nix/nix.conf, and flakes-on defaults. nix-darwin must not fight it,
# hence nix.enable = false (nix-darwin refuses to build otherwise). Daemon
# tweaks, if ever needed, go in /etc/nix/nix.custom.conf.
#
# Consequences:
#  - nix.settings / nix.gc / nix.optimise are unavailable here; user-level
#    GC lives in home/marcus/nix.nix instead.
#  - No system.autoUpgrade on darwin anyway — bump inputs with
#    `nix flake update` and rebuild.
{ ... }:

{
  nix.enable = false;

  nixpkgs.config.allowUnfree = true;
}
