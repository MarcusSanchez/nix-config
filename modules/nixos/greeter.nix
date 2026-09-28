# The login screen: DMS's greetd-based greeter, recreated after a brief
# SDDM interlude (Ryoku's theme couldn't rotate the portrait — SDDM's
# compositor knows nothing of the session's machine-local monitor pins —
# and had no per-screen story; this greeter solved both long ago). The
# greeter is its own niri + quickshell world and hands off to whatever
# wayland session is picked — Ryoku's niri by default. Greeter/display-
# manager changes ship via `nixos-rebuild boot` + reboot, not `switch` —
# switch would kill the live session out from under the user.
#
# Module and package both come from nixpkgs (the greeter split into its
# own dank-greeter repo upstream, nixpkgs adopted both halves).
# accounts-daemon, which persists the avatar below, is enabled in
# ./ryoku.nix with the rest of the desktop's system services.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  # The stock greeter puts a full sign-in UI on EVERY monitor
  # (GreeterSurface.qml hardcodes `model: Quickshell.screens`; unlike
  # the lock screen there is no screenPreferences filter). This build
  # of the same dms-greeter filters that list to the host's
  # greeterScreens option (declared below, assigned in hosts/):
  # listed connectors get the UI, the rest get NO surface — a
  # surface-less output that stays on shows the greeter compositor's
  # black background. Whether a side monitor stays on-but-blank or
  # loses its signal entirely is the host's greeterOutputs call (an
  # `off` block cuts it; the session's own compositor lights it again
  # at login). The list is
  # BAKED in at build time — an env var does not survive the
  # greetd -> script -> niri -> quickshell inheritance chain, and the
  # greeter's QML rides INSIDE the Go binary (`make sync-shell`
  # embeds quickshell/ before the build), so the filter is patched
  # into the source rather than the installed tree. Safety:
  # single-screen machines and a filter that matches nothing both
  # fall back to every screen — no config state can produce a greeter
  # with nowhere to type. The substitution uses --replace-fail on
  # purpose: an update that moves the line breaks the BUILD, never
  # the login screen.
  greeterShell = pkgs.dms-greeter.overrideAttrs (old: {
    env = (old.env or { }) // {
      wantList = builtins.toJSON config.greeterScreens;
    };
    postPatch = (old.postPatch or "") + ''
      substituteInPlace quickshell/Modules/Greetd/GreeterSurface.qml \
        --replace-fail 'model: Quickshell.screens' \
        "model: (function () { var want = $wantList; if (Quickshell.screens.length <= 1) return Quickshell.screens; var f = Quickshell.screens.filter(function (s) { return want.indexOf(s.name) >= 0; }); return f.length > 0 ? f : Quickshell.screens; })()"
    '';
  });
in
{

  options.greeterScreens = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    example = [ "DP-3" ];
    description = ''
      Connector names that carry the greeter's sign-in UI; every other
      screen shows the greeter compositor's blank background. The empty
      default, single-screen machines and a no-match filter all fall
      back to every screen — no value can produce a greeter with
      nowhere to type.
    '';
  };

  # The session's monitor layout lives machine-local in Ryoku's
  # ~/.config/niri/monitors_user.kdl, which the greeter's own niri
  # cannot read (wrong user, and system config must not reach into a
  # home) — so each host restates its output blocks here, the same
  # per-machine-VALUE shape as greeterScreens. Unset, the greeter runs
  # every monitor untransformed at scale 1: sideways on a vertical
  # monitor, tiny on a 4K — exactly the SDDM failure this greeter
  # replaced.
  options.greeterOutputs = lib.mkOption {
    type = lib.types.lines;
    default = "";
    example = ''
      output "DP-3" {
          scale 1.75
      }
    '';
    description = ''
      niri output blocks (connector-keyed kdl) for the greeter's
      compositor — keep them in step with the machine's
      monitors_user.kdl.
    '';
  };

  config = {
    services.displayManager = {
      # DMS's greetd-based greeter. configHome points it at the user's
      # config for wallpaper/colors when present; the package is the
      # screen-filtered dms-greeter build above.
      dms-greeter = {
        enable = true;
        compositor.name = "niri";
        configHome = config.identity.home;
        package = greeterShell;
        # without this the greeter's niri/quickshell startup output
        # goes to the VT — a flash of yellow WARN lines on every
        # logout/login
        logs.save = true;
      };

      # No auto-login: boot lands on the greeter, and a login enters
      # the picked wayland session — Ryoku's niri by default.
      defaultSession = "niri";
    };

    # The greeter runs niri with its OWN generated config, so unaided it
    # drives every monitor untransformed at scale 1. The DMS launcher
    # appends `include "/etc/greetd/niri_overrides.kdl"` to its
    # generated config when that file exists; hand it the host's
    # greeterOutputs plus one greeter-only extra: idle management. None
    # exists at the greeter otherwise (the session's belongs to the
    # shell, which only runs after login), so a remote wake-on-lan used
    # to leave every monitor burning at the sign-in screen all night —
    # swayidle powers the panels off after five idle minutes and any
    # input wakes them (niri behavior).
    environment.etc."greetd/niri_overrides.kdl".text = ''
      ${config.greeterOutputs}
      // greeter-only: dark screens after 5 idle minutes (any input
      // wakes them) — the sign-in screen otherwise never sleeps
      spawn-at-startup "${pkgs.swayidle}/bin/swayidle" "-w" "timeout" "300" "niri msg action power-off-monitors"
    '';

    # The greeter's avatar probe checks, in order: its own cache,
    # /var/lib/AccountsService/icons/<user>, then ~/.face — but the
    # dms-greeter user cannot read ~/.face through the 0700 home dir,
    # and AccountsService only gets an icons/ copy when the avatar is
    # set imperatively through a UI. Seed that copy declaratively, so a
    # fresh machine's login screen has the face too. C+ overwrites, so
    # an asset change propagates at the next boot/activation instead of
    # being blocked by the existing copy.
    systemd.tmpfiles.rules = [
      "C+ /var/lib/AccountsService/icons/${config.identity.username} 0644 root root - ${./assets/avatar-spaceman.png}"
    ];
  };
}
