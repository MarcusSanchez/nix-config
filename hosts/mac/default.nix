# Host definition: the MacBook Air. Everything host-specific lives here;
# everything reusable lives in modules/.
{ hostName, ... }:

{
  imports = [ ../../modules/darwin ];

  nixpkgs.hostPlatform = "aarch64-darwin";

  homeEntryPoint = ../../home/marcus/mac.nix;

  # From flake.nix — see hosts/wsl/default.nix.
  networking.hostName = hostName;
  networking.computerName = "Marcus’s MacBook Air";

  # Do not change after initial install.
  system.stateVersion = 6;
}
