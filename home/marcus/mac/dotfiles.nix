# The UI-managed configs on the mac, both directions: symlinked out of
# the store into the shared ../common/dotfiles/ so edits land in the repo
# as git drift, and that drift committed + pushed at activation
# (pathspec-scoped so unrelated dirty work never rides along; activation
# never fails over git; a failed push warns and leaves the commit). WSL reaches the same files through win-sync
# (wsl/dotfiles.nix) — Windows can't traverse Linux symlinks at all.
#
# Per-FILE links, never a whole-dir one: ~/.config/zed stays a real
# directory, so the prompt-library db and themes Zed writes beside its
# config land there instead of in the repo. Single-file links have one
# caveat — an atomic save can replace the link with a plain file, but HM
# re-links and hm-backups it on the next switch.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  repo = "${config.home.homeDirectory}/nix-config";
  dotfiles = "${repo}/home/marcus/common/dotfiles";
  link = name: config.lib.file.mkOutOfStoreSymlink "${dotfiles}/${name}";
  paths = [ "home/marcus/common/dotfiles" ];
  pathArgs = lib.concatMapStringsSep " " (p: "\"${p}\"") paths;
in
{
  xdg.configFile."zed/settings.json".source = link "zed.settings.json";
  xdg.configFile."zed/keymap.json".source = link "zed.keymap.json";

  home.file.".ideavimrc".source = link ".ideavimrc";

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
