# Shared Home Manager config for every machine. Per-world entry points
# (../wsl.nix, ../darwin.nix, ../nixos.nix) set home.stateVersion (a
# per-machine birth certificate — it can't live in a shared file since
# machines were installed under different releases) and the
# platform-only imports.
{ ... }:

{
  imports = [
    ./packages.nix
    ./shell.nix
    ./neovim.nix
    ./git.nix
    ./toolchains.nix
    ./secrets.nix
  ];
}
