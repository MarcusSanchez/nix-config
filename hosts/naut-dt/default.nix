# Host definition: the naut PC's bare-metal side (AMD CPU, NVIDIA GPU —
# the shared driver shape in modules/nixos/nvidia.nix fits it as-is),
# dual-booted next to the Windows that hosts naut-box — same physical
# machine, two hosts in this flake, only ever one running.
# hardware-configuration.nix is the generated truth from the install
# (regenerate, don't edit).
#
# Imports are DECISIVE: modules/nixos is a pool with no aggregator, and
# this list is the whole statement of what the machine runs — the same
# desktop session as tuf-laptop, plus this box's own hardware truth.
# The two platform modules are the sops-nix/home-manager halves that
# make the sops.* and home-manager.* options exist for modules/common.
{
  inputs,
  hostName,
  pkgs,
  ...
}:

{
  imports = [
    ../../modules/common
    inputs.sops-nix.nixosModules.sops
    inputs.home-manager.nixosModules.home-manager
    ../../modules/nixos/nix.nix
    ../../modules/nixos/packages.nix
    ../../modules/nixos/users.nix
    # the desktop session, in an order that is NOT cosmetic: merged-list
    # options (systemPackages, udev.packages) order their entries by
    # module position — keep this run aligned with tuf-laptop's
    inputs.dank-material-shell.nixosModules.greeter
    ../../modules/nixos/boot.nix
    ../../modules/nixos/security.nix
    ../../modules/nixos/niri.nix
    ../../modules/nixos/greeter.nix
    ../../modules/nixos/system.nix
    ../../modules/nixos/networking.nix
    ../../modules/nixos/nix-ld.nix
    ../../modules/nixos/nvidia.nix
    ./hardware-configuration.nix
    # Secure Boot, live since install day. On a REINSTALL, comment this
    # out until `sudo sbctl create-keys` has run — enabled without keys
    # on disk, the bootloader install (and therefore nixos-install)
    # fails. Full ceremony: lanzaboote.nix header.
    ./lanzaboote.nix
  ];

  nixpkgs.hostPlatform = "x86_64-linux";

  # Supplied by flake.nix, which keys every entry by the hostname itself, so
  # this cannot drift from the attribute that bare `nixos-rebuild --flake
  # /etc/nixos` resolves.
  networking.hostName = hostName;

  homeEntryPoint = ../../home/marcus/naut-dt.nix;

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

  # Boot with only the main monitor lit: plymouth paints every active
  # connector and has no per-monitor config, so the side connectors are
  # kernel-disabled through the splash. The `d` force outlives the
  # splash — compositors do NOT resurrect a forced-off connector (the
  # session would come up single-monitor) — so the wake-side-monitors
  # oneshot below un-forces them via sysfs right before greetd, and the
  # greeter lights them (blank-filtered, per modules/nixos/greeter.nix).
  # DP-2's rotation lives in niri.outputs.kdl as transform "90"; a
  # panel_orientation param would only rotate a plymouth that never draws
  # there (and niri composing param + transform flips the image — see
  # niri.outputs.kdl). Known cosmetic cost: the brief SHUTDOWN splash
  # still paints all three (the session re-enabled them), and sideways on
  # DP-2. Host-level: this desk's connectors by name.

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

  # Arms the onboard NIC to wake this machine on a magic packet.
  #
  # Wake-on-LAN is not a persistent property of the card: the running
  # driver switches the listener on, and the shutdown path is what leaves
  # it armed. So whichever OS powered the machine down decides whether a
  # packet gets through. Windows arms it as a side effect of its own
  # shutdown (magic-packet wake is on by default in its driver, and Fast
  # Startup's hybrid hibernate preserves that state), which is why WoL
  # worked for free while Windows was the default boot entry. Linux
  # leaves ethtool's wol flag at `d`, so making NixOS the default meant
  # nothing armed the chip any more and the packets were ignored.
  #
  # A .link file is the mechanism rather than an ethtool service because
  # udev honors .link units whether or not systemd-networkd is running
  # (nixpkgs says so at the generation site) — NetworkManager owns this
  # interface, and its own wake-on-lan default of `ignore` leaves the
  # setting alone.
  #
  # Matched on MAC rather than interface name: the address is this
  # machine's hardware truth and can't be renamed out from under the
  # match the way a predictable interface name can.

  systemd.network.links."40-wol" = {
    matchConfig.MACAddress = "d8:43:ae:fa:bb:31";
    linkConfig.WakeOnLan = "magic";
  };
}
