# Secret Service backing for secretspec's keyring provider (headless
# WSL: the daemon starts via D-Bus activation, no desktop needed; dbus
# itself is already on via the WSL defaults).
{ pkgs, ... }:

{
  services.gnome.gnome-keyring.enable = true;

  # secret-tool, for probing the keyring by hand
  environment.systemPackages = [ pkgs.libsecret ];
}
