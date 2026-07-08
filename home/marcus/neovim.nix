# Neovim (stable, from nixpkgs) + the external tools LazyVim expects on PATH.
# The editor config itself is marcus's own LazyVim fork, bootstrapped below —
# deliberately NOT programs.neovim, which generates its own init.lua and
# symlinks it over the checkout.
{ pkgs, lib, ... }:

{
  home.packages = with pkgs; [
    neovim

    # lazyvim deps
    tree-sitter
    ripgrep
    fd
    fzf
    xclip
  ];

  # First-run bootstrap: clone the editor config if it isn't there yet.
  # It stays a normal mutable git checkout, so lazy.nvim can write
  # lazy-lock.json and you can commit/push from ~/.config/nvim as usual.
  home.activation.cloneNvimConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -e "$HOME/.config/nvim" ]; then
      run ${pkgs.git}/bin/git clone https://github.com/marcussanchez/neovim-config.git "$HOME/.config/nvim"
    fi
  '';
}
