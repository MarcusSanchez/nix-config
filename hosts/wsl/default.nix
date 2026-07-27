# Host definition: the WSL machine. Everything host-specific lives here;
# everything reusable lives in modules/.
{ ... }:

{
  imports = [ ../../modules/nixos ];

  nixpkgs.hostPlatform = "x86_64-linux";

  networking.hostName = "nixos";

  homeEntryPoint = ../../home/marcus/wsl.nix;

  # Do not change after initial install.
  system.stateVersion = "25.05";
}
