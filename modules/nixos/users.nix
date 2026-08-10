# The one user, on every NixOS host. No hashedPassword on purpose:
# users.mutableUsers defaults to true, so the password set at install
# time survives rebuilds. Desktop-only group memberships (networkmanager,
# input/uinput for xremap) are added by modules/desktop, not here.
{ pkgs, ... }:

{
  # Source of truth for identity.username on NixOS (the option lives in
  # modules/common/identity.nix); the account attr below stays literal
  # beside it on purpose.
  identity.username = "marcus";

  programs.zsh.enable = true;

  # Single-user machines: wheel escalates without a password. The prompt's
  # protection is thin once an attacker already has this user's session,
  # and every rebuild goes through sudo. (NixOS-WSL already sets this on
  # the WSL boxes; stating it here makes it uniform everywhere.)
  security.sudo.wheelNeedsPassword = false;

  users.users.marcus = {
    isNormalUser = true;
    description = "Marcus Sanchez";
    shell = pkgs.zsh;
    extraGroups = [ "wheel" ];
  };
}
