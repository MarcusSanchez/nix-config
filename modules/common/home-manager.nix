# Bridges Home Manager into the system build; per-user config lives in
# home/. One bridge for both platforms — only the HM module import differs,
# and that lives in each platform aggregator.
#
# Which entry point this host's user gets is per-host via homeEntryPoint,
# set in hosts/ (or defaulted by a flavor) — every WSL box shares one
# entry point, the desktop hosts another, the mac its own.
{
  inputs,
  config,
  lib,
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
    # The account name and home dir flow from identity.* so the entry
    # points carry only what is genuinely per-host (their stateVersion);
    # mkDefault leaves an entry point free to disagree.
    users.${config.identity.username} = {
      imports = [ config.homeEntryPoint ];
      home.username = lib.mkDefault config.identity.username;
      home.homeDirectory = lib.mkDefault config.identity.home;
    };
  };
}
