# Shared Home Manager config for every machine. Per-host entry points
# (wsl.nix, mac.nix) set identity and the platform-only imports.
{ ... }:

{
  imports = [
    ./packages.nix
    ./shell.nix
    ./neovim.nix
    ./git.nix
    ./catppuccin.nix
  ];

  home.sessionVariables = {
    SUDO_EDITOR = "nvim";
  };

  # Do not change after initial install.
  home.stateVersion = "25.05";
}
