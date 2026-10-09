# The one human account's name, home directory, repo paths and email
# as shared options:
# assigned once per world (modules/nixos/users.nix, modules/wsl/
# users.nix, modules/darwin/users.nix, beside the account definitions
# they describe) and read by every module that would otherwise hardcode
# the name or branch on isDarwin. Deliberately NOT a rename knob — the
# assigned VALUE is an unconditional literal at every site (the attr
# names that consume it may be dynamic); this option removes
# duplication, not the account name.
#
# Guard rails: the username value must not derive from CONFIG.
# Consumers use it in dynamic attr names (users.users.${...},
# home-manager.users.${...}), and attr names are forced early in the
# module fixpoint — wrapping the assignment in mkIf or deriving it from
# other config invites infinite recursion. Two safe forms: a plain
# string literal, or a lookup keyed on the hostName SPECIALARG (as
# modules/darwin/users.nix does to give each Mac its own account) —
# specialArgs resolve outside the fixpoint, so a hostName-keyed value
# is as safe as a literal. What's forbidden is a value that reads
# config.*.
{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.identity = {
    username = lib.mkOption {
      type = lib.types.str;
      description = "The platform's single human account name, set in the platform users.nix.";
    };
    home = lib.mkOption {
      type = lib.types.str;
      default =
        (if pkgs.stdenv.hostPlatform.isDarwin then "/Users/" else "/home/") + config.identity.username;
      defaultText = lib.literalExpression ''(if isDarwin then "/Users/" else "/home/") + config.identity.username'';
      description = "The account's home directory, derived from the platform convention.";
    };
    repo = lib.mkOption {
      type = lib.types.str;
      default = "${config.identity.home}/nix-config";
      description = "Where this repo lives on every machine (what /etc/nixos and /etc/nix-darwin link to).";
    };
    dotfiles = lib.mkOption {
      type = lib.types.str;
      default = "${config.identity.repo}/home/marcus/common/dotfiles";
      description = "The UI-managed config files, linked out of the store from here.";
    };
    email = lib.mkOption {
      type = lib.types.str;
      default = "marcussanchez031@gmail.com";
      description = "The account's email, for git and the password vault.";
    };
  };
}
