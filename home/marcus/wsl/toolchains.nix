# Rustup repair for WSL.
{ pkgs, lib, ... }:

{
  # rustup-downloaded toolchains are patched against one specific store
  # glibc; when an upgrade bumps glibc and GC deletes the old one, every
  # rust binary dies with ENOENT. Reinstall stable whenever glibc changes
  # (also covers first activation on a fresh machine). Needs network; if
  # offline it warns and retries on the next activation.
  home.activation.rustupToolchain = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    stamp="$HOME/.rustup/.nix-glibc-stamp"
    if [ "$(cat "$stamp" 2>/dev/null)" != "${pkgs.glibc}" ]; then
      run ${pkgs.rustup}/bin/rustup toolchain uninstall stable || true
      if run ${pkgs.rustup}/bin/rustup toolchain install stable; then
        run ${pkgs.rustup}/bin/rustup default stable
        run sh -c "printf '%s' '${pkgs.glibc}' > '$stamp'"
      else
        echo "rustup: toolchain install failed (offline?); rust stays broken until the next successful activation" >&2
      fi
    fi
  '';
}
