# The modern-unix staples that are MORE than packages: each of these
# generates shell integration, aliases or config through its Home
# Manager module — which is also how the catppuccin module themes them
# (autoEnable). The plain no-config binaries of the same family live
# in modules/common/packages.nix with the other system CLIs.
#
# Interactive-shell ALIASES only (ls -> eza, cat -> bat) — aliases
# never expand inside scripts, so anything calling the real coreutils
# keeps them. ripgrep/fd/fzf binaries already arrive via neovim.nix
# (LazyVim dependencies); fzf's SHELL side lives here (Ctrl+T file
# picker, Alt+C cd — Ctrl+R stays atuin's, whose hook loads after
# fzf's and wins).
{ ... }:

{
  programs = {
    # fuzzy-anything: Ctrl+T files, Alt+C directories, **<Tab> completion
    fzf.enable = true;

    # cat with syntax highlighting + git gutters; degrades to plain
    # output when piped, which is what makes the alias safe
    bat.enable = true;

    # ls with colors, git status and tree mode; the module's default
    # aliases cover ls/ll/la/lt
    eza.enable = true;

    # terminal file manager (async, image previews in ghostty). The zsh
    # integration adds `y`: like yazi, but the shell cd's to wherever
    # navigation ended when it quits. Wrapper name pinned: the default
    # varies by home.stateVersion (`yy` before 26.05), and the fleet
    # spans both sides of that line
    yazi = {
      enable = true;
      shellWrapperName = "y";
    };

    # the most-loved git TUI: hunk staging, interactive rebase, branch
    # surgery — visual and keyboard-driven
    lazygit.enable = true;

    # htop's successor: GPU stats, per-process I/O, mouse support (the
    # system layer still ships htop for root/ssh muscle memory)
    btop.enable = true;
  };

  home.shellAliases.cat = "bat";
}
