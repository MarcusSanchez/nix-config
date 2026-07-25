# Zed runs on the Windows side; its config lives under %USERPROFILE%,
# where the UI edits it. Windows is the source of truth: on activation,
# UI changes are pulled INTO ./zed/ (they show up in git status — commit
# them like lazy-lock.json). The repo only writes toward Windows when a
# file is missing there (fresh machine). Symlinks are impossible across
# this boundary (NTFS can't point into WSL, Windows can't traverse Linux
# links), hence copies. Repo path hardcoded: activation must reach the
# working tree, not the store.
{ lib, ... }:

let
  winZedDir = "/mnt/c/Users/marcus/AppData/Roaming/Zed";
  repoZedDir = "/home/marcus/nix-config/home/marcus/wsl/zed";
in
{
  home.activation.zedConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ -d "${winZedDir}" ] && [ -d "${repoZedDir}" ]; then
      for f in settings.json keymap.json; do
        if [ -f "${winZedDir}/$f" ]; then
          if ! cmp -s "${winZedDir}/$f" "${repoZedDir}/$f"; then
            run cp "${winZedDir}/$f" "${repoZedDir}/$f"
            echo "zed: pulled $f from Windows — commit it in nix-config" >&2
          fi
        elif [ -f "${repoZedDir}/$f" ]; then
          run cp "${repoZedDir}/$f" "${winZedDir}/$f"
          echo "zed: seeded $f to Windows (was missing)" >&2
        fi
      done
    fi
  '';
}
