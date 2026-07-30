# Prompt: oh-my-zsh's robbyrussell, rebuilt in starship.
#
#   ➜  nix-config git:(main) ✗
#
# The omz default marcus used before starship: a green arrow that turns red
# on a failed command, the current directory's basename only, and the branch
# wrapped as git:(name). Plain foreground colours — no backgrounds, no
# powerline, no vendored preset — so it follows the terminal's catppuccin
# theme instead of hardcoding hex.
#
# $character comes FIRST, which is unusual for starship but is what
# robbyrussell does: the arrow is both the prompt marker and the exit-status
# indicator, so nothing trails the line.
#
# The parens in git_branch are BACKSLASH-ESCAPED. Unescaped, `(` opens a
# conditional group in starship's format grammar and the module dies with
# "expected variable, string, textgroup, or conditional". Same applies to
# $ \ [ ] ( ) anywhere a literal is meant.
#
# catppuccin.nix keeps its starship port opted out: it builds its theme at
# EVALUATION time, so any eval that cannot build it fails outright (CI
# runners, and evaluating the mac config from Linux). Named colours make it
# unnecessary anyway.
#
# Starship's zsh init runs after oh-my-zsh, so it owns the prompt; omz stays
# for its plugins only (shell.nix sets theme = "").
{ ... }:

{
  programs.starship = {
    enable = true;
    settings = {
      # blank line between prompts
      add_newline = true;

      format = builtins.concatStringsSep "" [
        "$character"
        "$directory"
        "$git_branch"
        "$git_status"
        "$cmd_duration"
      ];

      # leads the line, robbyrussell-style; the trailing space plus the one
      # in $directory give omz's two-space gap
      character = {
        success_symbol = "[➜ ](bold green)";
        error_symbol = "[➜ ](bold red)";
      };

      # basename only — omz's %c
      directory = {
        format = "[$path]($style) ";
        style = "cyan";
        truncation_length = 1;
        truncation_symbol = "";
        truncate_to_repo = false;
      };

      # git:(branch) in omz's colours — blue parens, red branch
      git_branch = {
        format = "[git:\\(](bold blue)[$branch](red)[\\)](bold blue) ";
      };

      git_status = {
        format = "([$all_status$ahead_behind]($style) )";
        style = "yellow";
        conflicted = "✗";
        modified = "✗";
        deleted = "✗";
        untracked = "?";
        staged = "+";
        renamed = "»";
        stashed = "≡";
        ahead = "⇡";
        behind = "⇣";
        diverged = "⇕";
      };

      cmd_duration = {
        min_time = 2000;
        format = "[$duration]($style) ";
        style = "dimmed yellow";
      };
    };
  };
}
