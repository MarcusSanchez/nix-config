# Home Manager entry point for the desktop: identity + shared config +
# desktop-only concerns.
{ ... }:

{
  imports = [
    ./common
    ./desktop/ghostty.nix
    ./desktop/theme.nix
    ./desktop/dms.nix
    ./desktop/niri.nix
    ./desktop/session-tools.nix
    ./desktop/appearance.nix
    # UI-managed-config links + drift auto-commit. Desktop note: the
    # niri kdls (desktop/niri.nix), dms.settings.json (desktop/dms.nix)
    # and xremap.yml live under the same pathspec, so their drift rides
    # the same hook.
    ./common/dotfiles-links.nix
    ./desktop/apps.nix
  ];

  # username/homeDirectory come from identity.* via the HM bridge
  # Do not change after initial install.
  home.stateVersion = "26.05";
}
