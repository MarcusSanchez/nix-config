# Aggregator for all system-level modules. Every WSL host imports this —
# they differ only in hostname and which home entry point they point
# homeEntryPoint at, since what makes the dev box a dev box lives in the
# home layer (the Windows dotfile syncing), not here.
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
    ./keyring.nix
    ./users.nix
    ./wsl.nix
  ];
}
