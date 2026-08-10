# Secure Boot for the dual-boot desktop: lanzaboote signs systemd-boot and
# every generation with keys generated ON THIS MACHINE (sbctl), so NixOS
# boots with Secure Boot enforcing — which Windows on the other half of
# the disk needs (anti-cheat, attestation). HOST-level on purpose: the
# laptop runs with Secure Boot off and must never import this.
#
# Live: Secure Boot reads "enabled (user)"
# under this machine's own PK. On a REINSTALL, comment this import out
# until `sudo sbctl create-keys` has run — with lanzaboote enabled and
# /var/lib/sbctl absent, the bootloader-install step fails, which would
# break nixos-install itself. The full ceremony, in the shape that
# actually works on this board:
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
