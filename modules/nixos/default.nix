# Aggregator for all system-level modules.
{ ... }:

{
  imports = [
    ../common
    ./nix.nix
    ./packages.nix
    ./nix-ld.nix
    ./keyring.nix
    ./users.nix
    ./wsl.nix
    ./home-manager.nix
  ];
}
