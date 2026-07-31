# Home Manager entry point for the WSL machine: identity + shared config +
# WSL-only concerns.
{ ... }:

{
  imports = [
    ./common
    ./wsl/windows.nix
    ./wsl/nix.nix
    ./wsl/dotfiles.nix
  ];

  home.username = "marcus";
  home.homeDirectory = "/home/marcus";
  windows.username = "marcus";
}
