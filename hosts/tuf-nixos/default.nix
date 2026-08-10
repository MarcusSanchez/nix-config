# Host definition: the TUF laptop (discrete NVIDIA GPU, MUX in
# discrete mode — the flavor's shared driver shape in
# modules/desktop/nvidia.nix fits it as-is). One of two bare-metal
# NixOS hosts (the other is hosts/bedroom-nixos): shared Linux core +
# the desktop flavor (niri/DMS session). Everything host-specific lives
# here; everything reusable lives in modules/.
{ hostName, ... }:

{
  imports = [
    ../../modules/nixos
    ../../modules/desktop
    ./hardware-configuration.nix
  ];

  nixpkgs.hostPlatform = "x86_64-linux";

  # Supplied by flake.nix, which keys every entry by the hostname itself, so
  # this cannot drift from the attribute that bare `nixos-rebuild --flake
  # /etc/nixos` resolves.
  networking.hostName = hostName;

  # Connectors that carry the greeter's sign-in UI on this machine — the
  # built-in panel (external monitors, when plugged in, stay blank at
  # the login screen).
  greeterScreens = [ "eDP-1" ];

  # Do not change after initial install.
  system.stateVersion = "26.05";
}
