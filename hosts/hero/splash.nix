# Boot and shutdown splash on the main monitor only. plymouth paints
# every active connector and has no per-monitor config, so the portrait
# connector is kernel-disabled through the splash. The `d` force
# outlives the splash — compositors do not resurrect a forced-off
# connector, so the session would come up single-monitor — hence the
# oneshot that un-forces it via sysfs right before the display manager,
# which lights it. The portrait's rotation is niri's transform "270" in
# home/marcus/common/dotfiles/niri.outputs.kdl; a panel_orientation
# kernel param would only rotate a plymouth that never draws there (and
# niri composing param + transform flips the image). The shutdown
# splash is the mirror problem: by then the session has re-enabled the
# portrait, so a second oneshot forces it off again before the shutdown
# splashes draw. HOST-level: this desk's connector by name.
{ ... }:

let
  portrait = "HDMI-A-1";
  # `detect` re-enables a forced-off connector, `off` forces it off
  setConnector = state: ''
    for f in /sys/class/drm/card*-${portrait}/status; do
      [ -e "$f" ] && echo ${state} > "$f" || true
    done
  '';
in
{
  boot.kernelParams = [ "video=${portrait}:d" ];

  systemd.services = {
    # greetd aliases display-manager.service, so the ordering holds for
    # any display manager
    wake-side-monitors = {
      description = "Un-force the boot-disabled portrait connector before the greeter";
      wantedBy = [ "multi-user.target" ];
      before = [ "display-manager.service" ];
      after = [ "plymouth-quit.service" ];
      serviceConfig.Type = "oneshot";
      script = setConnector "detect";
    };

    # Ordered before the plymouth shutdown services (which start once
    # the session is gone) and after display-manager, so the portrait
    # goes dark in the gap between the session ending and the splash
    # drawing. DefaultDependencies off is mandatory for a unit that must
    # RUN during shutdown rather than be stopped by it — the same reason
    # the plymouth-*.service units set it.
    hide-side-monitors = {
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
      script = setConnector "off";
    };
  };
}
