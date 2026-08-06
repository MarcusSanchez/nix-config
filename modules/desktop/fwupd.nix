# Firmware updates from LVFS — and specifically the UEFI dbx revocation
# database: MSI's true-Setup-Mode reset (the only path to custom Secure
# Boot keys on that board) wipes dbx, and fwupd is what restores it —
# `fwupdmgr update` offers "UEFI dbx" as a device.
{ ... }:

{
  services.fwupd.enable = true;
}
