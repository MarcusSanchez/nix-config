# One-shot boot into the Windows half of the dual-boot: sets the
# firmware's BootNext to the Windows Boot Manager entry and reboots.
# BootNext applies to exactly one boot — the boot after Windows
# returns to the default order (NixOS, instantly, no menu) — so this
# never changes BootOrder and needs no BIOS visit and no F11. The
# Windows entry is looked up by label at runtime rather than a
# hardcoded Boot#### (Windows updates have been known to recreate
# their entry under a new number).
{ pkgs, ... }:

{
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "reboot-windows" ''
      set -euo pipefail
      id=$(${pkgs.efibootmgr}/bin/efibootmgr \
        | ${pkgs.gnused}/bin/sed -n 's/^Boot\([0-9A-Fa-f]\{4\}\)\*\{0,1\}[[:space:]]*Windows Boot Manager.*/\1/p' \
        | head -n1)
      if [ -z "$id" ]; then
        echo "reboot-windows: no 'Windows Boot Manager' entry in efibootmgr output" >&2
        exit 1
      fi
      sudo ${pkgs.efibootmgr}/bin/efibootmgr --bootnext "$id" >/dev/null
      echo "BootNext -> Windows Boot Manager ($id); rebooting..."
      sudo systemctl reboot
    '')
  ];
}
