# Aggregator for all system-level modules.
{ ... }:

{
  imports = [
    ../common
    ./nix.nix
    ./ssh.nix
    ./secrets.nix
    ./homebrew.nix
    ./users.nix
    ./macos.nix
    ./fonts.nix
    ./home-manager.nix
  ];
}
