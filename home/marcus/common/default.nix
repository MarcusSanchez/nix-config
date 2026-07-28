# Shared Home Manager config for every machine. Per-host entry points
# (../wsl.nix, ../mac.nix, ../wsl-lite.nix) set identity and the
# platform-only imports from ../wsl/ and ../mac/.
{ ... }:

{
  imports = [
    ./packages.nix
    ./shell.nix
    ./neovim.nix
    ./git.nix
    ./catppuccin.nix
    ./comma.nix
    ./goroot.nix
  ];

  # Do not change after initial install.
  home.stateVersion = "25.05";
}
