# The one human account's name and home directory as a shared option:
# assigned once per platform (modules/nixos/users.nix, modules/darwin/
# users.nix, beside the account definitions they describe) and read by
# every module that would otherwise hardcode the name or branch on
# isDarwin. Deliberately NOT a rename knob — the users.users attr names
# at the two definition sites stay literal on purpose; this option
# removes duplication, not the account name.
#
# Guard rails: the username assignments must stay unconditional string
# literals. Consumers use the value in dynamic attr names
# (users.users.${...}, home-manager.users.${...}), and attr names are
# forced early in the module fixpoint — wrapping the assignment in mkIf
# or deriving it from other config invites infinite recursion. If that
# ever bites, the escape hatch is a literal attr name at the consumer
# while values keep reading config.identity.*.
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
      default = (if pkgs.stdenv.isDarwin then "/Users/" else "/home/") + config.identity.username;
      defaultText = lib.literalExpression ''(if isDarwin then "/Users/" else "/home/") + config.identity.username'';
      description = "The account's home directory, derived from the platform convention.";
    };
  };
}
