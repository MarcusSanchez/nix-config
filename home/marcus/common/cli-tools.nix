# The modern-unix staples, fleet-wide: faster, readable replacements
# for the classic tools plus a few TUIs. Interactive-shell ALIASES only
# (ls -> eza, cat -> bat) — aliases never expand inside scripts, so
# anything calling the real coreutils keeps them. ripgrep/fd/fzf
# binaries already arrive via neovim.nix (LazyVim dependencies); fzf's
# SHELL side lives here (Ctrl+T file picker, Alt+C cd — Ctrl+R stays
# atuin's, whose hook loads after fzf's and wins). The catppuccin
# module themes bat/fzf/yazi automatically (autoEnable).
{ pkgs, ... }:

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
    # navigation ended when it quits
    yazi.enable = true;
  };

  home.shellAliases.cat = "bat";

  home.packages = with pkgs; [
    # the most-loved git TUI: hunk staging, interactive rebase, branch
    # surgery — visual and keyboard-driven
    lazygit
    # htop's successor: GPU stats, per-process I/O, mouse support (the
    # system layer still ships htop for root/ssh muscle memory)
    btop
    # where-did-my-disk-go, readable: du and df respectively
    dust
    duf
    # example-first man pages: `tldr tar`
    tealdeer
    # statistical CLI benchmarking (warmups, comparisons)
    hyperfine
    # watch files, rerun a command — the glue for regenerate-on-change
    # loops inside devenv shells: `fd -e proto | entr -r buf generate`
    entr
    # HTTP client with humane syntax: `xh :3000/api/users`
    xh
    # traceroute+ping TUI, for why-is-the-network-slow sessions
    trippy
    # dig with readable output
    doggo
  ];
}
