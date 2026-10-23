# Neovim nightly + the external tools the editor config expects on PATH.
# The config itself is its own repo, bootstrapped below —
# deliberately NOT programs.neovim, which generates its own init.lua and
# symlinks it over the checkout.
{
  inputs,
  pkgs,
  lib,
  ...
}:

{
  home.packages =
    with pkgs;
    [
      # the overlay's build for this platform — nixpkgs' `neovim` is the
      # stable line, so it is not what goes on PATH
      inputs.neovim-nightly-overlay.packages.${stdenv.hostPlatform.system}.default

      # editor-config deps (fzf arrives via programs.fzf in packages.nix)
      tree-sitter
      ripgrep
      fd
    ]
    # macOS's clipboard is pbcopy, built in; Linux ships BOTH providers —
    # nvim picks wl-copy when $WAYLAND_DISPLAY is set (the niri desktop)
    # and falls back to xclip otherwise (WSL/X11) — so this shared file
    # never needs to know which kind of Linux box it's on.
    ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
      pkgs.xclip
      pkgs.wl-clipboard
    ];

  # First-run bootstrap: clone the editor config if it isn't there yet.
  # It stays a normal mutable git checkout, so lazy.nvim can write
  # lazy-lock.json and you can commit/push from ~/.config/nvim as usual.
  # On later activations, pull the latest — but only when it cannot lose
  # work: clean tree, fast-forward only, and never fail the rebuild
  # (offline / diverged just skip).
  home.activation.syncNvimConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -e "$HOME/.config/nvim" ]; then
      # offline-safe: HM activation can run at boot before network is up,
      # and a failed clone must not fail the whole home-manager unit
      run ${pkgs.git}/bin/git clone https://github.com/marcussanchez/neovim-config.git "$HOME/.config/nvim" \
        || echo "nvim: clone failed (offline?) — will retry on the next activation" >&2
    elif [ -d "$HOME/.config/nvim/.git" ] \
      && [ -z "$(${pkgs.git}/bin/git -C "$HOME/.config/nvim" status --porcelain)" ]; then
      run ${pkgs.git}/bin/git -C "$HOME/.config/nvim" pull --ff-only || true
    fi
  '';
}
