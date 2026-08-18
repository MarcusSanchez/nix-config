# ARCHIVED, NOT IMPORTED — noctalia 4.x, tried as shell variety and
# retired with the experiment (the 5.x rewrite is ./noctalia5.nix,
# same status). Everything else still speaks it, so re-enabling is:
# import this file from nixos.nix and put the hostname back in the
# sessionPackages gate in modules/nixos/niri.nix — the "niri
# (noctalia)" session entry sets NIRI_SHELL, the spawn line in
# niri.config.kdl reads it, and the binds route through shell-ipc
# (./niri.nix) to whichever shell answers. The package bundles its own
# pinned quickshell (noctalia-qs) — nothing extra to install.
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
