# A real-directory GOROOT for JetBrains at a stable path.
#
# Imported directly by ../wsl.nix and ../mac.nix — NOT by ./default.nix,
# because wsl-lite has no IDE pointed at it and shouldn't carry a 250MB
# copy of the Go tree.
#
# Two reasons the store path can't be handed to GoLand directly:
#
#  * On WSL, JetBrains runs on the Windows side and browses over \\wsl$,
#    which surfaces Linux symlinks as reparse points its file picker can't
#    traverse — and /run/current-system/sw is symlinks all the way down.
#    Hence `cp -RL`: the copy must contain no symlinks at all, not just at
#    the top level.
#  * On both machines, a store path is versioned — it changes on every go
#    update and the old one eventually gets collected. An SDK configured
#    at /nix/store/...-go-1.26.5 silently rots; ~/.toolchains/go doesn't.
#
# Point GoLand's SDK at ~/.toolchains/go (\\wsl$\NixOS\home\marcus\... from
# Windows) and it stays correct across upgrades. Only GOROOT needs this:
# plain executables work straight off PATH, and rustup's toolchains are
# already real directories, so RustRover is fine against ~/.rustup.
{ pkgs, lib, ... }:

let
  # stamped by store path, so a rebuild only re-copies when go changes
  goroot = "${pkgs.go}/share/go";
in
{
  home.activation.ideGoroot = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    dir="$HOME/.toolchains/go" stamp="$HOME/.toolchains/.go-stamp"
    if [ "$(cat "$stamp" 2>/dev/null)" != "${goroot}" ]; then
      run mkdir -p "$HOME/.toolchains"
      run rm -rf "$dir.new"
      run cp -RL "${goroot}" "$dir.new"
      # store trees are read-only; the IDE wants to write into GOROOT
      run chmod -R u+w "$dir.new"
      # swap in place so a half-copied tree is never visible as ~/.toolchains/go
      run rm -rf "$dir"
      run mv "$dir.new" "$dir"
      run sh -c "printf '%s' '${goroot}' > '$stamp'"
    fi
  '';
}
