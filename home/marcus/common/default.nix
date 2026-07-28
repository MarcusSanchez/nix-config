# Shared Home Manager config for every machine. Per-host entry points
# (../wsl.nix, ../mac.nix) set identity and the platform-only imports
# from ../wsl/ and ../mac/.
#
# One file in this directory is deliberately absent from the list below:
# ./goroot.nix is shared by the two IDE machines but not by wsl-lite, so
# those two entry points import it themselves.
{ ... }:

{
  imports = [
    ./packages.nix
    ./shell.nix
    ./neovim.nix
    ./git.nix
    ./catppuccin.nix
    ./comma.nix
  ];

  # Do not change after initial install.
  home.stateVersion = "25.05";
}
