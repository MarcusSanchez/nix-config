# Aggregator for all system-level modules.
{ ... }:

{
  imports = [
    ./nix.nix
    ./packages.nix
    ./homebrew.nix
    ./users.nix
    ./macos.nix
    ./fonts.nix
    ./home-manager.nix
    ./claude-code.nix
  ];
}
