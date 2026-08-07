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

  # Tell the kernel the DP-2 monitor is physically mounted rotated
  # (left edge up), as a DRM panel-orientation property. Plymouth
  # honors it (upright boot/shutdown splash) and so does niri — which
  # COMPOSES it with any config transform rather than preferring one,
  # so niri.outputs.kdl's DP-2 block carries NO transform: this
  # property is the single source of rotation for splash, greeter and
  # session alike. Host-level because it names this desk's connector.
  boot.kernelParams = [ "video=DP-2:panel_orientation=left_side_up" ];

  # The release this machine was installed under — never changes.
  system.stateVersion = "26.05";
}
