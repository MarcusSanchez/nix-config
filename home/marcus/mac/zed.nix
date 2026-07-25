# ~/.config/zed is a symlink into this repo's working tree
# (mkOutOfStoreSymlink, deliberately not a store path): Zed's UI writes
# land directly in mac/zed/ as git drift — commit like lazy-lock.json.
# Whole-directory link on purpose; per-file links can be clobbered by
# atomic saves. The WSL machine can't do any of this (Windows can't
# traverse Linux symlinks) — it uses win-sync.nix copies instead.
#
# One-time on a machine with an existing ~/.config/zed: move its
# contents into mac/zed/ here, delete the now-empty directory, rebuild.
{
  config,
  lib,
  pkgs,
  ...
}:

{
  xdg.configFile."zed".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nix-config/home/marcus/mac/zed";

  # UI edits accumulate as working-tree drift (see symlink above);
  # commit and push them at activation, pathspec-scoped so unrelated
  # dirty work never rides along. A failed push (offline, clone behind
  # origin) warns and leaves the commit for the next manual push.
  home.activation.zedAutoCommit = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    repo="${config.home.homeDirectory}/nix-config"
    sub="home/marcus/mac/zed"
    if [ -d "$repo/.git" ]; then
      run ${pkgs.git}/bin/git -C "$repo" add -A -- "$sub" || true
      if ! ${pkgs.git}/bin/git -C "$repo" diff --cached --quiet -- "$sub"; then
        echo "zed: config drift — committing" >&2
        if run ${pkgs.git}/bin/git -C "$repo" commit -q \
          -m "chore(zed): sync config from the mac ui" -- "$sub"; then
          run ${pkgs.git}/bin/git -C "$repo" push -q \
            || echo "zed: committed, but push failed (offline/behind?) — push manually" >&2
        else
          echo "zed: auto-commit failed; commit $sub manually" >&2
        fi
      fi
    fi
  '';
}
