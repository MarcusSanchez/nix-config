# Home Manager entry point for the MacBook: identity + shared config +
# mac-only concerns.
{ ... }:

{
  imports = [
    ./common
    ./darwin/ghostty.nix
    ./darwin/nix.nix
    # UI-managed-config links + drift auto-commit (the desktop entry
    # point imports the same file; WSL manages none of these)
    ./common/dotfiles-links.nix
    ./darwin/hammerspoon.nix
  ];

  # username/homeDirectory come from identity.* via the HM bridge
  # Do not change after initial install.
  home.stateVersion = "25.05";
}
