# Host definition: the second WSL box — headless, portable, "just a
# terminal": clone a repo on some other machine, poke at it with node or
# go, croc things around. Same system layer as the dev box (same
# toolchains, same nix-ld for npm's prebuilt binaries); what it skips is
# the Windows integration in the home layer — see home/marcus/wsl-lite.nix.
{ hostName, ... }:

{
  imports = [
    ../../modules/nixos
    # Host-level, not in the aggregator: only ONE WSL distro per Windows PC
    # can be a tailnet node — they share a network namespace. Fine here
    # because every lite instance lives on a PC of its own. See the file.
    ../../modules/nixos/tailscale.nix
  ];

  nixpkgs.hostPlatform = "x86_64-linux";

  # Supplied by flake.nix — see hosts/wsl/default.nix.
  networking.hostName = hostName;

  homeEntryPoint = ../../home/marcus/wsl-lite.nix;

  # Do not change after initial install.
  system.stateVersion = "25.05";
}
