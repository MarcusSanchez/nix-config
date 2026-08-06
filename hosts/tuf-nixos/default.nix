# Host definition: the TUF laptop (ASUS TUF Dash F15 FX517ZR — i7-12650H,
# RTX 3070 Mobile, MUX in discrete mode). One of two bare-metal NixOS
# hosts (the other is hosts/bedroom-nixos): shared Linux core + the
# desktop flavor (niri/DMS session), plus its own GPU facts in
# ./nvidia.nix. Everything host-specific lives here; everything reusable
# lives in modules/.
{ hostName, ... }:

{
  imports = [
    ../../modules/nixos
    ../../modules/desktop
    ./nvidia.nix
    ./hardware-configuration.nix
  ];

  nixpkgs.hostPlatform = "x86_64-linux";

  # Supplied by flake.nix, which keys every entry by the hostname itself, so
  # this cannot drift from the attribute that bare `nixos-rebuild --flake
  # /etc/nixos` resolves.
  networking.hostName = hostName;

  homeEntryPoint = ../../home/marcus/desktop.nix;

  # Trusted machine: own age key, recipient of both secrets files —
  # secretsTier defaults to "full", stated here to make the choice visible.
  secretsTier = "full";

  # Do not change after initial install.
  system.stateVersion = "26.05";
}
