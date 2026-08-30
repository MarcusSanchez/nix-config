# Secure Boot: lanzaboote signs systemd-boot and every generation with
# keys generated ON THIS MACHINE (sbctl). HOST-level on purpose: only
# this machine's firmware enrolls these keys.
#
# NOT YET IMPORTED — the import in default.nix stays commented until
# `sudo sbctl create-keys` has run: with lanzaboote enabled and
# /var/lib/sbctl absent, the bootloader-install step fails, which would
# break nixos-install itself. The full ceremony below is the shape that
# worked on the predecessor desk's board; expect the same dance, but
# verify each step against this firmware:
#   sudo sbctl create-keys          # writes /var/lib/sbctl
#   (import this file, switch — generations get signed)
#   sudo sbctl verify               # everything on the ESP shows signed
#   firmware: Secure Boot -> Mode = Custom -> Key Management ->
#   "Delete all Secure Boot variables". That is the ONLY route to true
#   Setup Mode here: deleting just the PK leaves db/KEK Microsoft-owned
#   and runtime enrolment gets EPERM despite SetupMode=1. Deleting all
#   DOES drop the dbx revocation database — deliberate, restored later.
#   sudo sbctl enroll-keys --microsoft   # succeeds at runtime now
#   # --microsoft is LOAD-BEARING: it keeps Microsoft's certificates
#   # enrolled, which is what lets Windows AND the GPU's option ROM keep
#   # booting. Never enroll without it on this machine.
#   reboot, enable Secure Boot; `bootctl status` = "enabled (user)"
#   fwupdmgr update                 # restores the dbx (fwupd.nix)
{
  inputs,
  lib,
  pkgs,
  ...
}:

{
  imports = [ inputs.lanzaboote.nixosModules.lanzaboote ];

  # for debugging and the enrollment ceremony
  environment.systemPackages = [ pkgs.sbctl ];

  # lanzaboote replaces the systemd-boot module wholesale — the flavor's
  # boot.nix enables it, so force it off here; lanzaboote installs its own
  # (signed) systemd-boot underneath
  boot.loader.systemd-boot.enable = lib.mkForce false;

  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/var/lib/sbctl";
    # same ESP budget as the flavor's systemd-boot setting (1 GB ESP,
    # early-KMS initrds) — the systemd-boot copy of this option is inert
    # once that module is forced off
    configurationLimit = 10;
  };
}
