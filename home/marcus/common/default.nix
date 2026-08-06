# Shared Home Manager config for every machine. Per-host entry points
# (../wsl.nix, ../mac.nix, ../wsl-lite.nix, ../desktop.nix) set identity,
# home.stateVersion (a per-machine birth certificate — it can't live in a
# shared file since machines were installed under different releases),
# and the platform-only imports.
{ ... }:

{
  imports = [
    ./packages.nix
    ./cli-tools.nix
    ./shell.nix
    ./neovim.nix
    ./git.nix
    ./toolchains.nix
    ./secrets.nix
  ];
}
