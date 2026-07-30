# starship-powerline.toml is `starship preset catppuccin-powerline` output,
# vendored — regenerate the same way, then re-apply the local edits on top:
# the zig / nix_shell / docker_context segments, the NixOS glyph, and
# line_break enabled (the preset ships it disabled, which glues the cursor
# to the end of the bar).
#
# It ships its own mocha palette, so catppuccin.nix opts out of the
# module's starship port. That opt-out is load-bearing, not tidiness: the
# port reads its palette from a derivation built at EVALUATION time, so any
# eval that can't build it fails outright — CI runners, and evaluating the
# mac config from Linux.
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
    }
    // builtins.fromTOML (builtins.readFile ./starship-powerline.toml);
  };
}
