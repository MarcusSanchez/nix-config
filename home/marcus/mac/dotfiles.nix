# The UI-managed configs, symlinked out of the store into the shared
# ../common/dotfiles/ so edits land in the repo as git drift (committed
# by auto-commit.nix). WSL reaches the same files through win-sync
# (wsl/dotfiles.nix) — Windows can't traverse Linux symlinks at all.
#
# Per-FILE links, never a whole-dir one: ~/.config/zed stays a real
# directory, so the prompt-library db and themes Zed writes beside its
# config land there instead of in the repo. Single-file links have one
# caveat — an atomic save can replace the link with a plain file, but HM
# re-links and hm-backups it on the next switch.
{ config, ... }:

let
  dotfiles = "${config.home.homeDirectory}/nix-config/home/marcus/common/dotfiles";
  link = name: config.lib.file.mkOutOfStoreSymlink "${dotfiles}/${name}";
in
{
  xdg.configFile."zed/settings.json".source = link "zed.settings.json";
  xdg.configFile."zed/keymap.json".source = link "zed.keymap.json";

  home.file.".ideavimrc".source = link ".ideavimrc";
}
