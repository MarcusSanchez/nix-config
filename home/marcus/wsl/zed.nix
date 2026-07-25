# Zed runs on the Windows side; its config under %APPDATA%\Zed and the
# vendored copies in ./zed/ are two-way synced by the win-sync engine —
# see win-sync.nix for the contract.
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
    repoSubdir = "home/marcus/wsl/zed";
    files = [
      "settings.json"
      "keymap.json"
    ];
    witness = ./zed;
  });
}
