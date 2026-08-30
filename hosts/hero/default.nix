# Host definition: hero, a dual-boot desk PC on the full modules/nixos
# stack — the 4K main with the 1440p VERTICAL on its LEFT.
#
# modules/nixos is the bare-metal world, aggregated by its default.nix.
# What stays spelled out here is this box's own hardware truth: the
# generated hardware config, Secure Boot (lanzaboote.nix), and the
# NVIDIA driver shape — a pool file OUTSIDE the aggregator (it
# hardcodes the video driver and early-KMS initrd, so a non-NVIDIA host
# must not get it).
# The two platform modules are the sops-nix/home-manager halves that
# make the sops.* and home-manager.* options exist for modules/common.
{ inputs, hostName, ... }:

{
  imports = [
    ../../modules/common
    inputs.sops-nix.nixosModules.sops
    inputs.home-manager.nixosModules.home-manager
    ../../modules/nixos
    ../../modules/nixos/nvidia.nix
    ./hardware-configuration.nix
    # Secure Boot, live since the sbctl ceremony. On a REINSTALL,
    # comment this out until `sudo sbctl create-keys` has run — enabled
    # without keys on disk, the bootloader install (and therefore
    # nixos-install) fails. Full ceremony: lanzaboote.nix header.
    ./lanzaboote.nix
  ];

  nixpkgs.hostPlatform = "x86_64-linux";

  # Supplied by flake.nix, which keys every entry by the hostname itself, so
  # this cannot drift from the attribute that bare `nixos-rebuild --flake
  # /etc/nixos` resolves.
  networking.hostName = hostName;

  homeEntryPoint = ../../home/marcus/nixos.nix;

  # Connectors that carry the greeter's sign-in UI on this machine — the
  # 4K; the portrait 1440p stays blank at the login screen.
  greeterScreens = [ "DP-3" ];

  # The release this machine was installed under — set at install time
  # to whatever the installer produces, then never changes.
  system.stateVersion = "26.05";
}
