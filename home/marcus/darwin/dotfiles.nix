# Shim: the mac's UI-managed-config links + drift auto-commit all live
# in ../common/dotfiles-links.nix. Mac-specific note: the WSL boxes
# reach the same files through win-sync copies instead of symlinks
# (wsl/dotfiles.nix) — Windows can't traverse Linux symlinks at all.
{ ... }:

{
  imports = [ ../common/dotfiles-links.nix ];
}
