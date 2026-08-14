# Aggregator for the bare-metal world: everything a NixOS machine of
# this fleet runs, in one import. The desktop stack is included because
# every bare-metal host here IS a desktop — the day a headless one
# appears, this file splits into a base half and a ./desktop.nix half,
# with the information that split needs actually in hand.
#
# nvidia.nix is deliberately NOT here, exactly like modules/wsl's
# networking.nix: it hardcodes services.xserver.videoDrivers and the
# early-KMS initrd list at normal priority, so a host without a discrete
# NVIDIA GPU would be broken by importing it. GPU vendor is per-machine
# hardware truth, so it stays a pool file the host imports itself.
{
  imports = [
    ./nix.nix
    ./packages.nix
    ./users.nix

    # the desktop session
    ./boot.nix
    ./security.nix
    ./niri.nix
    ./greeter.nix
    ./system.nix
    ./networking.nix
    ./nix-ld.nix
  ];
}
