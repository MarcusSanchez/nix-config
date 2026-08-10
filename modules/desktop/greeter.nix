# The whole login-screen story: DMS's greetd-based greeter, the
# greeter-only monitor layout (side monitors off, one sign-in UI), and
# the two pieces that put the avatar on it (accounts-daemon + the
# AccountsService icon seed). Greeter/display-manager changes ship via
# `nixos-rebuild boot` + reboot, not `switch` — switch would kill the
# live session out from under the user.
{ pkgs, ... }:

let
  # The stock greeter puts a full sign-in UI on EVERY monitor
  # (GreeterSurface.qml hardcodes `model: Quickshell.screens`; unlike
  # the lock screen there is no screenPreferences filter). This derived
  # copy of the same dms-shell filters that list to greeterScreens:
  # listed connectors get the UI, the rest get NO surface — and a
  # surface-less output shows the greeter compositor's black
  # background, monitors on. Same clean blank as the lock screen,
  # instead of the old cut-the-signal approach (output off), which
  # dropped the side monitors into no-signal standby. The list is
  # BAKED into the QML at build time — an env var does not survive the
  # greetd -> script -> niri ->
  # quickshell inheritance chain. Safety: single-screen machines and a
  # filter that matches nothing both fall back to every screen — no
  # config state can produce a greeter with nowhere to type. The
  # substitution uses --replace-fail on purpose: a DMS update that
  # moves the line breaks the BUILD, never the login screen.
  greeterScreens = [
    "DP-3"
    "eDP-1"
  ];
  greeterShell =
    pkgs.runCommand "dms-shell-greeter-screens"
      {
        base = pkgs.dms-shell;
        wantList = builtins.toJSON greeterScreens;
      }
      ''
        cp -r --no-preserve=mode "$base" $out
        substituteInPlace $out/share/quickshell/dms/Modules/Greetd/GreeterSurface.qml \
          --replace-fail 'model: Quickshell.screens' \
          "model: (function () { var want = $wantList; if (Quickshell.screens.length <= 1) return Quickshell.screens; var f = Quickshell.screens.filter(function (s) { return want.indexOf(s.name) >= 0; }); return f.length > 0 ? f : Quickshell.screens; })()"
      '';
in
{
  services = {
    displayManager = {
      # DMS's greetd-based greeter — the login screen wears the same
      # Material theme as the session shell. configHome points it at
      # the user's DMS settings so wallpaper/colors stay in sync; the
      # package is DERIVED from the same nixpkgs dms-shell the session
      # uses (see greeterShell above), so greeter and shell still can't
      # drift apart in version.
      dms-greeter = {
        enable = true;
        compositor.name = "niri";
        configHome = "/home/marcus";
        package = greeterShell;
        # without this the greeter's niri/quickshell startup output
        # goes to the VT — a flash of yellow WARN lines on every
        # logout/login
        logs.save = true;
      };

      # No auto-login: boot lands on the greeter. The boot-lock loop in
      # niri.config.kdl keys on session id 1, which the greeter session
      # occupies in this mode — so it stays dormant and a greeter login
      # enters the desktop unlocked. Flipping autoLogin back on
      # restores the boot-to-lock flow with no other changes needed.
      defaultSession = "niri";
    };

    # DMS persists the profile picture through AccountsService; without
    # the daemon, `dms ipc call profile setImage` claims SUCCESS but
    # only sets session memory and the avatar vanishes on reboot.
    accounts-daemon.enable = true;
  };

  # The greeter runs niri with its OWN generated config — the session's
  # niri.config.kdl reaches only the session — so unaided it drives every monitor
  # untransformed at scale 1: sideways on a vertical monitor, tiny on
  # the 4K. The DMS
  # launcher appends `include "/etc/greetd/niri_overrides.kdl"` to its
  # generated config when that file exists; hand it the session's
  # connector-keyed output layout unmodified (which screens carry the
  # sign-in UI is greeterShell's baked list above), plus one
  # greeter-only extra: idle management. None exists at the greeter
  # otherwise (the session's belongs to DMS, which only runs after
  # login), so a remote wake-on-lan used to leave every monitor burning
  # at the sign-in screen all night — swayidle powers the panels off
  # after five idle minutes and any input wakes them (niri behavior).
  # Store copy — updates on rebuild, not on save like the session's
  # symlink.
  environment.etc."greetd/niri_overrides.kdl".source =
    pkgs.runCommand "greeter-niri-overrides.kdl"
      {
        base = ../../home/marcus/common/dotfiles/niri.outputs.kdl;
        extra = pkgs.writeText "greeter-idle.kdl" ''

          // greeter-only: dark screens after 5 idle minutes (any input
          // wakes them) — the sign-in screen otherwise never sleeps
          spawn-at-startup "${pkgs.swayidle}/bin/swayidle" "-w" "timeout" "300" "niri msg action power-off-monitors"
        '';
      }
      ''
        cat "$base" "$extra" > $out
      '';

  # The greeter's avatar probe checks, in order: its own cache,
  # /var/lib/AccountsService/icons/<user>, then ~/.face — but the
  # dms-greeter user cannot read ~/.face through the 0700 home dir, and
  # AccountsService only gets an icons/ copy when the avatar is set
  # imperatively through the UI. Seed that copy declaratively from the
  # same asset home/marcus/desktop/appearance.nix links to ~/.face, so
  # a fresh machine's login screen has the face too. C+ overwrites, so
  # an asset change propagates at the next boot/activation instead of
  # being blocked by the existing copy.
  systemd.tmpfiles.rules = [
    "C+ /var/lib/AccountsService/icons/marcus 0644 root root - ${../../home/marcus/desktop/assets/avatar-spaceman.png}"
  ];
}
