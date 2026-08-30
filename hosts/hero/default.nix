# Host definition: hero, the desk PC that succeeds the sold naut
# machine — same desk role and the same feel (full modules/nixos
# stack), different hardware and a different monitor topology: the 4K
# main with the 1440p VERTICAL on its LEFT (the old 1080p portrait is
# gone). Everything monitor-shaped from the predecessor is deliberately
# NOT carried: the boot-splash single-monitor machinery, the
# wake/hide-side-monitors oneshots and the WoL link file were all keyed
# to that desk's connectors and MAC — add hero's own once the machine
# reports them (`niri msg outputs`; the NIC's MAC from `ip link`).
#
# modules/nixos is the bare-metal world, aggregated by its default.nix.
# What stays spelled out here is this box's own hardware truth: the
# generated hardware config (PLACEHOLDER until install — see its
# header), Secure Boot (commented until the sbctl ceremony), and the
# NVIDIA driver shape — a pool file OUTSIDE the aggregator (it
# hardcodes the video driver and early-KMS initrd, so a non-NVIDIA host
# must not get it); drop that import if this build turns out not to
# carry an NVIDIA card.
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
    # Secure Boot, COMMENTED for the first install: enabled without keys
    # on disk, the bootloader install (and therefore nixos-install)
    # fails. After `sudo sbctl create-keys`, uncomment and run the full
    # ceremony — lanzaboote.nix header.
    # ./lanzaboote.nix
  ];

  nixpkgs.hostPlatform = "x86_64-linux";

  # Supplied by flake.nix, which keys every entry by the hostname itself, so
  # this cannot drift from the attribute that bare `nixos-rebuild --flake
  # /etc/nixos` resolves.
  networking.hostName = hostName;

  homeEntryPoint = ../../home/marcus/nixos.nix;

  # greeterScreens stays at its default ([] = the sign-in UI on every
  # screen — no value can strand the login) until the machine reports
  # its connector names; then pin the 4K here like the other desktops.

  # The release this machine was installed under — set at install time
  # to whatever the installer produces, then never changes.
  system.stateVersion = "26.05";
}
