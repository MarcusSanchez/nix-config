# Home Manager entry point for the bare-metal desktops — the world
# entry beside wsl.nix and darwin.nix: shared config + the desktop
# session, every concern named here, imported from ./common and
# ./nixos. Both desktop machines run the same home; this file splits
# per-host the day a real divergence appears.
{ ... }:

{
  imports = [
    ./common
    ./nixos/theme.nix
    ./nixos/dms.nix
    ./nixos/niri.nix
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
