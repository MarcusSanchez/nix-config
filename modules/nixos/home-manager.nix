# Bridges Home Manager into the NixOS build; per-user config lives in home/.
# Which entry point marcus gets is per-host — the full dev machine and the
# lite box share this bridge but not their home config.
{
  inputs,
  config,
  lib,
  ...
}:

{
  imports = [ inputs.home-manager.nixosModules.home-manager ];

  options.homeEntryPoint = lib.mkOption {
    type = lib.types.path;
    description = "Home Manager entry point for this host's marcus, set in hosts/.";
  };

  config.home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs; };
    # If a target dotfile already exists, move it aside instead of aborting.
    backupFileExtension = "hm-backup";
    users.marcus = import config.homeEntryPoint;
  };
}
