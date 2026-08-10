# Home Manager entry point for the WSL machine: identity + shared config +
# WSL-only concerns.
{ ... }:

{
  imports = [
    ./common
    ./wsl/dotfiles.nix
  ];

  # username/homeDirectory come from identity.* via the HM bridge
  # Do not change after initial install.
  home.stateVersion = "25.05";
  # the WINDOWS account on this PC — same string by coincidence, not
  # the same identity
  windows.username = "marcus";
}
