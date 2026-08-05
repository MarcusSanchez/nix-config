# Home Manager entry point for the WSL machine: identity + shared config +
# WSL-only concerns.
{ ... }:

{
  imports = [
    ./common
    ./wsl/dotfiles.nix
  ];

  home = {
    username = "marcus";
    homeDirectory = "/home/marcus";
    # Do not change after initial install.
    stateVersion = "25.05";
  };
  windows.username = "marcus";
}
