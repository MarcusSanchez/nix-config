# Two-way sync engine between a Windows-side directory and a directory in
# this repo. A base stamp in ~/.local/state/<name>-sync decides direction:
# Windows edits pull into the repo and auto-commit (chore(<name>):) +
# push, repo edits push to Windows, both-changed warns and writes
# nothing, missing files seed toward the side that lacks them. Symlinks
# are impossible across this boundary (NTFS can't point into WSL, Windows
# can't traverse Linux links), hence copies. Instantiated per config by
# zed.nix and ideavim.nix.
{ pkgs, repoDir }:
{
  name, # sync id: state dir, log prefix, chore scope
  winDir, # absolute Windows-side dir (via /mnt/c)
  repoSubdir, # repo-relative dir holding the vendored copies
  files, # file names, identical on both sides
  witness, # repo dir as a store path so edits re-run the hook
}:
''
  # store reference so edits to the synced files change the generation
  # and re-run this hook on rebuild: ${witness}
  state="$HOME/.local/state/${name}-sync"
  pulled=""
  if [ -d "${winDir}" ] && [ -d "${repoDir}/${repoSubdir}" ]; then
    run mkdir -p "$state"
    for f in ${toString files}; do
      w="${winDir}/$f" r="${repoDir}/${repoSubdir}/$f" b="$state/$f"
      if [ ! -f "$w" ] && [ -f "$r" ]; then
        run cp "$r" "$w" && run cp "$r" "$b"
        echo "${name}: seeded $f to Windows (was missing)" >&2
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
          echo "${name}: pushed $f to Windows" >&2
        else
          echo "${name}: CONFLICT on $f — both sides changed since last sync; nothing written." >&2
          echo "     resolve: diff '$r' '$w', make them match, then rebuild" >&2
        fi
      fi
    done
    # commit only the files this run actually pulled; a failed push
    # leaves the commit for the next manual push
    if [ -n "$pulled" ]; then
      paths=""
      for p in $pulled; do paths="$paths ${repoSubdir}/$p"; done
      echo "${name}: pulled$pulled from Windows — committing" >&2
      if run ${pkgs.git}/bin/git -C "${repoDir}" commit -q \
        -m "chore(${name}): sync config from the windows ui" \
        -- $paths; then
        run ${pkgs.git}/bin/git -C "${repoDir}" push -q \
          || echo "${name}: committed, but push failed (offline?) — push manually" >&2
      else
        echo "${name}: auto-commit failed; commit the ${repoSubdir} drift manually" >&2
      fi
    fi
  fi
''
