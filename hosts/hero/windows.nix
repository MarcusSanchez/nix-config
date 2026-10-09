# The dual-boot's other half: the Windows volume, readable at
# /mnt/windows, and the one-shot reboot into Windows. HOST-level: the
# partition UUID and the firmware boot entry are this machine's.
#
# The mount is READ-ONLY on purpose: Linux never writes a filesystem
# Windows believes it owns. Files flow one way — drop them anywhere on
# C:\ from the Windows side, copy them out of /mnt/windows here; the
# reverse has no local path (Windows cannot read this ext4), so anything
# bound for Windows travels over the network. uid/gid make the files the
# user's without chmod theater (the uid is pinned in
# modules/nixos/users.nix); nofail keeps boot unbothered if the
# partition ever vanishes.
#
# reboot:windows sets the firmware's BootNext to the Windows Boot
# Manager entry and reboots. BootNext applies to exactly one boot — the
# boot after, the machine returns to the default order (NixOS,
# instantly, no menu) — so BootOrder never changes and no BIOS visit is
# needed. The entry is looked up by label at runtime rather than a
# hardcoded Boot####: Windows updates can recreate it under a new
# number. Named like the repo scripts (verb:noun); the colon forces the
# file-inside-a-derivation shape modules/common/bin.nix uses.
{ config, pkgs, ... }:

{
  fileSystems."/mnt/windows" = {
    device = "/dev/disk/by-uuid/64523010522FE590";
    fsType = "ntfs3";
    options = [
      "ro"
      "nofail"
      "uid=${toString config.users.users.${config.identity.username}.uid}"
      "gid=${toString config.users.groups.users.gid}"
    ];
  };

  environment.systemPackages = [
    (pkgs.runCommand "reboot-windows" { } ''
      mkdir -p $out/bin
      install -m755 ${pkgs.writeShellScript "reboot-windows" ''
        set -euo pipefail
        id=$(${pkgs.efibootmgr}/bin/efibootmgr \
          | ${pkgs.gnused}/bin/sed -n 's/^Boot\([0-9A-Fa-f]\{4\}\)\*\{0,1\}[[:space:]]*Windows Boot Manager.*/\1/p' \
          | head -n1)
        if [ -z "$id" ]; then
          echo "reboot:windows: no 'Windows Boot Manager' entry in efibootmgr output" >&2
          exit 1
        fi
        sudo ${pkgs.efibootmgr}/bin/efibootmgr --bootnext "$id" >/dev/null
        echo "BootNext -> Windows Boot Manager ($id); rebooting..."
        sudo systemctl reboot
      ''} "$out/bin/reboot:windows"
    '')
  ];
}
