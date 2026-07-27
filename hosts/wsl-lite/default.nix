# Host definition: the lite WSL box — a place to drop simple binaries,
# not a dev machine. Imports modules/nixos/base.nix rather than the full
# aggregator, so it skips the language toolchains, claude-code, nix-ld
# and the keyring.
{ ... }:

{
  imports = [ ../../modules/nixos/base.nix ];

  nixpkgs.hostPlatform = "x86_64-linux";

  # Must match the flake attribute: bare `nixos-rebuild --flake /etc/nixos`
  # and system.autoUpgrade both resolve nixosConfigurations.<hostname>.
  networking.hostName = "nixos-lite";

  homeEntryPoint = ../../home/marcus/wsl-lite.nix;

  # Do not change after initial install.
  system.stateVersion = "25.05";
}
