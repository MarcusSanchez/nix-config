# Secure Boot: lanzaboote signs systemd-boot and every generation with
# keys generated ON THIS MACHINE (sbctl). HOST-level on purpose: only
# this machine's firmware enrolls these keys.
#
# On a REINSTALL, comment this import out in default.nix until
# `sudo sbctl create-keys` has run — with lanzaboote enabled and
# /var/lib/sbctl absent, the bootloader-install step fails, which
# would break nixos-install itself.
#
# The ceremony for THIS board (ASUS ROG Crosshair X870E Hero — per the
# official X870E BIOS manual + a confirmed same-family report; gentler
# than the predecessor MSI board's delete-everything dance):
#   sudo sbctl create-keys            # writes /var/lib/sbctl
#   (import this file, switch — sbctl verify shows everything signed)
#   BIOS: set an Administrator password AND Fast Boot off — without
#     both, runtime enrollment returns permission-denied on this
#     firmware family. The password matters only for the enrollment
#     WRITE; once keys are in NVRAM it may be removed (enforcement
#     doesn't need it — it only seals the BIOS against physical
#     tampering), and a future re-enrollment sets it again.
#   (enroll-keys may report "File is immutable" on KEK/db — that's
#     the kernel's efivarfs safety flag, not the firmware refusing:
#     `chattr -i` the two named files and re-run.)
#   BIOS: Boot -> Secure Boot -> Secure Boot Mode = Custom (Key
#     Management is hidden until this); Key Management -> "Save all
#     Secure Boot variables" to USB (the escape hatch), then
#     PK Management -> Delete key. PK-only: enters Setup Mode AND
#     preserves the dbx. ("Clear Secure Boot keys" = the full wipe,
#     fallback only; fwupdmgr update restores the dropped dbx.)
#   sudo sbctl enroll-keys --microsoft
#   # --microsoft is LOAD-BEARING: Windows' boot manager and the GPU
#   # option ROM verify against Microsoft's certs (sbctl >= 0.17
#   # enrolls the 2011 AND 2023 CA sets — Blackwell-era GOPs may be
#   # 2023-signed). NEVER --firmware-builtin on ASUS: it duplicates
#   # vendor certs and the next boot dies with a Secure Boot
#   # Violation before the boot manager.
#   BIOS: OS Type = "Windows UEFI Mode" — the actual enforcement
#     switch ("Other OS" leaves Secure Boot effectively off).
#   bootctl status = "enabled (user)"; boot Windows once (a one-time
#   BitLocker recovery prompt is normal — custom keys shift the PCRs).
#   Anti-cheat escape hatch if ever needed: BIOS "Install Default
#   Secure Boot keys" restores factory state (and unsigns NixOS out
#   of booting until re-enrollment).
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
