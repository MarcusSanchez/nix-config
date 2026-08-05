# Aggregator for the SHARED NixOS system core — every NixOS host imports
# this, whatever its flavor. What differs by kind of machine lives in the
# flavor layers: modules/wsl (Windows integration, weekly autoUpgrade,
# keyring for headless secretspec) and modules/desktop (the whole
# bare-metal GUI stack). A file here does nothing until listed.
#
# The two sops-nix/home-manager imports are the platform halves of
# modules/common/secrets.nix and modules/common/home-manager.nix: they are
# what make the sops.* and home-manager.* options exist for common to set.
{ inputs, ... }:

{
  imports = [
    ../common
    inputs.sops-nix.nixosModules.sops
    inputs.home-manager.nixosModules.home-manager
    ./nix.nix
    ./packages.nix
    ./nix-ld.nix
    ./users.nix
  ];
}
