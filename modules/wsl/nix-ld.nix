# nix-ld lets unpatched dynamically-linked binaries (npm-downloaded
# tools, prebuilt LSPs, ...) run on NixOS. Only the module's base
# libraries here (setting `libraries` would *replace* that default set,
# not add to it) — anything a specific project needs goes in that
# project's devenv.nix. Duplicated with modules/nixos/nix-ld.nix on
# purpose: each directory is self-contained for its kind of machine.
{ ... }:

{
  programs.nix-ld.enable = true;
}
