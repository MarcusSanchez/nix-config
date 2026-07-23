# Bridges Home Manager into the nix-darwin build; per-user config lives in home/.
{ inputs, ... }:

{
  imports = [ inputs.home-manager.darwinModules.home-manager ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs; };
    # If a target dotfile already exists, move it aside instead of aborting.
    backupFileExtension = "hm-backup";
    users.marcussanchez = import ../../home/marcus/mac.nix;
  };
}
