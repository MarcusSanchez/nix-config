# User accounts and their login shells.
{
  config,
  pkgs,
  hostName,
  ...
}:

let
  # Source of truth for identity.username on darwin (the option lives in
  # modules/common/identity.nix). marcus is the norm; the Air is the one
  # legacy exception until its factory reset unifies it — at which point
  # this map empties and every Mac is marcus. Keyed on the hostName
  # SPECIALARG, not config: it resolves outside the module fixpoint, so
  # the dynamic users.users attr name below is safe from the recursion
  # the identity.nix guard rail warns about (which only bites when the
  # name derives from config). home-manager.nix already keys its
  # users.${...} the same way.
  username = { macbook-air = "marcussanchez"; }.${hostName} or "marcus";
in
{
  identity.username = username;

  programs.zsh.enable = true;

  # Several darwin options (homebrew, system.defaults, ...) act on one user.
  system.primaryUser = config.identity.username;

  users.users.${username} = {
    name = username;
    home = config.identity.home;
    shell = pkgs.zsh;
  };
}
