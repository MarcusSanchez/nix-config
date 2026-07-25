# ~/.ideavimrc → the shared copy in common/ideavim/ (out-of-store
# symlink; single file, so no directory trick — an editor doing atomic
# saves could replace the link with a real file, but HM re-links and
# hm-backups it on the next switch). WSL reaches the same file through
# win-sync (wsl/ideavim.nix); drift here is committed by auto-commit.nix.
{ config, ... }:

{
  home.file.".ideavimrc".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nix-config/home/marcus/common/ideavim/.ideavimrc";
}
