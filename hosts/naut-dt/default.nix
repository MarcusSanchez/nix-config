# Host definition: the bedroom PC's bare-metal side (AMD CPU, NVIDIA
# GPU — the flavor's shared driver shape in modules/desktop/nvidia.nix
# fits it as-is), dual-booted next to the Windows that hosts
# naut-box — same physical machine, two hosts in this flake, only
# ever one running. Same desktop flavor as the TUF laptop.
# hardware-configuration.nix is the generated truth from the install
# (regenerate, don't edit).
{ hostName, ... }:

{
  imports = [
    ../../modules/nixos
    ../../modules/desktop
    ./hardware-configuration.nix
    ./wake-on-lan.nix
    # Secure Boot, live since install day. On a REINSTALL, comment this
    # out until `sudo sbctl create-keys` has run — enabled without keys
    # on disk, the bootloader install (and therefore nixos-install)
    # fails. Full ceremony: lanzaboote.nix header.
    ./lanzaboote.nix
    ./reboot-windows.nix
    ./monitors.nix
  ];

  nixpkgs.hostPlatform = "x86_64-linux";

  # Supplied by flake.nix, which keys every entry by the hostname itself, so
  # this cannot drift from the attribute that bare `nixos-rebuild --flake
  # /etc/nixos` resolves.
  networking.hostName = hostName;

  # Connectors that carry the greeter's sign-in UI on this machine — the
  # 4K in the middle; the sides stay blank at the login screen.
  greeterScreens = [ "DP-3" ];

  # Windows lives on its own ESP (the factory ~100 MB one); NixOS gets a
  # dedicated 1 GB ESP, so systemd-boot can't auto-detect Windows across
  # partitions. Pick the OS in the firmware boot menu — that's the plan of
  # record, and once Secure Boot is on it's effectively the only option:
  # the cross-ESP chainload trick (boot.loader.systemd-boot.windows) boots
  # through an unsigned EDK2 UEFI shell, which enforcing Secure Boot
  # rejects — and lanzaboote replaces the systemd-boot module anyway.

  # The release this machine was installed under — never changes.
  system.stateVersion = "26.05";
}
