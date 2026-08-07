# Home Manager entry point for the MacBook: identity + shared config +
# mac-only concerns.
{ ... }:

{
  imports = [
    ./common
    ./darwin/ghostty.nix
    ./darwin/nix.nix
    ./darwin/dotfiles.nix
    ./darwin/hammerspoon.nix
  ];

  home = {
    username = "marcussanchez";
    homeDirectory = "/Users/marcussanchez";
    # Do not change after initial install.
    stateVersion = "25.05";
  };
}
