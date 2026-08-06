# Power services a DE would silently provide: DMS reads battery state
# through UPower — without it the bar's battery widget silently hides —
# and drives the control center's performance/balanced/saver switch
# through power-profiles-daemon. Both came with GNOME/Plasma and left
# with them.
{ ... }:

{
  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;
}
