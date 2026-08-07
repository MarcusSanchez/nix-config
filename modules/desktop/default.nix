# Aggregator for the bare-metal desktop flavor: boot/splash, the niri +
# DankMaterialShell session, and the hardware services a machine someone
# sits in front of needs. Imports the dms-greeter module from the
# dank-material-shell flake input — the ONLY thing that input supplies
# (the shell itself is nixpkgs' dms-shell; see flake.nix). NVIDIA is NOT
# here: modules encode per-machine GPU facts (MUX mode, open modules),
# so each host carries its own — see hosts/tuf-nixos/nvidia.nix and
# hosts/bedroom-nixos/nvidia.nix.
#
# tailscale.nix lives in this aggregator, unlike the WSL flavor's: a
# bare-metal machine is always its own tailnet node, so the
# one-node-per-Windows-PC constraint that forces host-level imports on
# WSL does not exist here.
#
# The niri.nix..packages.nix run descends from the old desktop.nix
# monolith: merged-list options (systemPackages, udev.packages) order
# their entries by module position, so reordering imports is not
# cosmetic.
{ inputs, ... }:

{
  imports = [
    inputs.dank-material-shell.nixosModules.greeter
    ./boot.nix
    ./zram.nix
    ./locale.nix
    ./security-keys.nix
    ./tailscale.nix
    ./niri.nix
    ./greeter.nix
    ./peripherals.nix
    ./audio.nix
    ./networking.nix
    ./users.nix
    ./packages.nix
    ./fonts.nix
    ./nix-ld.nix
    ./envfs.nix
  ];
}
