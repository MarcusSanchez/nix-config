# Security-key plumbing for WebAuthn, virtual and physical. The virtual
# half is tpm-fido (home/marcus/nixos/session-tools.nix): a FIDO2 key whose
# secrets are sealed in the TPM — the closest Linux gets to Windows
# Hello. uaccess tags grant the active seat user access via logind
# ACLs: no tss-group membership (dodges the dynamic-GID udev bug), no
# relogin needed. uhid is how tpm-fido pretends to be a USB HID token
# that browsers can see. The physical half is libfido2's rules for
# real USB tokens.
{ pkgs, ... }:

{
  boot.kernelModules = [ "uhid" ];

  # The tpm-fido rules must sort BEFORE 70-uaccess.rules (which runs
  # the ACL builtin), so they ship as a numbered package file —
  # extraRules lands in 99-local.rules, too late for the uaccess tag
  # to matter. libfido2's rules give the browser access to a physical
  # token's hidraw device, which is what makes WebAuthn passkeys work
  # (phone-as-passkey via the QR/bluetooth flow needs nothing beyond
  # bluetooth, which is on). udev orders rules by FILENAME, so the
  # package list's order is behaviorally irrelevant.
  services.udev.packages = [
    (pkgs.writeTextFile {
      name = "tpm-fido-udev-rules";
      destination = "/lib/udev/rules.d/60-tpm-fido-uaccess.rules";
      text = ''
        KERNEL=="tpmrm[0-9]*", TAG+="uaccess"
        KERNEL=="uhid", SUBSYSTEM=="misc", TAG+="uaccess"
      '';
    })
    pkgs.libfido2
  ];
}
