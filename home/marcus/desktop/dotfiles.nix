# Shim: the desktop's UI-managed-config links + drift auto-commit all
# live in ../common/dotfiles-links.nix. Desktop-specific note:
# niri.config.kdl, niri.outputs.kdl, dms.settings.json and xremap.yml
# are linked by desktop/niri.nix but live under the same pathspec, so
# their drift rides the same hook.
{ ... }:

{
  imports = [ ../common/dotfiles-links.nix ];
}
