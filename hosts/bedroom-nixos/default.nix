# Host definition: the bedroom PC's bare-metal side (AMD CPU, NVIDIA
# GPU), dual-booted next to the Windows that hosts bedroom-wsl —
# same physical machine, two hosts in this flake, only ever one running.
# Same desktop flavor as the TUF laptop; its own GPU facts in
# ./nvidia.nix. hardware-configuration.nix is the generated truth from
# the install (regenerate, don't edit).
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
    # fails. Full ceremony: lanzaboote.nix header.
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
  # connector and has no per-monitor config, so the side connectors are
  # kernel-disabled through the splash. The `d` force outlives the
  # splash — compositors do NOT resurrect a forced-off connector
  # (the session would come up single-monitor) — so the
  # wake-side-monitors oneshot below un-forces them via sysfs right
  # before greetd, and the greeter lights them (blank-filtered, per
  # modules/desktop/greeter.nix). DP-2's rotation lives in
  # niri.outputs.kdl as transform "90"; a panel_orientation param
  # would only rotate a plymouth that never draws there (and niri
  # composing param + transform flips the image — see
  # niri.outputs.kdl). Known cosmetic cost: the brief SHUTDOWN
  # splash still paints all three (the session re-enabled them), and
  # sideways on DP-2. Host-level: this desk's connectors by name.
  boot.kernelParams = [
    "video=DP-1:d"
    "video=DP-2:d"
  ];

  systemd.services.wake-side-monitors = {
    description = "Un-force the boot-disabled side monitor connectors before the greeter";
    wantedBy = [ "multi-user.target" ];
    before = [ "greetd.service" ];
    after = [ "plymouth-quit.service" ];
    serviceConfig.Type = "oneshot";
    script = ''
      for conn in DP-1 DP-2; do
        for f in /sys/class/drm/card*-"$conn"/status; do
          [ -e "$f" ] && echo detect > "$f" || true
        done
      done
    '';
  };

  # The release this machine was installed under — never changes.
  system.stateVersion = "26.05";
}
