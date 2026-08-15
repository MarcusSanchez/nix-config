# User-level CLIs: the standalone tools, and the modern-unix staples
# that are MORE than packages — each of those generates shell
# integration, aliases or config through its Home Manager module, which
# is also how the catppuccin module themes them (autoEnable). The plain
# no-config binaries of the same family live in
# modules/common/packages.nix with the other system CLIs.
#
# Interactive-shell ALIASES only (ls -> eza, cat -> bat) — aliases
# never expand inside scripts, so anything calling the real coreutils
# keeps them. ripgrep/fd/fzf binaries already arrive via neovim.nix
# (LazyVim dependencies); fzf's SHELL side lives here (Ctrl+T file
# picker, Alt+C cd — Ctrl+R stays atuin's, whose hook loads after
# fzf's and wins).
{ inputs, pkgs, ... }:

{
  home.packages = with pkgs; [
    croc
    flyctl
    # sends WoL magic packets; the target PC's BIOS/NIC must have
    # wake-on-LAN enabled or the packet is silently ignored
    wakeonlan
  ];

  # comma: `, <cmd>` runs any program from nixpkgs without installing it
  # (one-off tools, trying things out). Backed by nix-index-database's
  # prebuilt index — refreshed by `nix flake update`, never built locally.
  # Bonus: nix-index's command-not-found handler tells you which package
  # provides a missing command.
  imports = [ inputs.nix-index-database.homeModules.nix-index ];

  programs = {
    nix-index.enable = true;
    nix-index-database.comma.enable = true;

    # fuzzy-anything: Ctrl+T files, Alt+C directories, **<Tab> completion.
    # No history widget: atuin owns Ctrl-R (shell.nix), and leaving
    # fzf's competing binding declared made every eval warn about the
    # collision — this is the warning's own prescribed fix.
    fzf = {
      enable = true;
      historyWidget.command = "";
    };

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

      # j/k inverted. prepend_keymap rather than a bare `keymap`: prepend
      # wins over the defaults while leaving every other binding intact,
      # where a plain keymap would replace the whole default set.
      keymap.mgr.prepend_keymap = [
        {
          on = [ "j" ];
          run = "arrow -1";
          desc = "Move cursor up";
        }
        {
          on = [ "k" ];
          run = "arrow 1";
          desc = "Move cursor down";
        }
      ];
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
