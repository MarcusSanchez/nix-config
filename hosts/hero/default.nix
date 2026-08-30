# Host definition: hero, a dual-boot desk PC on the full modules/nixos
# stack — the 4K main with the 1440p VERTICAL on its LEFT.
#
# modules/nixos is the bare-metal world, aggregated by its default.nix.
# What stays spelled out here is this box's own hardware truth: the
# generated hardware config, Secure Boot (lanzaboote.nix), and the
# NVIDIA driver shape — a pool file OUTSIDE the aggregator (it
# hardcodes the video driver and early-KMS initrd, so a non-NVIDIA host
# must not get it).
# The two platform modules are the sops-nix/home-manager halves that
# make the sops.* and home-manager.* options exist for modules/common.
{ inputs, hostName, ... }:

{
  imports = [
    ../../modules/common
    inputs.sops-nix.nixosModules.sops
    inputs.home-manager.nixosModules.home-manager
    ../../modules/nixos
    ../../modules/nixos/nvidia.nix
    ./hardware-configuration.nix
    # Secure Boot, live since the sbctl ceremony. On a REINSTALL,
    # comment this out until `sudo sbctl create-keys` has run — enabled
    # without keys on disk, the bootloader install (and therefore
    # nixos-install) fails. Full ceremony: lanzaboote.nix header.
    ./lanzaboote.nix
    ./bluetooth.nix
    ./lianli.nix
    ./tryx.nix
    ./rgb.nix
    ./tuning.nix
  ];

  nixpkgs.hostPlatform = "x86_64-linux";

  # Supplied by flake.nix, which keys every entry by the hostname itself, so
  # this cannot drift from the attribute that bare `nixos-rebuild --flake
  # /etc/nixos` resolves.
  networking.hostName = hostName;

  homeEntryPoint = ../../home/marcus/nixos.nix;

  # Connectors that carry the greeter's sign-in UI on this machine — the
  # 4K; the portrait 1440p stays blank at the login screen.
  greeterScreens = [ "DP-3" ];

  # The release this machine was installed under — set at install time
  # to whatever the installer produces, then never changes.
  system.stateVersion = "26.05";

  # Boot with only the main monitor lit: plymouth paints every active
  # connector and has no per-monitor config, so the portrait connector
  # is kernel-disabled through the splash. The `d` force outlives the
  # splash — compositors do NOT resurrect a forced-off connector (the
  # session would come up single-monitor) — so the wake-side-monitors
  # oneshot below un-forces it via sysfs right before greetd, and the
  # greeter lights it (blank-filtered, per modules/nixos/greeter.nix
  # and greeterScreens above). The portrait's rotation lives in
  # niri.outputs.kdl as transform "270"; a panel_orientation param
  # would only rotate a plymouth that never draws there (and niri
  # composing param + transform flips the image — see
  # niri.outputs.kdl). The SHUTDOWN splash is the mirror problem — by
  # then the session has re-enabled the portrait, so
  # hide-side-monitors (below) forces it off again before the shutdown
  # splashes draw. Host-level: this desk's connectors by name.

  boot.kernelParams = [ "video=HDMI-A-1:d" ];

  systemd = {
    services.wake-side-monitors = {
      description = "Un-force the boot-disabled portrait connector before the greeter";
      wantedBy = [ "multi-user.target" ];
      before = [ "greetd.service" ];
      after = [ "plymouth-quit.service" ];
      serviceConfig.Type = "oneshot";
      script = ''
        for conn in HDMI-A-1; do
          for f in /sys/class/drm/card*-"$conn"/status; do
            [ -e "$f" ] && echo detect > "$f" || true
          done
        done
      '';
    };

    # The shutdown-side counterpart: force the portrait off again so the
    # reboot/poweroff/halt splash paints only the main monitor, the same
    # one-monitor look as boot. Ordered before the plymouth shutdown
    # services (which start once the session is gone) and after
    # display-manager, so it goes dark in the gap between the session
    # ending and the splash drawing. DefaultDependencies off is
    # mandatory for a unit that must RUN during shutdown rather than be
    # stopped by it — the same reason the plymouth-*.service units set
    # it.
    services.hide-side-monitors = {
      description = "Force the portrait connector off before the shutdown splash";
      wantedBy = [
        "reboot.target"
        "poweroff.target"
        "halt.target"
      ];
      before = [
        "plymouth-reboot.service"
        "plymouth-poweroff.service"
        "plymouth-halt.service"
      ];
      after = [ "display-manager.service" ];
      unitConfig.DefaultDependencies = false;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        for conn in HDMI-A-1; do
          for f in /sys/class/drm/card*-"$conn"/status; do
            [ -e "$f" ] && echo off > "$f" || true
          done
        done
      '';
    };
  };
}
