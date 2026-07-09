# Real-directory toolchain copies for Windows-side IDEs, plus rustup repair.
#
# JetBrains on Windows browses WSL files over \\wsl$, which exposes Linux
# symlinks as reparse points its file picker can't traverse. Toolchains the
# IDE needs as a *directory* (GOROOT) must therefore be real dereferenced
# copies, not links into /nix/store. Plain executables (node, buf, ...)
# work fine straight from /run/current-system/sw/bin, and rustup's
# toolchains are already real directories, so RustRover works against
# ~/.rustup as-is.
{ pkgs, lib, ... }:

let
  ideToolchains = {
    go = "${pkgs.go}/share/go"; # GOROOT
  };
in
{
  home.activation.ideToolchains = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    sync_toolchain() {
      local name="$1" src="$2"
      local dir="$HOME/.toolchains/$name" stamp="$HOME/.toolchains/.$name-stamp"
      [ "$(cat "$stamp" 2>/dev/null)" = "$src" ] && return 0
      if [ -n "''${DRY_RUN:-}" ]; then
        echo "would sync $dir from $src"
        return 0
      fi
      rm -rf "$dir.new"
      cp -rL "$src" "$dir.new"
      chmod -R u+w "$dir.new"
      rm -rf "$dir"
      mv "$dir.new" "$dir"
      printf '%s' "$src" > "$stamp"
    }
    mkdir -p "$HOME/.toolchains"
    ${lib.concatStrings (
      lib.mapAttrsToList (name: src: ''
        sync_toolchain ${name} ${src}
      '') ideToolchains
    )}
  '';

  # rustup-downloaded toolchains are patched against one specific store
  # glibc; when an upgrade bumps glibc and GC deletes the old one, every
  # rust binary dies with ENOENT. Reinstall stable whenever glibc changes
  # (also covers first activation on a fresh machine). Needs network; if
  # offline it warns and retries on the next activation.
  home.activation.rustupToolchain = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    stamp="$HOME/.rustup/.nix-glibc-stamp"
    if [ -z "''${DRY_RUN:-}" ] && [ "$(cat "$stamp" 2>/dev/null)" != "${pkgs.glibc}" ]; then
      ${pkgs.rustup}/bin/rustup toolchain uninstall stable >/dev/null 2>&1 || true
      if ${pkgs.rustup}/bin/rustup toolchain install stable; then
        ${pkgs.rustup}/bin/rustup default stable
        printf '%s' "${pkgs.glibc}" > "$stamp"
      else
        echo "rustup: toolchain install failed (offline?); rust stays broken until the next successful activation" >&2
      fi
    fi
  '';
}
