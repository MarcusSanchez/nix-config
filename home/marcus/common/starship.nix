# Prompt. Plain by design: no powerline separators, no filled blocks, no
# right-hand segment. Two lines so a long branch never squeezes the cursor.
#
#    marcus@bedroom-wsl ~/projects/noted  main ●
#   ❯
#
# Colour discipline is borrowed from the Pure preset, which is why it reads
# calmly: exactly ONE accent — the directory — and everything else dimmed to
# bright-black. Context (which box, which branch) shouldn't compete with the
# thing you're actually looking at. Only $character is vivid, and only so
# failure is obvious.
#
# Symbols are the codepoints from starship's own nerd-font-symbols preset
# rather than hand-picked Unicode:  is U+F313, not the ❄ emoji, which
# renders as a colour glyph and sits badly against text.
#
# An explicit `format` means ONLY these modules render — otherwise starship
# prints a version badge for every toolchain it finds in the directory.
#
# nix_shell is deliberately absent. direnv loads devenv in every project, so
# the marker would always be on and carry no information — and its symbol is
# the same U+F313 as NixOS, so it showed twice.
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
        "$cmd_duration"
        "$line_break"
        "$character"
      ];

      # Which machine, at a glance. Dim — the glyph shape carries it.
      os = {
        disabled = false;
        format = "[$symbol]($style)";
        style = "bright-black";
        symbols = {
          Macos = " ";
          NixOS = " ";
          Linux = " ";
        };
      };

      username = {
        show_always = true;
        format = "[$user]($style)";
        style_user = "bright-black";
        style_root = "bold red";
      };

      hostname = {
        ssh_only = false;
        format = "[@$hostname]($style) ";
        style = "bright-black";
      };

      # The one accent. Full path rather than truncate_to_repo, so you keep
      # the context of where the repo lives.
      directory = {
        format = "[$path]($style)[$read_only]($read_only_style) ";
        style = "bold blue";
        truncation_length = 3;
        truncation_symbol = "…/";
        read_only = " 󰌾";
        read_only_style = "red";
      };

      git_branch = {
        format = "[$symbol$branch]($style) ";
        symbol = " ";
        style = "bright-black";
      };

      # Symbols only, no counts — yellow is the one thing allowed to catch
      # your eye besides the prompt character.
      git_status = {
        format = "([$all_status$ahead_behind]($style) )";
        style = "yellow";
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

      cmd_duration = {
        min_time = 2000;
        format = "[$duration]($style) ";
        style = "bright-black";
      };

      character = {
        success_symbol = "[❯](bold green)";
        error_symbol = "[❯](bold red)";
      };
    };
  };
}
