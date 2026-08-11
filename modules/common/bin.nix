# The repo's operational scripts (bin/*), on PATH everywhere — thin
# wrappers that run the LIVE working-tree scripts, so editing bin/
# stays rebuild-free, the same philosophy as the dotfile links. Each
# wrapper execs its script from the repo root (the scripts resolve
# their pieces via git rev-parse); the caller's shell keeps its own
# directory untouched, as any child process guarantees. One derivation
# carries all of them because a store path's own NAME cannot contain
# the colon the script names use — the files inside it can.
#
# Also carries the reboot:windows command, hostname-gated: only the
# dual-boot desktop has a Windows half to reboot into.
{
  config,
  lib,
  pkgs,
  ...
}:

{
  environment.systemPackages = [
    (pkgs.runCommand "repo-bin" { } ''
      mkdir -p $out/bin
      ${lib.concatMapStrings
        (name: ''
            cat > "$out/bin/${name}" <<'WRAP'
          #!/usr/bin/env bash
          # the cd is invisible to the caller: this wrapper is a child
          # process, and a child's working directory never touches the
          # invoking shell's
          cd ${config.identity.home}/nix-config || exit 1
          exec ./bin/${name} "$@"
          WRAP
            chmod +x "$out/bin/${name}"
        '')
        [
          "age:place"
          "config:check"
          "secrets:drop"
          "secrets:edit"
          "secrets:status"
        ]
      }
    '')
  ]
  # One-shot boot into the Windows half of the dual-boot: sets the
  # firmware's BootNext to the Windows Boot Manager entry and reboots.
  # BootNext applies to exactly one boot — the boot after, Windows
  # returns to the default order (NixOS, instantly, no menu) — so this
  # never changes BootOrder and needs no BIOS visit and no F11. The
  # Windows entry is looked up by label at runtime rather than a
  # hardcoded Boot#### (Windows updates have been known to recreate
  # their entry under a new number).
  ++ lib.optionals (config.networking.hostName == "naut-dt") [
    # named like the repo scripts (verb:noun); the colon forces the same
    # file-inside-a-derivation shape as repo-bin above
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
