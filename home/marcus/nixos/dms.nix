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
}
