# ~/.config/zed is a symlink into this repo's working tree
# (mkOutOfStoreSymlink, deliberately not a store path): Zed's UI writes
# land directly in mac/zed/ as git drift — commit like lazy-lock.json.
# Whole-directory link on purpose; per-file links can be clobbered by
# atomic saves. The WSL machine can't do any of this (Windows can't
# traverse Linux symlinks) — it uses win-sync.nix copies instead.
#
# One-time on a machine with an existing ~/.config/zed: move its
# contents into mac/zed/ here, delete the now-empty directory, rebuild.
{ config, ... }:

{
  # UI edits accumulate as working-tree drift through this symlink;
  # auto-commit.nix commits and pushes them at activation.
  xdg.configFile."zed".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nix-config/home/marcus/mac/zed";
}
