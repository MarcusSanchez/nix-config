# Shell variety for the desk: noctalia (the 4.x quickshell shell — the
# 5.x rewrite is ./noctalia5.nix, archived unimported until it
# matures) installed ALONGSIDE DMS, selected per login at the
# greeter's session menu — the "niri (noctalia)" entry
# (modules/nixos/niri.nix) sets NIRI_SHELL, the spawn line in
# niri.config.kdl reads it, and the binds route through shell-ipc
# (./niri.nix) to whichever shell is running. DMS stays the default
# session. The package bundles its own pinned quickshell (noctalia-qs)
# — nothing extra to install.
#
# Hostname-gated, same rule as the other per-machine ON/OFF facts: the
# list lives at the option it gates. Kept deliberately STOCK — no bar
# or widget customization; only wallpaper is touched, and by turning
# it OFF (machine-local ~/.config/noctalia/settings.json): the
# compositor owns all three backgrounds instead (stars stills via
# swaybg + the animated middle via mpvpaper, spawned in
# niri.host.naut-dt.kdl), so the desk looks the same in every shell.
# Colors come from its builtin Catppuccin scheme, set in the same
# machine-local file.
{
  pkgs,
  lib,
  osConfig,
  ...
}:

{
  home.packages = lib.mkIf (builtins.elem osConfig.networking.hostName [ "naut-dt" ]) [
    pkgs.noctalia-shell
  ];
}
