# Aggregator for the WSL world — everything a NixOS machine inside
# Windows runs, in one import (hosts/wsl imports it beside
# modules/common; modules/nixos is the bare-metal world and plays no
# part here). networking.nix is deliberately NOT here: it stays a
# host-level import because only ONE WSL distro per Windows PC can be
# a tailnet node — see that file.
{ ... }:

{
  imports = [
    ./nix.nix
    ./packages.nix
    ./nix-ld.nix
    ./users.nix
    ./wsl.nix
    ./keyring.nix
  ];
}
