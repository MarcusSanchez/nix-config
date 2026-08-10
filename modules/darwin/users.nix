# User accounts and their login shells.
{ config, pkgs, ... }:

{
  # Source of truth for identity.username on darwin (the option lives in
  # modules/common/identity.nix); the account attr below stays literal
  # beside it on purpose.
  identity.username = "marcussanchez";

  programs.zsh.enable = true;

  # Several darwin options (homebrew, system.defaults, ...) act on one user.
  system.primaryUser = config.identity.username;

  users.users.marcussanchez = {
    name = config.identity.username;
    home = config.identity.home;
    shell = pkgs.zsh;
  };
}
