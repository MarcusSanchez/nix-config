# nix-ld lets unpatched dynamically-linked binaries (Electron apps,
# npm-downloaded tools, Mason-installed LSPs, ...) run on NixOS.
# Only the module's base libraries here (setting `libraries` would
# *replace* that default set, not add to it) — anything a specific
# project needs goes in that project's devenv.nix, not the global
# config (e.g. noted/mobile carries the Electron/GTK stack).
{ ... }:

{
  programs.nix-ld.enable = true;
}
