# Secure Boot: lanzaboote signs systemd-boot and every generation with
# keys generated ON THIS MACHINE (sbctl). HOST-level on purpose: only
# this machine's firmware enrolls these keys.
#
# On a REINSTALL, comment this import out in default.nix until
# `sudo sbctl create-keys` has run — with lanzaboote enabled and
# /var/lib/sbctl absent, the bootloader-install step fails, which
# would break nixos-install itself.
#
# The ceremony for THIS board (ASUS ROG Crosshair X870E Hero), as
# actually performed 2026-08-30 — NOT the documented sbctl path:
# this firmware DISCARDS runtime-written key variables at POST (the
# AMI NVRAM_Verify tamper check) and quietly reinstates its factory
# keys, so `sbctl enroll-keys` "succeeds" and then the first enforced
# boot hits a Secure Boot Violation against a db that no longer holds
# the key. Setup Mode, PK deletion and the admin-password dance are
# all dead ends here. The path the firmware DOES honor is its own
# Key Management UI, appending one cert to the factory db:
#   sudo sbctl create-keys            # writes /var/lib/sbctl
#   (import this file, switch — sbctl verify shows everything signed)
#   openssl x509 -in /var/lib/sbctl/keys/db/db.pem \
#     -outform DER -out /boot/hero-db.cer
#   # the BIOS file browser reads any FAT partition, named HD(<part#>,
#   # GPT,...) — this disk has TWO ESPs (p1 Windows', p7 NIXBOOT);
#   # copying the cert to both roots makes every entry a right answer
#   BIOS: Boot -> Secure Boot -> Secure Boot Mode = Custom (reveals
#     Key Management) -> DB Management -> Append Key -> pick the cert
#     -> format "Public Key Certificate". Touch NOTHING else: PK/KEK/
#     db stay factory (MS 2011 + 2023 certs already present — Windows,
#     the GPU option ROM and MS-signed dbx updates all keep working,
#     and the near-stock policy is friendlier to anti-cheat), and the
#     dbx is never dropped, so no fwupd restore dance.
#   BIOS: OS Type = "Windows UEFI Mode" — the actual enforcement
#     switch ("Other OS" leaves Secure Boot effectively off). F10.
#   bootctl status = "enabled (user)"; efi-readvar -v db shows the
#   appended "Database Key" as the last list. No BIOS admin password
#   needed for this path.
#   Escape hatch if a boot ever violates: OS Type back to "Other OS"
#   (or Key Management -> "Install Default Secure Boot keys" for a
#   full factory reset of the policy — which drops the appended cert).
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
