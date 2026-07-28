# Home Manager entry point for the WSL machine: identity + shared config +
# WSL-only concerns.
{ ... }:

{
  imports = [
    ./common
    ./common/goroot.nix # not in common/default.nix — wsl-lite skips it
    ./wsl/windows.nix
    ./wsl/nix.nix
    ./wsl/toolchains.nix
    ./wsl/dotfiles.nix
  ];

  home.username = "marcus";
  home.homeDirectory = "/home/marcus";
  windows.username = "marcus";
}
