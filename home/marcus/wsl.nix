# Home Manager entry point for the WSL machine: identity + shared config +
# WSL-only concerns.
{ ... }:

{
  imports = [
    ./common
    ./wsl/nix.nix
    ./wsl/toolchains.nix
    ./wsl/zed.nix
  ];

  home.username = "marcus";
  home.homeDirectory = "/home/marcus";
}
