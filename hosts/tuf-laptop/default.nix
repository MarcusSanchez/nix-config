# Host definition: the TUF laptop (discrete NVIDIA GPU, MUX in
# discrete mode — the shared driver shape in modules/nixos/nvidia.nix
# fits it as-is). One of two bare-metal NixOS hosts (the other is
# hosts/naut-dt).
#
# Imports are DECISIVE: modules/nixos is a pool with no aggregator, and
# this list is the whole statement of what the machine runs — the same
# desktop session as naut-dt, plus this box's own hardware truth. The
# two platform modules are the sops-nix/home-manager halves that make
# the sops.* and home-manager.* options exist for modules/common.
{ inputs, hostName, ... }:

{
  imports = [
    ../../modules/common
    inputs.sops-nix.nixosModules.sops
    inputs.home-manager.nixosModules.home-manager
    ../../modules/nixos/nix.nix
    ../../modules/nixos/packages.nix
    ../../modules/nixos/nix-ld.nix
    ../../modules/nixos/users.nix
    # the desktop session, in an order that is NOT cosmetic: merged-list
    # options (systemPackages, udev.packages) order their entries by
    # module position — keep this run aligned with naut-dt's
    inputs.dank-material-shell.nixosModules.greeter
    ../../modules/nixos/boot.nix
    ../../modules/nixos/locale.nix
    ../../modules/nixos/security-keys.nix
    ../../modules/nixos/tailscale.nix
    ../../modules/nixos/niri.nix
    ../../modules/nixos/greeter.nix
    ../../modules/nixos/peripherals.nix
    ../../modules/nixos/audio.nix
    ../../modules/nixos/networking.nix
    ../../modules/nixos/fonts.nix
    ../../modules/nixos/foreign-binaries.nix
    ../../modules/nixos/nvidia.nix
    ./hardware-configuration.nix
  ];

  nixpkgs.hostPlatform = "x86_64-linux";

  # Supplied by flake.nix, which keys every entry by the hostname itself, so
  # this cannot drift from the attribute that bare `nixos-rebuild --flake
  # /etc/nixos` resolves.
  networking.hostName = hostName;

  homeEntryPoint = ../../home/marcus/tuf-laptop.nix;

  # Connectors that carry the greeter's sign-in UI on this machine — the
  # built-in panel (external monitors, when plugged in, stay blank at
  # the login screen).
  greeterScreens = [ "eDP-1" ];

  # Do not change after initial install.
  system.stateVersion = "26.05";
}
