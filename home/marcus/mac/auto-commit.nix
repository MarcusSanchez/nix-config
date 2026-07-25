# UI-managed configs living in the repo working tree (zed settings/keymap
# file symlinks, shared .ideavimrc): commit and push their drift at activation.
# Pathspec-scoped so unrelated dirty work never rides along; activation
# never fails over git; a failed push (offline, clone behind origin)
# warns and leaves the commit for the next manual push.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  repo = "${config.home.homeDirectory}/nix-config";
  paths = [
    "home/marcus/common/zed"
    "home/marcus/common/ideavim"
  ];
  pathArgs = lib.concatMapStringsSep " " (p: "\"${p}\"") paths;
in
{
  home.activation.configAutoCommit = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ -d "${repo}/.git" ]; then
      run ${pkgs.git}/bin/git -C "${repo}" add -A -- ${pathArgs} || true
      if ! ${pkgs.git}/bin/git -C "${repo}" diff --cached --quiet -- ${pathArgs}; then
        echo "config: ui drift — committing" >&2
        if run ${pkgs.git}/bin/git -C "${repo}" commit -q \
          -m "chore(config): sync ui-managed files from the mac" -- ${pathArgs}; then
          run ${pkgs.git}/bin/git -C "${repo}" push -q \
            || echo "config: committed, but push failed (offline/behind?) — push manually" >&2
        else
          echo "config: auto-commit failed; commit the drift manually" >&2
        fi
      fi
    fi
  '';
}
