# The Windows account that owns this WSL distro — set per machine in the
# HM entry point (wsl.nix). Consumers build /mnt/c/Users/<name> paths
# from it (dotfiles.nix).
{ lib, ... }:

{
  options.windows.username = lib.mkOption {
    type = lib.types.str;
    description = "Windows username owning /mnt/c/Users/<name>.";
  };
}
