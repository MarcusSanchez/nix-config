# Host definition: the TUF laptop (ASUS TUF Dash F15 — discrete NVIDIA
# GPU, MUX in discrete mode, so the shared driver shape in
# modules/nixos/nvidia.nix fits it as-is and no prime block is needed).
# One of two bare-metal NixOS hosts; the other is hosts/naut-dt.
#
# modules/nixos is the bare-metal world, aggregated by its default.nix.
# What stays spelled out here is this box's own hardware truth: the
# generated hardware config, and the NVIDIA driver shape — a pool file
# OUTSIDE the aggregator (it hardcodes the video driver and early-KMS
# initrd, so a non-NVIDIA host must not get it). No lanzaboote.nix: this
# machine is not dual-booted beside Windows, so Secure Boot was never
# set up on it.
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
  ];

  nixpkgs.hostPlatform = "x86_64-linux";

  # Supplied by flake.nix, which keys every entry by the hostname itself, so
  # this cannot drift from the attribute that bare `nixos-rebuild --flake
  # /etc/nixos` resolves.
  networking.hostName = hostName;

  homeEntryPoint = ../../home/marcus/nixos.nix;

  # Connectors that carry the greeter's sign-in UI on this machine — the
  # built-in panel (external monitors, when plugged in, stay blank at
  # the login screen).
  greeterScreens = [ "eDP-1" ];

  # Do not change after initial install.
  system.stateVersion = "26.05";
}
