# Host definition: the WSL KIND, not one machine — every WSL attribute
# in flake.nix points here, differing only in the hostName passed in
# (and any per-attr extra modules wired there, e.g. the rustdesk
# bridge). Headless and portable: a terminal into the shared
# toolchains on whatever PC hosts the distro.
{ hostName, ... }:

{
  imports = [
    ../../modules/nixos
    ../../modules/wsl
    # Host-level, not in the aggregator: only ONE WSL distro per Windows PC
    # can be a tailnet node — they share a network namespace. See the file.
    ../../modules/wsl/tailscale.nix
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
