# The whole login-screen story: DMS's greetd-based greeter, the
# greeter-only monitor layout (side monitors off, one sign-in UI), and
# the two pieces that put the avatar on it (accounts-daemon + the
# AccountsService icon seed). Greeter/display-manager changes ship via
# `nixos-rebuild boot` + reboot, not `switch` — switch would kill the
# live session out from under the user.
{ pkgs, ... }:

{
  services = {
    displayManager = {
      # DMS's greetd-based greeter — the login screen wears the same
      # Material theme as the session shell. configHome points it at
      # the user's DMS settings so wallpaper/colors stay in sync; package
      # pinned to the same nixpkgs dms-shell the session uses so
      # greeter and shell can't drift apart.
      dms-greeter = {
        enable = true;
        compositor.name = "niri";
        configHome = "/home/marcus";
        package = pkgs.dms-shell;
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
  # the 4K (bedroom-nixos's first greeter did exactly that). The DMS
  # launcher appends `include "/etc/greetd/niri_overrides.kdl"` to its
  # generated config when that file exists; hand it the session's
  # connector-keyed output layout, with one greeter-only change: the
  # bedroom side monitors are switched OFF. Quickshell renders a full
  # sign-in stack on every screen it sees and no DMS setting hides it
  # (verified against GreetdSettings in the packaged source) — with the
  # sides off, the login UI exists only on the middle monitor and the
  # session wakes the sides on login. Built by filtering those blocks
  # out of the shared file and appending explicit `off` blocks, because
  # niri's merge behavior for duplicate output sections is undocumented.
  # Store copy — updates on rebuild, not on save like the session's
  # symlink. Inert on the laptop (no such connectors).
  environment.etc."greetd/niri_overrides.kdl".source =
    pkgs.runCommand "greeter-niri-overrides.kdl"
      {
        base = ../../home/marcus/common/dotfiles/niri.outputs.kdl;
        extra = pkgs.writeText "greeter-side-monitors-off.kdl" ''

          // greeter-only: sides dark, sign-in lives on the 4K alone
          output "DP-2" {
              off
          }

          output "DP-1" {
              off
          }
        '';
      }
      ''
        awk '
          /^output "(DP-1|DP-2)" \{/ { skip = 1; next }
          skip && /^\}/ { skip = 0; next }
          !skip
        ' "$base" > $out
        cat "$extra" >> $out
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
