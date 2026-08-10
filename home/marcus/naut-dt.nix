# Home Manager entry point for naut-dt: shared config + the desktop
# session, composed decisively — every concern this machine's user
# runs is named here, imported from ./common and ./nixos.
{ ... }:

{
  imports = [
    ./common
    ./nixos/ghostty.nix
    ./nixos/theme.nix
    ./nixos/dms.nix
    ./nixos/niri.nix
    ./nixos/appearance.nix
    # UI-managed-config links + drift auto-commit. Desktop note: the
    # niri kdls (nixos/niri.nix), dms.settings.json (nixos/dms.nix)
    # and xremap.yml live under the same pathspec, so their drift rides
    # the same hook.
    ./common/dotfiles.nix
    ./nixos/apps.nix
  ];

  # username/homeDirectory come from identity.* via the HM bridge
  # Do not change after initial install.
  home.stateVersion = "26.05";
}
