# Devices you plug in or pair, their firmware, and their power state.
# Several small concerns grouped by purpose — each would otherwise be a
# near-one-line file.
{ pkgs, ... }:

{
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  services = {
    # CUPS
    printing.enable = true;

    # virtual filesystems for the file manager: trash, USB drives,
    # MTP phones, network shares (nautilus in home/marcus/desktop/apps.nix)
    gvfs.enable = true;

    # firmware updates (LVFS), and specifically the UEFI dbx revocation
    # database: the firmware's true-Setup-Mode reset (the only path to custom
    # Secure Boot keys on that board) wipes dbx, and fwupd is what
    # restores it — `fwupdmgr update` offers "UEFI dbx" as a device
    fwupd.enable = true;

    # DMS reads battery state through UPower — without it the bar's
    # battery widget silently hides — and drives the control center's
    # performance/balanced/saver switch through power-profiles-daemon.
    # Both fail QUIETLY if removed.
    upower.enable = true;
    power-profiles-daemon.enable = true;

    # Wooting keyboard: the maintained udev rules (hidraw via uaccess),
    # which is what lets the web Wootility configure the keyboard over
    # WebHID from a chromium browser. Deliberately NOT
    # hardware.wooting.enable — that option also installs the wootility
    # desktop app, which the web version replaces here. Inert without
    # the hardware plugged in.
    udev.packages = [ pkgs.wooting-udev-rules ];
  };
}
