# Home Manager entry point for the headless WSL box: everything the dev
# machine has except the Windows integration.
#
# Deliberately NOT imported (don't add them back without reading this):
# ./wsl/dotfiles.nix — this box has no JetBrains or Zed on the other side
# of /mnt/c, and worse, if it ever ran on the same PC as the dev box both
# would see the same /mnt/c/Users/marcus while win-sync's direction stamp
# stays per-box, producing spurious pulls and two clones racing to push.
# (windows.username lives inside that file too, so nothing else to skip.)
#
{ ... }:

{
  imports = [ ./common ];

  home.username = "marcus";
  home.homeDirectory = "/home/marcus";
}
