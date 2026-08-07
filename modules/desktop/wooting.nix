# Wooting keyboard access for Wootility: the option ships Wooting's
# maintained udev rules (hidraw access via uaccess for the active seat
# user), replacing the /etc/udev/rules.d hand-install their setup page
# prescribes for other distros. Inert without the hardware plugged in.
{ ... }:

{
  hardware.wooting.enable = true;
}
