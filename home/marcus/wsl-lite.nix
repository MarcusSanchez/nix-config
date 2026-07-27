# Home Manager entry point for the lite WSL box: identity + the shared
# config, and nothing else.
#
# Deliberately NOT imported here (don't add them back without reading
# this): ./wsl/dotfiles.nix — both WSL instances see the same
# /mnt/c/Users/marcus, but win-sync's direction stamp is per-box, so two
# syncers over one set of Windows files produce spurious pulls, duplicate
# chore commits and two clones racing to push. ./wsl/windows.nix — only
# dotfiles.nix consumes it. ./wsl/toolchains.nix — rustup glibc repair,
# and there's no rustup here.
{ ... }:

{
  imports = [
    ./common
    ./wsl/nix.nix
  ];

  home.username = "marcus";
  home.homeDirectory = "/home/marcus";
}
