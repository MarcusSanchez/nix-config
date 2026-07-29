# Host definition: the WSL machine. Everything host-specific lives here;
# everything reusable lives in modules/.
{ ... }:

{
  imports = [
    ../../modules/nixos
    # Host-level, not in the aggregator: only ONE WSL distro per Windows PC
    # can be a tailnet node — they share a network namespace. See the file.
    ../../modules/nixos/tailscale.nix
  ];

  nixpkgs.hostPlatform = "x86_64-linux";

  networking.hostName = "nixos";

  homeEntryPoint = ../../home/marcus/wsl.nix;

  # Do not change after initial install.
  system.stateVersion = "25.05";
}
