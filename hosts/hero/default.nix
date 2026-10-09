# Host definition: hero, a dual-boot desk PC on the full modules/nixos
# stack — the 4K main with the 1440p VERTICAL on its LEFT.
#
# modules/nixos is the bare-metal world, aggregated by its default.nix.
# What stays spelled out at host level is this box's own hardware
# truth: the generated hardware config; the NVIDIA driver shape — a
# pool file OUTSIDE the aggregator (it hardcodes the video driver and
# early-KMS initrd, so a non-NVIDIA host must not get it); the sibling
# concern files (Secure Boot, the combo card's bluetooth backport, the
# case and cooler screens, RGB, sensors/tuning — each explains
# itself, including the dual-boot's Windows side and the one-monitor
# boot splash); and, inline below, the WoL arming.
# The two platform modules are the sops-nix/home-manager halves that
# make the sops.* and home-manager.* options exist for modules/common.
{
  inputs,
  hostName,
  ...
}:

{
  imports = [
    ../../modules/common
    inputs.sops-nix.nixosModules.sops
    inputs.home-manager.nixosModules.home-manager
    ../../modules/nixos
    ../../modules/nixos/nvidia.nix
    ./hardware-configuration.nix
    # Secure Boot. On a REINSTALL, comment this out until `sudo sbctl
    # create-keys` has run — lanzaboote.nix's header has the ceremony.
    ./lanzaboote.nix
    ./bluetooth.nix
    ./lianli.nix
    ./tryx.nix
    ./rgb.nix
    ./tuning.nix
    ./splash.nix
    ./windows.nix
  ];

  nixpkgs.hostPlatform = "x86_64-linux";

  # Supplied by flake.nix, which keys every entry by the hostname itself, so
  # this cannot drift from the attribute that bare `nixos-rebuild --flake
  # /etc/nixos` resolves.
  networking.hostName = hostName;

  homeEntryPoint = ../../home/marcus/nixos.nix;

  # Which connectors carry the greeter's sign-in UI, and the greeter
  # compositor's output layout: only the 4K runs at the login screen —
  # the portrait's SIGNAL is cut (`off`) until the session's niri
  # lights it from niri.outputs.kdl (a fresh compositor inherits
  # nothing from the greeter's). Keep the DP-3 block in step with that
  # file's.
  greeterScreens = [ "DP-3" ];
  greeterOutputs = ''
    output "HDMI-A-1" {
        off
    }

    output "DP-3" {
        mode "3840x2160@240.000"
        scale 1.75
    }
  '';

  # The release this machine was installed under — set at install time
  # to whatever the installer produces, then never changes.
  system.stateVersion = "26.05";

  # Arms the wired NIC to wake this machine on a magic packet. WoL is
  # not a persistent property of the card: the running driver switches
  # the listener on, and the shutdown path is what leaves it armed —
  # whichever OS powered the machine down decides whether a packet
  # gets through. A .link file rather than an ethtool service because
  # udev honors .link units whether or not systemd-networkd runs, and
  # NetworkManager's own wake-on-lan default of `ignore` leaves the
  # setting alone. Matched on MAC — hardware truth that can't be
  # renamed out from under the match; this board carries a second
  # ethernet port (…:53, one below), deliberately left unarmed while
  # nothing is plugged into it. The waker is any LAN device sending a
  # broadcast magic packet for this MAC (an L2 send — it cannot cross
  # the tailnet, which is L3 and has no address for a sleeping box).
  systemd.network.links."40-wol" = {
    matchConfig.MACAddress = "08:bf:b8:23:74:54";
    linkConfig.WakeOnLan = "magic";
  };

  # Upstream systemd wart (261.2): on warm boots the initrd udevd
  # deadlocks at stop after a clean worker shutdown and gets
  # SIGKILLed, and the main udevd's recovery delays input coldplug —
  # the login screen renders while keyboard and mouse stay dead for
  # tens of seconds. Cold boots are unaffected. After a systemd
  # bump, `journalctl -b | grep stop-sigterm` coming back empty on a
  # warm reboot means the wedge is gone: remove this comment and the
  # specialisation below (a boot-menu entry that adds udev debug
  # logging).
  specialisation.udev-debug.configuration = {
    boot.kernelParams = [
      "rd.udev.log_level=debug"
      "udev.log_level=debug"
    ];
  };
}
