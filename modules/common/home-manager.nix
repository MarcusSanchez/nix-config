# Bridges Home Manager into the system build; per-user config lives in
# home/. One bridge for both platforms — only the HM module import differs,
# and that lives in each platform's home-manager.nix shim.
#
# Which entry point this host's user gets is per-host via homeEntryPoint,
# set in hosts/ — the dev box and the lite boxes share this bridge but not
# their home config, and the mac declares its entry the same way.
{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:

{
  options.homeEntryPoint = lib.mkOption {
    type = lib.types.path;
    description = "Home Manager entry point for this host's user, set in hosts/.";
  };

  config.home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs; };
    # If a target dotfile already exists, move it aside instead of aborting.
    backupFileExtension = "hm-backup";
    users.${if pkgs.stdenv.isDarwin then "marcussanchez" else "marcus"} = import config.homeEntryPoint;
  };
}
