# User accounts and their login shells.
{ pkgs, ... }:

{
  programs.zsh.enable = true;

  # Several darwin options (homebrew, system.defaults, ...) act on one user.
  system.primaryUser = "marcussanchez";

  users.users.marcussanchez = {
    name = "marcussanchez";
    home = "/Users/marcussanchez";
    shell = pkgs.zsh;
  };
}
