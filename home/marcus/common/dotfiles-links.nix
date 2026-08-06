# The UI-managed configs, both directions: symlinked out of the store
# into ./dotfiles/ so edits made from inside Zed / the IDEs land in the
# repo as ordinary git drift, and that drift committed + pushed at
# activation (pathspec-scoped so unrelated dirty work never rides
# along; activation never fails over git; a failed push warns and
# leaves the commit). The commit message names the machine via
# osConfig.networking.hostName — the same value on NixOS and darwin,
# both set from the flake's hostName specialArg.
#
# Imported EXPLICITLY by home/marcus/desktop/dotfiles.nix and
# home/marcus/mac/dotfiles.nix, and deliberately NOT aggregated by
# common/default.nix: the WSL boxes reach these same files through
# win-sync (wsl/dotfiles.nix) — Windows can't traverse Linux symlinks
# at all, and a second writer would fight the sync engine.
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
  osConfig,
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
          -m "chore(config): sync ui-managed files from ${osConfig.networking.hostName}" -- ${pathArgs}; then
          run ${pkgs.git}/bin/git -C "${repo}" push -q \
            || echo "config: committed, but push failed (offline/behind?) — push manually" >&2
        else
          echo "config: auto-commit failed; commit the drift manually" >&2
        fi
      fi
    fi
  '';
}
