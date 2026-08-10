# nix-ld lets unpatched dynamically-linked binaries (npm-downloaded
# tools, prebuilt LSPs, ...) run on NixOS. Only the module's base
# libraries here (setting `libraries` would *replace* that default set,
# not add to it) — anything a specific project needs goes in that
# project's devenv.nix. (The desktop machines get theirs from
# modules/nixos/foreign-binaries.nix, together with the GUI library
# list; this box needs only the enable.)
{ ... }:

{
  programs.nix-ld.enable = true;
}
