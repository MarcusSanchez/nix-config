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
    # UI-managed-config links + drift auto-commit for zed/ghostty/
    # .ideavimrc (Ryoku's own config is machine-local by design and
    # never linked into the repo)
    ./common/dotfiles.nix
    ./nixos/apps.nix
  ];

  # username/homeDirectory come from identity.* via the HM bridge
  # Do not change after initial install.
  home.stateVersion = "26.05";
}
