# Home Manager entry point for the MacBook: identity + shared config +
# mac-only concerns.
{ ... }:

{
  imports = [
    ./common
    ./common/goroot.nix # not in common/default.nix — wsl-lite skips it
    ./mac/ghostty.nix
    ./mac/nix.nix
    ./mac/toolchains.nix
    ./mac/dotfiles.nix
    ./mac/manual.nix
    ./mac/auto-commit.nix
  ];

  home.username = "marcussanchez";
  home.homeDirectory = "/Users/marcussanchez";
}
