# Home Manager entry point for the MacBook: identity + shared config +
# mac-only concerns.
{ ... }:

{
  imports = [
    ./common
    ./mac/ghostty.nix
    ./mac/nix.nix
    ./mac/dotfiles.nix
  ];

  home = {
    username = "marcussanchez";
    homeDirectory = "/Users/marcussanchez";
    # Do not change after initial install.
    stateVersion = "25.05";
  };
}
