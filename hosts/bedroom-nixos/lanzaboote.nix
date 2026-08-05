# Secure Boot for the dual-boot desktop: lanzaboote signs systemd-boot and
# every generation with keys generated ON THIS MACHINE (sbctl), so NixOS
# boots with Secure Boot enforcing — which Windows on the other half of
# the disk needs (anti-cheat, attestation). HOST-level on purpose: the
# laptop runs with Secure Boot off and must never import this.
#
# NOT imported until the keys exist (see the commented import in
# ./default.nix): with lanzaboote enabled and /var/lib/sbctl absent, the
# bootloader-install step fails — which would break nixos-install itself.
# The README's "Enable Secure Boot" section is the ceremony:
#   sudo sbctl create-keys          # writes /var/lib/sbctl
#   (uncomment the import, nh os switch — generations get signed)
#   sudo sbctl verify               # everything on the ESP shows signed
#   reboot into firmware, put Secure Boot into Setup Mode. MSI board:
#   F7 for Advanced, Settings -> Advanced -> Windows OS Configuration ->
#   Secure Boot, Mode = Custom, Key Management, delete the PK only.
#   NOT "delete all Secure Boot variables" (drops dbx) and NOT "restore
#   factory keys" (undoes Setup Mode). bootctl status should then read
#   "Secure Boot: disabled (setup)".
#   sudo sbctl enroll-keys --microsoft
#   # --microsoft is LOAD-BEARING: it keeps Microsoft's certificates
#   # enrolled, which is what lets Windows AND the GPU's option ROM keep
#   # booting. Never enroll without it on this machine.
#   reboot, enable Secure Boot; `bootctl status` = "enabled (user)"
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
