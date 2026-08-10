# The compositor: niri (scrollable-tiling Wayland compositor) with its
# session Exec routed through systemd-cat, plus the GNOME/GTK portals
# programs.niri wires up. User-side pieces (DMS shell, niri config) live
# in home/marcus/desktop/ (niri.nix + dms.nix); the greeter that enters this session
# is ./greeter.nix.
{ pkgs, ... }:

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

  # swaylock is the session's fallback locker (DMS's is primary); it
  # authenticates via PAM, and without this entry unlocking fails.
  # Pairs with programs.swaylock in home/marcus/desktop/niri.nix.
  security.pam.services.swaylock = { };
}
