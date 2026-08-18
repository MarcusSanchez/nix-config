# ARCHIVED, NOT IMPORTED — the 5.x rewrite, tried and shelved as too
# immature (beta): its bar took heavy hand-configuration to approach
# the DMS layout and still missed. Kept in-tree, off the import path,
# for the day 5.x stabilizes: re-import from nixos.nix in place of
# ./noctalia.nix, and shell-ipc's 5.x branch (./niri.nix) plus the
# session entry (modules/nixos/niri.nix) already speak it — the spawn
# line in niri.config.kdl prefers 4.x, so also swap the gate here vs
# noctalia.nix. Its machine-local state lives in
# ~/.local/state/noctalia/ (validate edits with `noctalia config
# validate`).
{
  pkgs,
  lib,
  osConfig,
  ...
}:

{
  home.packages = lib.mkIf (builtins.elem osConfig.networking.hostName [ ]) [
    pkgs.noctalia
  ];
}
