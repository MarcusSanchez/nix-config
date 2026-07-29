# Aggregator for all system-level modules. Both WSL hosts import this —
# they differ only in hostname and which home entry point they point
# homeEntryPoint at, since what makes the dev box a dev box lives in the
# home layer (the Windows dotfile syncing), not here.
{ ... }:

{
  imports = [
    ../common
    ./nix.nix
    ./packages.nix
    ./nix-ld.nix
    ./ssh.nix
    ./terminfo.nix
    ./secrets.nix
    ./keyring.nix
    ./users.nix
    ./wsl.nix
    ./home-manager.nix
  ];
}
