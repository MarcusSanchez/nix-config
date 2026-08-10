# The shell: DankMaterialShell (quickshell-based) — bar, launcher,
# notifications, control center, lock screen and wallpaper-driven
# Material theming in one — spawned and bound in niri.config.kdl
# (spawn-at-startup "dms run", Mod+D / Alt+Space spotlight, Super+Alt+L
# lock). Its settings.json is linked into the repo below (same
# UI-managed-config pattern as zed/niri: edits made in the DMS settings
# UI land as git drift). Session *state* — wallpaper path, avatar,
# per-app usage — stays outside in ~/.local/state, machine-local by
# design. (noctalia fits the same slot; DMS is the deliberate pick.)
{ config, pkgs, ... }:

{
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

  # DMS caveat, same as the zed links: it may atomically replace
  # settings.json's link with a plain file on save; HM re-links and
  # hm-backups it on the next switch.
  xdg.configFile =
    let
      dotfiles = "${config.home.homeDirectory}/nix-config/home/marcus/common/dotfiles";
      link = f: config.lib.file.mkOutOfStoreSymlink "${dotfiles}/${f}";
      # custom DMS bar widgets (one dir per plugin id), linked out-of-store
      # like the rest of the rice so QML edits hot-reload without a rebuild.
      # A plugin only LOADS where plugin_settings.json (machine-local DMS
      # state, not managed here) has it enabled — a bar entry for a plugin
      # the machine hasn't enabled simply doesn't render, so the shared
      # dms.settings.json stays safe across hosts.
      plugins = "${config.home.homeDirectory}/nix-config/home/marcus/nixos/assets/dms-plugins";
      pluginLink = p: config.lib.file.mkOutOfStoreSymlink "${plugins}/${p}";
    in
    {
      "DankMaterialShell/settings.json".source = link "dms.settings.json";
      "DankMaterialShell/plugins/cpuCombo".source = pluginLink "cpuCombo";
      "DankMaterialShell/plugins/gpuCombo".source = pluginLink "gpuCombo";
    };
}
