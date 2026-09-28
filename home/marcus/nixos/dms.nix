# DankMaterialShell, the desktop shell — STOCK, a deliberate fresh
# start after the shell-trial month: no looks table, no shipped
# wallpapers or theme files, no accent machinery. Configuration
# happens in the settings UI (Mod+Comma) and lands as git drift
# through the settings link below, the same UI-managed pattern as zed.
# The retired looks system — the wallpaper:<name> commands, per-look
# dms.theme jsons, the shipped space wallpapers and the niri
# accent-sed — is whole in git history if any of it is ever wanted
# back. Spawned and bound in niri.config.kdl (spawn-at-startup
# "dms run", Alt/Mod+Space spotlight, Super+Alt+L lock). Session
# *state* — wallpaper path, avatar, per-app usage — stays outside in
# ~/.local/state, machine-local by design.
{
  config,
  pkgs,
  ...
}:

{
  # DMS caveat, same as the zed links: it may atomically replace
  # settings.json's link with a plain file on save; HM re-links and
  # hm-backups it on the next switch. The target starts as an empty
  # object — DMS runs on its defaults and writes choices back through
  # the link.
  xdg.configFile."DankMaterialShell/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nix-config/home/marcus/common/dotfiles/dms.settings.json";

  home.packages = [
    pkgs.dms-shell
    # dms spawns `qs` from PATH; its package doesn't bundle quickshell
    pkgs.quickshell
    # backs dms's system-monitor widgets (cpu/mem/process list)
    pkgs.dgop
    # backs dms's wallpaper-driven dynamic theming; without it on PATH,
    # theme generation silently does nothing
    pkgs.matugen
  ];

  # The wallpaper collection, carried in the repo so a fresh desktop
  # machine has them to pick from — linked to stable paths under ~
  # rather than referenced by store path, because DMS records an
  # ABSOLUTE path in its session state and a store path would rot on
  # the next GC. Selection happens in the settings UI; nothing here
  # sets one. (avatar-spaceman.png sits beside them in ./assets,
  # unlinked, for whenever a profile picture is wanted again.)
  home.file = {
    "Pictures/Wallpapers/astronaut-jellyfish.jpg".source = ./assets/astronaut-jellyfish.jpg;
    "Pictures/Wallpapers/galaxy-waves.jpg".source = ./assets/galaxy-waves.jpg;
    "Pictures/Wallpapers/nix-flake.png".source = ./assets/nix-flake.png;
    "Pictures/Wallpapers/space-stars-2560x1440.jpg".source = ./assets/space-stars-2560x1440.jpg;
    "Pictures/Wallpapers/space-stars-1080x1920.jpg".source = ./assets/space-stars-1080x1920.jpg;
    "Pictures/Wallpapers/swirls.jpg".source = ./assets/swirls.jpg;
  };
}
