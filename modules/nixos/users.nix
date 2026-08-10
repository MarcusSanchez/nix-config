# The one user on the bare-metal machines, groups included. No
# hashedPassword on purpose: users.mutableUsers defaults to true, so
# the password set at install time survives rebuilds. NetworkManager
# membership pairs with ./networking.nix; input/uinput are evdev read +
# uinput write for xremap (home/marcus/nixos/session-tools.nix).
{ pkgs, ... }:

{
  # Source of truth for identity.username on the bare-metal machines
  # (the option lives in modules/common/identity.nix); the account attr
  # below stays literal beside it on purpose.
  identity.username = "marcus";

  programs.zsh.enable = true;

  # Single-user machines: wheel escalates without a password. The prompt's
  # protection is thin once an attacker already has this user's session,
  # and every rebuild goes through sudo.
  security.sudo.wheelNeedsPassword = false;

  # /dev/uinput + the uinput group, for xremap's synthetic input
  hardware.uinput.enable = true;

  users.users.marcus = {
    isNormalUser = true;
    description = "Marcus Sanchez";
    shell = pkgs.zsh;
    extraGroups = [
      "wheel"
      "networkmanager"
      "input"
      "uinput"
    ];
  };
}
