# The compositor: niri (scrollable-tiling Wayland compositor) with its
# session Exec routed through systemd-cat, plus the GNOME/GTK portals
# programs.niri wires up. User-side pieces (DMS shell, niri config) live
# in home/marcus/nixos/ (niri.nix + dms.nix); the greeter that enters this session
# is ./greeter.nix.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  # niri, with its session Exec routed through systemd-cat: greetd
  # starts sessions with stdio inherited from the VT, so niri's and
  # quickshell's startup/shutdown output otherwise flashes as raw text
  # during every login/logout handoff. journalctl -t niri-session reads
  # it back. symlinkJoin only rewrites the .desktop — no niri rebuild.
  niriQuiet = pkgs.symlinkJoin {
    name = "niri-quiet";
    paths = [ pkgs.niri ];
    postBuild = ''
      rm $out/share/wayland-sessions/niri.desktop
      {
        echo "[Desktop Entry]"
        echo "Name=niri"
        echo "Comment=A scrollable-tiling Wayland compositor (session logs to the journal)"
        echo "Exec=${pkgs.systemd}/bin/systemd-cat --identifier=niri-session $out/bin/niri-session"
        echo "Type=Application"
        echo "DesktopNames=niri"
      } > $out/share/wayland-sessions/niri.desktop
    '';
    passthru.providedSessions = [ "niri" ];
  };

  # The second session the greeter's menu offers where noctalia is
  # installed (home/marcus/nixos/noctalia.nix): same compositor, same
  # systemd-cat routing, plus NIRI_SHELL=noctalia — which the shell
  # spawn line in niri.config.kdl reads to start noctalia instead of
  # DMS. Selecting plain "niri" remains the DMS session.
  noctaliaSession =
    pkgs.runCommand "niri-noctalia-session"
      {
        passthru.providedSessions = [ "niri-noctalia" ];
      }
      ''
        mkdir -p $out/share/wayland-sessions
        {
          echo "[Desktop Entry]"
          echo "Name=niri (noctalia)"
          echo "Comment=niri with the noctalia shell (session logs to the journal)"
          echo "Exec=${pkgs.systemd}/bin/systemd-cat --identifier=niri-session ${pkgs.coreutils}/bin/env NIRI_SHELL=noctalia ${niriQuiet}/bin/niri-session"
          echo "Type=Application"
          echo "DesktopNames=niri"
        } > $out/share/wayland-sessions/niri-noctalia.desktop
      '';
in
{
  # The module also enables gnome-keyring, which provides
  # org.freedesktop.secrets — secretspec's keyring provider and
  # libsecret's secret-tool talk to it.
  programs.niri = {
    enable = true;
    package = niriQuiet;
  };

  # backs HM's dconf.settings and gsettings for GTK apps (arrived with
  # GNOME before, left with it)
  programs.dconf.enable = true;

  # the noctalia session entry, only where the shell itself is
  # installed — the hostname list mirrors the gate in
  # home/marcus/nixos/noctalia.nix (a session entry without the shell
  # would greet its picker into a shell-less niri). EMPTY while the
  # noctalia files sit archived off the import path.
  services.displayManager.sessionPackages = lib.mkIf (builtins.elem config.networking.hostName [
  ]) [ noctaliaSession ];

  # swaylock is the session's fallback locker (DMS's is primary); it
  # authenticates via PAM, and without this entry unlocking fails.
  # Pairs with programs.swaylock in home/marcus/nixos/niri.nix.
  security.pam.services.swaylock = { };
}
