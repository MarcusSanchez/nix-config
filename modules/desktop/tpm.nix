# TPM plumbing for tpm-fido (home/marcus/desktop/niri.nix): a virtual
# FIDO2 security key whose secrets are sealed in the TPM — the closest
# Linux gets to Windows Hello. uaccess tags grant the active seat user
# access via logind ACLs: no tss-group membership (dodges the dynamic-
# GID udev bug), no relogin needed. uhid is how tpm-fido pretends to be
# a USB HID token that browsers can see.
{ pkgs, ... }:

{
  boot.kernelModules = [ "uhid" ];

  # The rules must sort BEFORE 70-uaccess.rules (which runs the ACL
  # builtin), so they ship as a numbered package file — extraRules
  # lands in 99-local.rules, too late for the uaccess tag to matter.
  services.udev.packages = [
    (pkgs.writeTextFile {
      name = "tpm-fido-udev-rules";
      destination = "/lib/udev/rules.d/60-tpm-fido-uaccess.rules";
      text = ''
        KERNEL=="tpmrm[0-9]*", TAG+="uaccess"
        KERNEL=="uhid", SUBSYSTEM=="misc", TAG+="uaccess"
      '';
    })
  ];
}
