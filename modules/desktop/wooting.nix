# Wooting keyboard access: the maintained udev rules (hidraw via
# uaccess for the active seat user), which is what lets the web
# Wootility configure the keyboard over WebHID from a chromium browser.
# Deliberately NOT hardware.wooting.enable — that option also installs
# the wootility desktop app, which the web version replaces here.
# Inert without the hardware plugged in.
{ pkgs, ... }:

{
  services.udev.packages = [ pkgs.wooting-udev-rules ];
}
