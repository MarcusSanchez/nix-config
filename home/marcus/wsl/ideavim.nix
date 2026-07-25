# JetBrains IdeaVim: %USERPROFILE%\.ideavimrc two-way synced with
# ./ideavim/ by the win-sync engine — see win-sync.nix for the contract.
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
    repoSubdir = "home/marcus/wsl/ideavim";
    files = [ ".ideavimrc" ];
    witness = ./ideavim;
  });
}
