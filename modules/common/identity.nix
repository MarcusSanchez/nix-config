# The one human account's name and home directory as a shared option:
# assigned once per platform (modules/nixos/users.nix, modules/darwin/
# users.nix, beside the account definitions they describe) and read by
# every module that would otherwise hardcode the name or branch on
# isDarwin. Deliberately NOT a rename knob — the users.users attr names
# at the two definition sites stay literal on purpose; this option
# removes duplication, not the account name.
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
  };
}
