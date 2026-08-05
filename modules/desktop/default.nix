# Aggregator for the bare-metal desktop flavor: boot/splash, the niri +
# DankMaterialShell session, and laptop hardware services. Imports the
# dms-greeter module from the dank-material-shell flake input — the ONLY
# thing that input supplies (the shell itself is nixpkgs' dms-shell; see
# flake.nix). NVIDIA is NOT here: modules encode per-machine GPU facts
# (MUX mode, open modules), so each host carries its own — see
# hosts/tuf/nvidia.nix.
#
# tailscale.nix lives in this aggregator, unlike the WSL flavor's: a
# bare-metal machine is always its own tailnet node, so the
# one-node-per-Windows-PC constraint that forces host-level imports on
# WSL does not exist here.
{ inputs, ... }:

{
  imports = [
    inputs.dank-material-shell.nixosModules.greeter
    ./boot.nix
    ./zram.nix
    ./locale.nix
    ./tpm.nix
    ./tailscale.nix
    ./desktop.nix
    ./fonts.nix
    ./nix-ld.nix
  ];
}
