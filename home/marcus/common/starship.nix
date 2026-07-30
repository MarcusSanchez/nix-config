# Prompt: starship with the official catppuccin-powerline preset, vendored
# as starship-powerline.toml. Regenerate with:
#
#   starship preset catppuccin-powerline
#
# It carries its own mocha palette, so catppuccin.nix opts out of the
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
      # blank line between prompts — replaces the old `precmd() { echo }`
      add_newline = true;
    }
    // builtins.fromTOML (builtins.readFile ./starship-powerline.toml);
  };
}
