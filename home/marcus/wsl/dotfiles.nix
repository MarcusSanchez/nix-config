# The Windows-side apps' configs, two-way synced with the shared copies
# in ../common/dotfiles/ by the win-sync engine (see win-sync.nix for the
# contract). Zed reads %APPDATA%\Zed, IdeaVim reads %USERPROFILE% — same
# engine, one instance each because the state dir, chore scope and
# Windows directory differ per app. The mac reaches these same repo files
# through symlinks instead (mac/dotfiles.nix). windows.username — the
# Windows account owning /mnt/c/Users/<name> — is declared here because
# this is its only consumer; the value is set per host in wsl.nix.
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
  winHome = "/mnt/c/Users/${config.windows.username}";
  repoSubdir = "home/marcus/common/dotfiles";
  witness = ../common/dotfiles;
in
{
  options.windows.username = lib.mkOption {
    type = lib.types.str;
    description = "Windows username owning /mnt/c/Users/<name>.";
  };

  config = {
    # one settings.json + one keymap.json for both machines — cmd-*
    # bindings are inert-ish super-key combos on Windows, ctrl-* extras
    # are harmless on the mac
    home.activation.zedConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] (winSync {
      name = "zed";
      winDir = "${winHome}/AppData/Roaming/Zed";
      files = {
        "settings.json" = "zed.settings.json";
        "keymap.json" = "zed.keymap.json";
      };
      inherit repoSubdir witness;
    });

    home.activation.ideavimConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] (winSync {
      name = "ideavim";
      winDir = winHome;
      files = {
        ".ideavimrc" = ".ideavimrc";
      };
      inherit repoSubdir witness;
    });
  };
}
