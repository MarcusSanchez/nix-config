# A GOROOT at a stable path for JetBrains: ~/.toolchains/go -> the store.
# One symlink, so every machine carries it whether or not an IDE is
# attached.
#
# The point is only to dodge the *versioned* store path: an SDK configured
# at /nix/store/...-go-1.26.5 silently rots on the next go update + GC,
# while this link is re-pointed on every switch. Only GOROOT needs it —
# plain executables work off PATH, and rustup's toolchains are already
# real directories, so RustRover is fine against ~/.rustup.
#
# History worth knowing: this was a `cp -RL` dereferenced copy until
# 2026-07-28, because JetBrains browsing WSL over \\wsl$ used to surface
# Linux symlinks as reparse points its file picker couldn't traverse
# (commit 46643f1 switched links -> copies for exactly that). Marcus
# confirmed a link works now. If GoLand ever can't open the SDK from
# Windows again, that's the reason, and the copy is in git history.
{ pkgs, ... }:

{
  home.file.".toolchains/go".source = "${pkgs.go}/share/go";
}
