# Host definition: the MacBook Air. Everything host-specific lives here;
# everything reusable lives in modules/.
{ ... }:

{
  imports = [ ../../modules/darwin ];

  nixpkgs.hostPlatform = "aarch64-darwin";

  networking.hostName = "Marcuss-MacBook-Air";
  networking.computerName = "Marcus’s MacBook Air";

  # Do not change after initial install.
  system.stateVersion = 6;
}
