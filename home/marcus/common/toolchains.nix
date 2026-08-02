# Rustup toolchain upkeep, both platforms — one hook, branched on isDarwin.
# (rustup itself comes from modules/common/packages.nix; RustRover refuses
# standalone toolchains, hence rustup at all — see CLAUDE.md.)
#
# Linux (WSL): rustup-downloaded toolchains are patched against one specific
# store glibc; when an upgrade bumps glibc and GC deletes the old one, every
# rust binary dies with ENOENT. Reinstall stable whenever glibc changes —
# the stamp also covers first activation on a fresh machine.
#
# Darwin: no glibc, so toolchains survive upgrades — only a first-run
# bootstrap so `cargo` and `rustc` work immediately.
#
# Both need network; if offline they warn and retry on the next activation,
# never failing it.
{ pkgs, lib, ... }:

{
  # A GOROOT at a stable path for JetBrains: ~/.toolchains/go -> the store.
  # The point is only to dodge the *versioned* store path: an SDK configured
  # at /nix/store/...-go-1.26.5 silently rots on the next go update + GC,
  # while this link is re-pointed on every switch. Only GOROOT needs it —
  # plain executables work off PATH, and rustup's toolchains are already
  # real directories, so RustRover is fine against ~/.rustup.
  #
  # History worth knowing: this was a `cp -RL` dereferenced copy until
  # 2026-07-28, because JetBrains browsing WSL over \\wsl$ used to surface
  # Linux symlinks as reparse points its file picker couldn't traverse
  # (commit 46643f1 switched links -> copies for exactly that); a link
  # verifiably works again as of 2026-07-28. If GoLand can't open the SDK from
  # Windows again, that's the reason, and the copy is in git history.
  home.file.".toolchains/go".source = "${pkgs.go}/share/go";

  home.activation.rustupToolchain = lib.hm.dag.entryAfter [ "writeBoundary" ] (
    if pkgs.stdenv.isDarwin then
      ''
        if ! ${pkgs.rustup}/bin/rustup show active-toolchain >/dev/null 2>&1; then
          if run ${pkgs.rustup}/bin/rustup toolchain install stable; then
            run ${pkgs.rustup}/bin/rustup default stable
          else
            echo "rustup: toolchain install failed (offline?); will retry on the next activation" >&2
          fi
        fi
      ''
    else
      ''
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
      ''
  );
}
