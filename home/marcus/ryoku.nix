# Home Manager entry point for the bare-metal desktops — the world
# entry beside wsl.nix and darwin.nix, serving every NixOS machine with
# a screen the way wsl.nix serves the WSL boxes (it replaced the
# niri + DMS world's nixos.nix when the fleet converged on Ryoku; that
# world is whole in git history). Ryoku owns the session wholesale —
# shell, wallpaper, theming, locker, niri config — so this entry
# carries only what Ryoku doesn't: the shared toolchains, the
# UI-managed dotfile links, the desktop GUI apps, and the session
# helpers in nixos/ryoku.nix.
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
