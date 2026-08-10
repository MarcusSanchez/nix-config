# The one user on every WSL box. No hashedPassword on purpose:
# users.mutableUsers defaults to true, so the password set at install
# time survives rebuilds.
{ pkgs, ... }:

{
  # Source of truth for identity.username on the WSL machines (the
  # option lives in modules/common/identity.nix); the account attr
  # below stays literal beside it on purpose.
  identity.username = "marcus";

  programs.zsh.enable = true;

  # Single-user machines: wheel escalates without a password. The prompt's
  # protection is thin once an attacker already has this user's session,
  # and every rebuild goes through sudo. (NixOS-WSL already sets this;
  # stating it keeps it uniform with the bare-metal boxes.)
  security.sudo.wheelNeedsPassword = false;

  users.users.marcus = {
    isNormalUser = true;
    description = "Marcus Sanchez";
    shell = pkgs.zsh;
    extraGroups = [ "wheel" ];
  };
}
