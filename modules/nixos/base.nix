# The floor every NixOS-WSL box in this flake stands on: nix itself, the
# user, WSL integration, the basics for unpacking and running foreign
# binaries, and the Home Manager bridge (each host points it at its own
# entry point via homeEntryPoint). Dev-machine extras are layered on top
# by ./default.nix — a module added here lands on EVERY WSL host.
{ ... }:

{
  imports = [
    ./nix.nix
    ./packages.nix
    ./nix-ld.nix
    ./users.nix
    ./wsl.nix
    ./home-manager.nix
  ];
}
