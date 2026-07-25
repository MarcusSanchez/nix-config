# Zed runs on the Windows side; its config under %USERPROFILE% and the
# copy in ./zed/ are two-way synced on activation. A base stamp in
# ~/.local/state/zed-sync tells which side changed: Windows edits are
# pulled into the repo (commit them like lazy-lock.json), repo edits are
# pushed to Windows, both-sides-changed is a loud warning and no writes.
# Symlinks are impossible across this boundary (NTFS can't point into
# WSL, Windows can't traverse Linux links), hence copies. Repo path
# hardcoded: activation must write to the working tree, not the store.
{ lib, ... }:

let
  winZedDir = "/mnt/c/Users/marcus/AppData/Roaming/Zed";
  repoZedDir = "/home/marcus/nix-config/home/marcus/wsl/zed";
in
{
  home.activation.zedConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    # store reference so edits to zed/ change the generation and re-run
    # this hook on rebuild: ${./zed}
    state="$HOME/.local/state/zed-sync"
    if [ -d "${winZedDir}" ] && [ -d "${repoZedDir}" ]; then
      run mkdir -p "$state"
      for f in settings.json keymap.json; do
        w="${winZedDir}/$f" r="${repoZedDir}/$f" b="$state/$f"
        if [ ! -f "$w" ] && [ -f "$r" ]; then
          run cp "$r" "$w" && run cp "$r" "$b"
          echo "zed: seeded $f to Windows (was missing)" >&2
        elif [ -f "$w" ] && [ ! -f "$r" ]; then
          run cp "$w" "$r" && run cp "$w" "$b"
          echo "zed: pulled $f from Windows (missing in repo) — commit it" >&2
        elif [ -f "$w" ] && [ -f "$r" ]; then
          if cmp -s "$w" "$r"; then
            cp "$w" "$b" 2>/dev/null || true
          elif [ -f "$b" ] && cmp -s "$r" "$b"; then
            run cp "$w" "$r" && run cp "$w" "$b"
            echo "zed: pulled $f from Windows — commit it in nix-config" >&2
          elif [ -f "$b" ] && cmp -s "$w" "$b"; then
            run cp "$r" "$w" && run cp "$r" "$b"
            echo "zed: pushed $f to Windows" >&2
          else
            echo "zed: CONFLICT on $f — both sides changed since last sync; nothing written." >&2
            echo "     resolve: diff '$r' '$w', make them match, then rebuild" >&2
          fi
        fi
      done
    fi
  '';
}
