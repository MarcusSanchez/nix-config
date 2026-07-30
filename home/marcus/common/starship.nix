# Prompt: oh-my-zsh's robbyrussell, rebuilt in starship, plus an OS glyph.
#
#   <os> ➜  nix-config git:(main) ✗
#
# That's the omz default marcus used before starship: a green arrow that
# turns red on a failed command, the current directory's basename only, and
# the branch wrapped as git:(name). Plain foreground colours — no
# backgrounds, no powerline — so it inherits the terminal's catppuccin theme
# rather than hardcoding hex.
#
# $character comes FIRST here, which is unusual for starship but is what
# robbyrussell does: the arrow leads the line and doubles as the status
# indicator, so there is no trailing prompt marker.
#
# Only two OS glyphs are defined; everything else falls through to
# starship's defaults, which don't matter on a two-platform fleet. NixOS is
# mapped to the generic tux on purpose — with no entry starship uses its
# own default, an emoji-presentation snowflake that renders in colour and
# sits badly against text.
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
        "$os"
        "$character"
        "$directory"
        "$git_branch"
        "$git_status"
        "$cmd_duration"
      ];

      os = {
        disabled = false;
        format = "[$symbol ]($style)";
        style = "bold blue";
        symbols = {
          Macos = "󰀵";
          Linux = "󰌽";
          NixOS = "󰌽";
        };
      };

      # leads the line, robbyrussell-style; two spaces after, as omz has
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

      # git:(branch) — parens blue, branch red, exactly omz's colours
      git_branch = {
        format = "[git:(](bold blue)[$branch](red)[)](bold blue) ";
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
