# Aggregator for all system-level modules.
#
# The two sops-nix/home-manager imports are the platform halves of
# modules/common/secrets.nix and modules/common/home-manager.nix: they are
# what make the sops.* and home-manager.* options exist for common to set.
{ inputs, ... }:

{
  # Positions preserved from the retired ./secrets.nix and ./home-manager.nix
  # shims: darwin concatenates equal-priority activation-script text in
  # definition order, so moving these imports moves the script and the drv.
  imports = [
    ../common
    ./nix.nix
    ./tailscale.nix
    inputs.sops-nix.darwinModules.sops
    ./homebrew.nix
    ./users.nix
    ./macos.nix
    ./fonts.nix
    inputs.home-manager.darwinModules.home-manager
    # Last on purpose: appending leaves every position above unmoved, and
    # the ordering note at the top of this file makes that matter. Settings
    # for it live with the rest of the brew config, in ./homebrew.nix.
    inputs.nix-homebrew.darwinModules.nix-homebrew
  ];
}
