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
    # Uncomment AFTER `sudo sbctl create-keys` on the installed machine —
    # enabled without keys on disk, the bootloader install (and therefore
    # nixos-install) fails. Full ceremony: lanzaboote.nix header + README
    # "Enable Secure Boot".
    ./lanzaboote.nix
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

  # Set at install time to the ISO's release — verify before first switch.
  system.stateVersion = "26.05";
}
