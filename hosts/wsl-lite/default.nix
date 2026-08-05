# Host definition: the lite KIND of WSL box, not one machine — every
# headless instance points here (nixos-lite, office-lite-wsl-1/2 in
# flake.nix), differing only in the hostName passed in. Headless,
# portable, "just a terminal": clone a repo on some other machine, poke at
# it with node or go, croc things around. Same system layer as the dev box
# (same toolchains, same nix-ld for npm's prebuilt binaries); what it
# skips is the Windows integration in the home layer — see
# home/marcus/wsl-lite.nix.
{ hostName, ... }:

{
  imports = [
    ../../modules/nixos
    ../../modules/wsl
    # Host-level, not in the aggregator: only ONE WSL distro per Windows PC
    # can be a tailnet node — they share a network namespace. Fine here
    # because every lite instance lives on a PC of its own. See the file.
    ../../modules/wsl/tailscale.nix
  ];

  nixpkgs.hostPlatform = "x86_64-linux";

  # Supplied by flake.nix — see hosts/wsl/default.nix.
  networking.hostName = hostName;

  homeEntryPoint = ../../home/marcus/wsl-lite.nix;

  # No fly_token here, and no ability to get it: super.yaml's recipients
  # are the trusted machines' keys, which lite boxes never hold — see
  # modules/common/secrets.nix.
  secretsTier = "lite";

  # Do not change after initial install.
  system.stateVersion = "25.05";
}
