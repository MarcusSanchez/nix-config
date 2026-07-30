# Host definition: the WSL machine. Everything host-specific lives here;
# everything reusable lives in modules/.
{ hostName, ... }:

{
  imports = [
    ../../modules/nixos
    # Host-level, not in the aggregator: only ONE WSL distro per Windows PC
    # can be a tailnet node — they share a network namespace. See the file.
    ../../modules/nixos/tailscale.nix
  ];

  nixpkgs.hostPlatform = "x86_64-linux";

  # Supplied by flake.nix, which keys every entry by the hostname itself, so
  # this cannot drift from the attribute that bare `nixos-rebuild --flake
  # /etc/nixos` and system.autoUpgrade resolve. Several hostnames may point
  # at this same module — that's how an identical second box is added.
  networking.hostName = hostName;

  homeEntryPoint = ../../home/marcus/wsl.nix;

  # Do not change after initial install.
  system.stateVersion = "25.05";
}
