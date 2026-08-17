# Toolchain upkeep, both platforms: rustup (one hook, branched on
# isDarwin) plus a stable GOROOT for JetBrains. (rustup itself comes from
# modules/common/packages.nix; RustRover refuses standalone toolchains,
# hence rustup at all — see CLAUDE.md.)
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
#
# Components are ensured separately from the toolchain, and unconditionally,
# because a toolchain that already exists can still be missing them: rustup
# installs SHIMS for the whole tool family into PATH, rust-analyzer included,
# and a shim whose component is absent does not fall through to anything else
# — it exits with "unavailable for the active toolchain". So the editor's LSP
# never starts, while mason's own perfectly good rust-analyzer sits further
# down PATH and never gets reached. A fresh `toolchain install` does not carry
# hand-added components either, so the WSL glibc repair above would drop them.
{ pkgs, lib, ... }:

let
  # rust-analyzer: the LSP itself. rust-src: what lets it resolve into the
  # standard library (go-to-definition on Vec, etc.).
  rustComponents = "rust-analyzer rust-src";

  ensureRustComponents = ''
    for c in ${rustComponents}; do
      if ! ${pkgs.rustup}/bin/rustup component list --installed 2>/dev/null | grep -q "^$c"; then
        run ${pkgs.rustup}/bin/rustup component add "$c" \
          || echo "rustup: could not add $c (offline?); will retry on the next activation" >&2
      fi
    done
  '';
in

{
  home.activation.rustupToolchain = lib.hm.dag.entryAfter [ "writeBoundary" ] (
    if pkgs.stdenv.hostPlatform.isDarwin then
      ''
        if ! ${pkgs.rustup}/bin/rustup show active-toolchain >/dev/null 2>&1; then
          if run ${pkgs.rustup}/bin/rustup toolchain install stable; then
            run ${pkgs.rustup}/bin/rustup default stable
          else
            echo "rustup: toolchain install failed (offline?); will retry on the next activation" >&2
          fi
        fi
        ${ensureRustComponents}
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
        ${ensureRustComponents}
      ''
  );

  # A GOROOT at a stable path for JetBrains: ~/.toolchains/go -> the store.
  # The point is only to dodge the *versioned* store path: an SDK configured
  # at /nix/store/...-go-1.26.5 silently rots on the next go update + GC,
  # while this link is re-pointed on every switch. Only GOROOT needs it —
  # plain executables work off PATH, and rustup's toolchains are already
  # real directories, so RustRover is fine against ~/.rustup.
  home.file.".toolchains/go".source = "${pkgs.go}/share/go";
}
