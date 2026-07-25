# Zed runs on the Windows side; its config under %USERPROFILE% and the
# copy in ./zed/ are two-way synced on activation. A base stamp in
# ~/.local/state/zed-sync tells which side changed: Windows edits are
# pulled into the repo and auto-committed (chore:) + pushed, repo edits
# are pushed to Windows, both-sides-changed is a loud warning and no
# writes. Symlinks are impossible across this boundary (NTFS can't point
# into WSL, Windows can't traverse Linux links), hence copies. Repo path
# hardcoded: activation must write to the working tree, not the store.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  winZedDir = "/mnt/c/Users/${config.windows.username}/AppData/Roaming/Zed";
  repoDir = "${config.home.homeDirectory}/nix-config";
  repoZedDir = "${repoDir}/home/marcus/wsl/zed";
in
{
  home.activation.zedConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    # store reference so edits to zed/ change the generation and re-run
    # this hook on rebuild: ${./zed}
    state="$HOME/.local/state/zed-sync"
    pulled=""
    if [ -d "${winZedDir}" ] && [ -d "${repoZedDir}" ]; then
      run mkdir -p "$state"
      for f in settings.json keymap.json; do
        w="${winZedDir}/$f" r="${repoZedDir}/$f" b="$state/$f"
        if [ ! -f "$w" ] && [ -f "$r" ]; then
          run cp "$r" "$w" && run cp "$r" "$b"
          echo "zed: seeded $f to Windows (was missing)" >&2
        elif [ -f "$w" ] && [ ! -f "$r" ]; then
          run cp "$w" "$r" && run cp "$w" "$b"
          pulled="$pulled $f"
        elif [ -f "$w" ] && [ -f "$r" ]; then
          if cmp -s "$w" "$r"; then
            cp "$w" "$b" 2>/dev/null || true
          elif [ -f "$b" ] && cmp -s "$r" "$b"; then
            run cp "$w" "$r" && run cp "$w" "$b"
            pulled="$pulled $f"
          elif [ -f "$b" ] && cmp -s "$w" "$b"; then
            run cp "$r" "$w" && run cp "$r" "$b"
            echo "zed: pushed $f to Windows" >&2
          else
            echo "zed: CONFLICT on $f — both sides changed since last sync; nothing written." >&2
            echo "     resolve: diff '$r' '$w', make them match, then rebuild" >&2
          fi
        fi
      done
      # commit is pathspec-scoped so unrelated dirty files never ride
      # along; a failed push leaves the commit for the next manual push
      if [ -n "$pulled" ]; then
        echo "zed: pulled$pulled from Windows — committing" >&2
        if run ${pkgs.git}/bin/git -C "${repoDir}" commit -q \
          -m "chore(zed): sync config from the windows ui" \
          -- home/marcus/wsl/zed/settings.json home/marcus/wsl/zed/keymap.json; then
          run ${pkgs.git}/bin/git -C "${repoDir}" push -q \
            || echo "zed: committed, but push failed (offline?) — push manually" >&2
        else
          echo "zed: auto-commit failed; commit the zed/ drift manually" >&2
        fi
      fi
    fi
  '';
}
