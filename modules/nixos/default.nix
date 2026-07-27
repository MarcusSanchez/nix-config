# Aggregator for a full WSL dev machine: the shared floor (./base.nix)
# plus everything only a workstation needs. A minimal host imports
# base.nix directly instead — so a new module goes here if it's
# dev-machine tooling, and in base.nix only if every WSL box needs it.
{ ... }:

{
  imports = [
    ./base.nix
    ../common
    ./nix-ld.nix
    ./keyring.nix
  ];
}
