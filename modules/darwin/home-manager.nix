# The home-manager.* options exist on this platform because of this import;
# the bridge itself lives in modules/common/home-manager.nix.
{ inputs, ... }:

{
  imports = [ inputs.home-manager.darwinModules.home-manager ];
}
