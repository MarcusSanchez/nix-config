# Home Manager entry point for the desktop: identity + shared config +
# desktop-only concerns.
{ ... }:

{
  imports = [
    ./common
    ./desktop/ghostty.nix
    ./desktop/niri.nix
    ./desktop/appearance.nix
    ./desktop/dotfiles.nix
    ./desktop/apps.nix
  ];

  home = {
    username = "marcus";
    homeDirectory = "/home/marcus";
    # Do not change after initial install.
    stateVersion = "26.05";
  };
}
