# Zed runs on the Windows side; its config under %APPDATA%\Zed and the
# SHARED copies in ../common/zed/ (one settings.json + one keymap.json
# for both machines — cmd-* bindings are inert-ish super-key combos on
# Windows, ctrl-* extras are harmless on the mac) are two-way synced by
# the win-sync engine — see win-sync.nix for the contract. The mac
# symlinks the same files (mac/zed.nix).
{
  config,
  lib,
  pkgs,
  ...
}:

let
  winSync = import ./win-sync.nix {
    inherit pkgs;
    repoDir = "${config.home.homeDirectory}/nix-config";
  };
in
{
  home.activation.zedConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] (winSync {
    name = "zed";
    winDir = "/mnt/c/Users/${config.windows.username}/AppData/Roaming/Zed";
    repoSubdir = "home/marcus/common/dotfiles";
    files = {
      "settings.json" = "zed.settings.json";
      "keymap.json" = "zed.keymap.json";
    };
    witness = ../common/dotfiles;
  });
}
