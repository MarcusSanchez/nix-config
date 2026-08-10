# Home Manager entry point for the desktop: identity + shared config +
# desktop-only concerns.
{ ... }:

{
  imports = [
    ./common
    ./desktop/ghostty.nix
    ./desktop/niri.nix
    ./desktop/appearance.nix
    # UI-managed-config links + drift auto-commit. Desktop note:
    # niri.config.kdl, niri.outputs.kdl, dms.settings.json and
    # xremap.yml are linked by desktop/niri.nix but live under the same
    # pathspec, so their drift rides the same hook.
    ./common/dotfiles-links.nix
    ./desktop/apps.nix
  ];

  home = {
    username = "marcus";
    homeDirectory = "/home/marcus";
    # Do not change after initial install.
    stateVersion = "26.05";
  };
}
