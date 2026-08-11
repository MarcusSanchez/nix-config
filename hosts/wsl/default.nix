# Host definition: the WSL KIND, not one machine — every WSL attribute
# in flake.nix points here, differing only in the hostName passed in.
# Headless and portable: a terminal into the shared toolchains on
# whatever PC hosts the distro. Per-machine differences are hostname
# lists hardcoded at the options they gate (the rustdesk bridge in
# wsl/networking.nix, the super tier in common/secrets.nix).
#
# The two platform modules are the sops-nix/home-manager halves that
# make the sops.* and home-manager.* options exist for modules/common
# to set; everything WSL lives in modules/wsl, self-contained.
{
  inputs,
  hostName,
  lib,
  ...
}:

{
  imports = [
    ../../modules/common
    inputs.sops-nix.nixosModules.sops
    inputs.home-manager.nixosModules.home-manager
    ../../modules/wsl
  ]
  # Not in the wsl aggregator: a PC gets exactly one tailnet node — the
  # Windows host or a single distro, never both (all its distros share
  # one network namespace; see the file). The list is the distros whose
  # PC carries the node elsewhere, so they skip this import.
  ++ lib.optionals (!builtins.elem hostName [ "naut-box" ]) [ ../../modules/wsl/networking.nix ];

  nixpkgs.hostPlatform = "x86_64-linux";

  # Supplied by flake.nix, which keys every entry by the hostname itself, so
  # this cannot drift from the attribute that bare `nixos-rebuild --flake
  # /etc/nixos` and system.autoUpgrade resolve. Several hostnames may point
  # at this same module — that's how an identical second box is added.
  networking.hostName = hostName;

  homeEntryPoint = ../../home/marcus/wsl.nix;

  # Do not change after initial install.
  system.stateVersion = "25.05";
}
