# Host definition: the bedroom PC's bare-metal side (AMD 9800X3D,
# RTX 5080), dual-booted next to the Windows that hosts bedroom-wsl —
# same physical machine, two hosts in this flake, only ever one running.
# Same desktop flavor as the TUF laptop; its own GPU facts in
# ./nvidia.nix. Installed 2026-08-06 via the README's dual-boot
# runbook; hardware-configuration.nix is the generated truth from that
# install (regenerate, don't edit).
{ hostName, ... }:

{
  imports = [
    ../../modules/nixos
    ../../modules/desktop
    ./nvidia.nix
    ./hardware-configuration.nix
    ./wake-on-lan.nix
    # Secure Boot, live since install day. On a REINSTALL, comment this
    # out until `sudo sbctl create-keys` has run — enabled without keys
    # on disk, the bootloader install (and therefore nixos-install)
    # fails. Full ceremony: lanzaboote.nix header + README "Secure Boot".
    ./lanzaboote.nix
    ./reboot-windows.nix
  ];

  nixpkgs.hostPlatform = "x86_64-linux";

  # Supplied by flake.nix, which keys every entry by the hostname itself, so
  # this cannot drift from the attribute that bare `nixos-rebuild --flake
  # /etc/nixos` resolves.
  networking.hostName = hostName;

  homeEntryPoint = ../../home/marcus/desktop.nix;

  # Trusted machine: own age key (generated on-box at install, enrolled
  # in .sops.yaml), recipient of both secrets files.
  secretsTier = "full";

  # Windows lives on its own ESP (the factory ~100 MB one); NixOS gets a
  # dedicated 1 GB ESP, so systemd-boot can't auto-detect Windows across
  # partitions. Pick the OS in the firmware boot menu — that's the plan of
  # record, and once Secure Boot is on it's effectively the only option:
  # the cross-ESP chainload trick (boot.loader.systemd-boot.windows) boots
  # through an unsigned EDK2 UEFI shell, which enforcing Secure Boot
  # rejects — and lanzaboote replaces the systemd-boot module anyway.

  # Boot with only the main monitor lit: plymouth paints every active
  # connector and has no per-monitor config, so the side connectors
  # are kernel-disabled until a compositor turns them on (the greeter's
  # niri does, per niri.outputs.kdl — where DP-2's rotation now lives
  # as transform "90" again; the old panel_orientation param's only
  # consumer was plymouth-on-DP-2, which no longer exists).
  # Host-level because it names this desk's connectors.
  boot.kernelParams = [
    "video=DP-1:d"
    "video=DP-2:d"
  ];

  # The release this machine was installed under — never changes.
  system.stateVersion = "26.05";
}
