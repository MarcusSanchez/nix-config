# Secret Service backing for secretspec's keyring provider (headless
# WSL: the daemon starts via D-Bus activation, no desktop needed; dbus
# itself is already on via the WSL defaults).
{ pkgs, ... }:

{
  services.gnome.gnome-keyring.enable = true;

  # Also run the daemon as a proper user service instead of relying on
  # D-Bus activation alone (a bus started before a rebuild doesn't know
  # new activatable names until restarted — the service side-steps that).
  # --start makes it defer to an already-running daemon, so the two
  # startup paths can't fight.
  systemd.user.services.gnome-keyring = {
    description = "GNOME Keyring (Secret Service for secretspec)";
    wantedBy = [ "default.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.gnome-keyring}/bin/gnome-keyring-daemon --start --foreground --components=secrets";
      Restart = "on-failure";
    };
  };

  # secret-tool, for probing the keyring by hand
  environment.systemPackages = [ pkgs.libsecret ];
}
