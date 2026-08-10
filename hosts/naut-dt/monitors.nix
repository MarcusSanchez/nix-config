# Boot with only the main monitor lit: plymouth paints every active
# connector and has no per-monitor config, so the side connectors are
# kernel-disabled through the splash. The `d` force outlives the
# splash — compositors do NOT resurrect a forced-off connector (the
# session would come up single-monitor) — so the wake-side-monitors
# oneshot below un-forces them via sysfs right before greetd, and the
# greeter lights them (blank-filtered, per modules/desktop/greeter.nix).
# DP-2's rotation lives in niri.outputs.kdl as transform "90"; a
# panel_orientation param would only rotate a plymouth that never draws
# there (and niri composing param + transform flips the image — see
# niri.outputs.kdl). Known cosmetic cost: the brief SHUTDOWN splash
# still paints all three (the session re-enabled them), and sideways on
# DP-2. Host-level: this desk's connectors by name.
{ ... }:

{
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
}
