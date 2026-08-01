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

  home.username = "marcussanchez";
  home.homeDirectory = "/Users/marcussanchez";
}
