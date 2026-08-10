# Desktop-only additions to the base user from modules/nixos/users.nix,
# and the uinput device those additions exist for. The three-group list
# stays one definition on purpose: extraGroups lists merge across
# modules, and splitting it would reorder the merge for zero benefit
# (the networkmanager service itself is enabled in ./networking.nix).
{ config, ... }:

{
  # /dev/uinput + the uinput group, for xremap's synthetic input
  hardware.uinput.enable = true;

  # Desktop-only group memberships, layered onto the base user from
  # modules/nixos/users.nix (extraGroups lists merge): NetworkManager
  # control without polkit prompts, and evdev read + uinput write for
  # xremap (home/marcus/desktop/session-tools.nix).
  users.users.${config.identity.username}.extraGroups = [
    "networkmanager"
    "input"
    "uinput"
  ];
}
