{ config, pkgs, ...}:

{
  imports = [ ];

  environment.systemPackages = with pkgs; [
    gcc
    curl
    unzip
    gzip
    gnutar
    tree

    nodejs_latest

    go
    gopls

    rustup # all you need for rust development
  ];

  programs.zsh.enable = true;

  users.users.marcus.isNormalUser = true;
  users.users.marcus.shell = pkgs.zsh;

  networking.hostName = "nixos";

  system.stateVersion = "25.05";

  # Automatic updating
  system.autoUpgrade.enable = true;
  system.autoUpgrade.dates = "weekly";

  # Automatic cleanup
  nix.gc.automatic = true;
  nix.gc.dates = "daily";
  nix.gc.options = "--delete-older-than 10d";
  nix.settings.auto-optimise-store = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config = {
    allowUnfree = true;
    allowUnfreePredicate = true;
  };
}
