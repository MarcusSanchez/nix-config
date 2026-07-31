# Aggregator for modules shared by every machine (NixOS and darwin alike —
# everything in here must only use options that exist on both).
{ ... }:

{
  imports = [
    ./packages.nix
    ./secrets.nix
    ./home-manager.nix
    ./claude-code.nix
  ];
}
