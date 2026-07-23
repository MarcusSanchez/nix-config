# Neovim (stable, from nixpkgs) + the external tools LazyVim expects on PATH.
# The editor config itself is marcus's own LazyVim fork, bootstrapped below —
# deliberately NOT programs.neovim, which generates its own init.lua and
# symlinks it over the checkout.
{ pkgs, lib, ... }:

{
  home.packages =
    with pkgs;
    [
      neovim

      # lazyvim deps
      tree-sitter
      ripgrep
      fd
      fzf
    ]
    # macOS's clipboard is pbcopy, built in; Linux needs xclip
    ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.xclip ];

  # First-run bootstrap: clone the editor config if it isn't there yet.
  # It stays a normal mutable git checkout, so lazy.nvim can write
  # lazy-lock.json and you can commit/push from ~/.config/nvim as usual.
  # On later activations, pull the latest — but only when it cannot lose
  # work: clean tree, fast-forward only, and never fail the rebuild
  # (offline / diverged just skip).
  home.activation.syncNvimConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -e "$HOME/.config/nvim" ]; then
      run ${pkgs.git}/bin/git clone https://github.com/marcussanchez/neovim-config.git "$HOME/.config/nvim"
    elif [ -d "$HOME/.config/nvim/.git" ] \
      && [ -z "$(${pkgs.git}/bin/git -C "$HOME/.config/nvim" status --porcelain)" ]; then
      run ${pkgs.git}/bin/git -C "$HOME/.config/nvim" pull --ff-only || true
    fi
  '';
}
