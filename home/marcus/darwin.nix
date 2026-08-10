# Home Manager entry point for the MacBook: identity + shared config +
# mac-only concerns.
{ ... }:

{
  imports = [
    ./common
    ./darwin/ghostty.nix
    ./darwin/nix.nix
    # UI-managed-config links + drift auto-commit. Mac note: the WSL
    # boxes reach the same files through win-sync copies instead of
    # symlinks (wsl/dotfiles.nix) — Windows can't traverse Linux
    # symlinks at all.
    ./common/dotfiles-links.nix
    ./darwin/hammerspoon.nix
  ];

  home = {
    username = "marcussanchez";
    homeDirectory = "/Users/marcussanchez";
    # Do not change after initial install.
    stateVersion = "25.05";
  };
}
