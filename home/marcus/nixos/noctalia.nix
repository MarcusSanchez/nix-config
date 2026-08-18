# Shell variety for the desk: noctalia (the 5.x rewrite) installed
# ALONGSIDE DMS, selected per login at the greeter's session menu —
# the extra "niri • noctalia" session entry (modules/nixos/niri.nix)
# sets NIRI_SHELL=noctalia, the spawn line in niri.config.kdl reads
# it, and the binds route through shell-ipc (./niri.nix) to whichever
# shell is running. DMS stays the default session.
#
# Hostname-gated, same rule as the other per-machine ON/OFF facts: the
# list lives at the option it gates. Its settings are deliberately
# machine-local (~/.local/state/noctalia/settings.toml, validated with
# `noctalia config validate`) — noctalia rewrites widget geometry in
# place, so a repo link would be endless drift noise; the bar layout
# mirrors dms.settings.json's by hand instead.
{
  pkgs,
  lib,
  osConfig,
  ...
}:

{
  home.packages = lib.mkIf (builtins.elem osConfig.networking.hostName [ "naut-dt" ]) [
    pkgs.noctalia
  ];
}
