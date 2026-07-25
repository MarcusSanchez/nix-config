# JetBrains IdeaVim: %USERPROFILE%\.ideavimrc two-way synced with the
# SHARED copy in ../common/ideavim/ by the win-sync engine (see
# win-sync.nix for the contract). The mac symlinks the same file
# (mac/ideavim.nix) — this one file serves both machines.
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
  home.activation.ideavimConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] (winSync {
    name = "ideavim";
    winDir = "/mnt/c/Users/${config.windows.username}";
    repoSubdir = "home/marcus/common/ideavim";
    files = [ ".ideavimrc" ];
    witness = ../common/ideavim;
  });
}
