# Home Manager entry point for the desktop: identity + shared config +
# desktop-only concerns.
{ ... }:

{
  imports = [
    ./common
    ./desktop/ghostty.nix
    ./desktop/theme.nix
    # session-tools -> niri -> dms: HM emits sibling imports'
    # home.packages contributions in REVERSE import order (verified by
    # derivation diff), so this backwards-looking order is what
    # reproduces the pre-split package list byte-for-byte — not cosmetic
    ./desktop/session-tools.nix
    ./desktop/niri.nix
    ./desktop/dms.nix
    ./desktop/appearance.nix
    # UI-managed-config links + drift auto-commit. Desktop note: the
    # niri kdls (desktop/niri.nix), dms.settings.json (desktop/dms.nix)
    # and xremap.yml live under the same pathspec, so their drift rides
    # the same hook.
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
