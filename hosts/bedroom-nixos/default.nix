# Host definition: the bedroom PC's bare-metal side (AMD 9800X3D,
# RTX 5080), dual-booted next to the Windows that hosts bedroom-wsl —
# same physical machine, two hosts in this flake, only ever one running.
# Same desktop flavor as the TUF laptop; its own GPU facts in
# ./nvidia.nix. PREPARED AHEAD OF INSTALL: hardware-configuration.nix is
# a placeholder until the installer regenerates it (see its header), and
# the README's dual-boot runbook is the install path.
{ hostName, ... }:

{
  imports = [
    ../../modules/nixos
    ../../modules/desktop
    ./nvidia.nix
    ./hardware-configuration.nix
  ];

  nixpkgs.hostPlatform = "x86_64-linux";

  # Supplied by flake.nix, which keys every entry by the hostname itself, so
  # this cannot drift from the attribute that bare `nixos-rebuild --flake
  # /etc/nixos` resolves.
  networking.hostName = hostName;

  homeEntryPoint = ../../home/marcus/desktop.nix;

  # Trusted machine: own age key, recipient of both secrets files —
  # enrolled at install day (README "Enrolling a trusted machine").
  secretsTier = "full";

  # Windows lives on its own ESP (the factory ~100 MB one); NixOS gets a
  # dedicated 1 GB ESP, so systemd-boot can't auto-detect Windows across
  # partitions. The firmware boot menu works day one; for a menu entry
  # inside systemd-boot instead, uncomment and fill in the device handle
  # (type `map` in an EFI shell — it's the FsN handle of the Windows ESP):
  # boot.loader.systemd-boot.windows."11".efiDeviceHandle = "HD0b";

  # Set at install time to the ISO's release — verify before first switch.
  system.stateVersion = "26.05";
}
