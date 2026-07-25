# ~/.config/zed is a REAL directory; only settings.json and keymap.json
# are out-of-store symlinks into the SHARED ../common/zed/ (one config
# for both machines; keymap carries both cmd- and ctrl- variants —
# stow's --no-folding idea). Writes to the two files flow through the
# links into the repo as git drift — committed by auto-commit.nix —
# while anything else Zed creates next to them (prompt-library db,
# themes) lands in the real directory and can never reach the repo.
# Same single-file caveat as mac/ideavim.nix: an atomic save could
# replace a link with a plain file; HM re-links and hm-backups it on
# the next switch. The WSL machine can't use links at all (Windows
# can't traverse them) — it syncs the same files via win-sync.nix.
{ config, ... }:

let
  repoZed = "${config.home.homeDirectory}/nix-config/home/marcus/common/zed";
in
{
  xdg.configFile."zed/settings.json".source = config.lib.file.mkOutOfStoreSymlink "${repoZed}/settings.json";
  xdg.configFile."zed/keymap.json".source = config.lib.file.mkOutOfStoreSymlink "${repoZed}/keymap.json";
}
