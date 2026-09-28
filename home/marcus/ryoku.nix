# Home Manager entry point for the Ryoku desktop (hero) — the world
# entry beside nixos.nix, wsl.nix and darwin.nix, split out the day the
# desk committed to Ryoku while the other bare-metal hosts stayed on
# niri + DMS (the divergence nixos.nix's header always anticipated).
# Ryoku owns the session wholesale — shell, wallpaper, theming, locker,
# niri config — so this entry carries only what Ryoku doesn't:
# the shared toolchains, the UI-managed dotfile links, the desktop GUI
# apps, and the session helpers in nixos/ryoku.nix.
{ ... }:

{
  imports = [
    ./common
    ./nixos/ryoku.nix
    # UI-managed-config links + drift auto-commit — zed/ghostty/
    # .ideavimrc still ride it; the niri kdls and dms.settings.json do
    # NOT reach this world (Ryoku materializes its own niri config, and
    # the drift pathspec only matches files that exist as links)
    ./common/dotfiles.nix
    ./nixos/apps.nix
  ];

  # username/homeDirectory come from identity.* via the HM bridge
  # Do not change after initial install.
  home.stateVersion = "26.05";
}
