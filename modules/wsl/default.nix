# Aggregator for the WSL flavor — everything that only makes sense when
# NixOS runs inside Windows. Every WSL host imports this alongside
# modules/nixos (the shared core). tailscale.nix is deliberately NOT
# here: it stays a host-level import because only ONE WSL distro per
# Windows PC can be a tailnet node — see that file.
{ ... }:

{
  imports = [
    ./nix.nix
    ./packages.nix
    ./nix-ld.nix
    ./users.nix
    ./wsl.nix
    ./keyring.nix
    ./autoupgrade.nix
  ];
}
