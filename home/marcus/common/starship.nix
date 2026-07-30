# Prompt. Deliberately plain: no powerline separators, no filled blocks, no
# right-hand segment — just the facts, two lines so a long branch never
# squeezes the cursor.
#
#   marcus@bedroom-wsl ~/nix-config  main ●
#   ❯
#
# An explicit `format` means ONLY the modules listed there render. Starship
# otherwise shows a language version for every toolchain it detects in the
# directory, which is where these prompts start getting long.
#
# Colours come from catppuccin (autoEnable in catppuccin.nix), so the names
# below resolve to mocha rather than terminal ANSI.
{ ... }:

{
  programs.starship = {
    enable = true;

    settings = {
      format = builtins.concatStringsSep "" [
        "$os"
        "$username"
        "$hostname"
        "$directory"
        "$git_branch"
        "$git_status"
        "$nix_shell"
        "$cmd_duration"
        "$line_break"
        "$character"
      ];

      # Which machine am I on. Off by default in starship.
      os = {
        disabled = false;
        format = "[$symbol]($style)";
        style = "bold blue";
        symbols = {
          Macos = " ";
          NixOS = "❄ ";
          Linux = " ";
        };
      };

      # Always shown, not just over SSH — the point is knowing which of four
      # boxes this is without thinking.
      username = {
        show_always = true;
        format = "[$user]($style)";
        style_user = "bold blue";
        style_root = "bold red";
      };

      hostname = {
        ssh_only = false;
        format = "[@$hostname]($style) ";
        style = "bold blue";
      };

      directory = {
        format = "[$path]($style)[$read_only]($read_only_style) ";
        style = "bold cyan";
        truncation_length = 3;
        truncate_to_repo = true;
        read_only = " ";
      };

      git_branch = {
        format = "[$symbol$branch]($style) ";
        symbol = " ";
        style = "bold purple";
      };

      # Compact: symbols only, no counts. ● dirty, ⇡⇣ ahead/behind.
      git_status = {
        format = "([$all_status$ahead_behind]($style))";
        style = "bold yellow";
        conflicted = "=";
        untracked = "?";
        modified = "●";
        staged = "+";
        renamed = "»";
        deleted = "✘";
        stashed = "≡";
        ahead = "⇡";
        behind = "⇣";
        diverged = "⇕";
      };

      # devenv / nix develop, so it's obvious when a shell isn't the plain one.
      nix_shell = {
        format = "[$symbol$name]($style) ";
        symbol = "❄ ";
        style = "bold cyan";
      };

      # Only for commands slow enough that you'd want to know.
      cmd_duration = {
        min_time = 2000;
        format = "[$duration]($style) ";
        style = "dimmed yellow";
      };

      character = {
        success_symbol = "[❯](bold green)";
        error_symbol = "[❯](bold red)";
      };
    };
  };
}
