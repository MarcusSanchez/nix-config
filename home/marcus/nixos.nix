# Home Manager entry point for the niri + DMS desktops (tuf-laptop,
# naut-dt) — the world entry beside wsl.nix, darwin.nix and ryoku.nix:
# shared config + the desktop session, every concern named here,
# imported from ./common and ./nixos. The long-anticipated per-host
# split happened when hero committed to Ryoku — ryoku.nix is that
# world's entry; this one keeps serving every DMS desktop.
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
