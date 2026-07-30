# Prompt: starship, themed Catppuccin Mocha by the catppuccin module
# (autoEnable). Its zsh init runs after oh-my-zsh, so it owns the prompt;
# omz stays for its plugins only — see shell.nix, where the theme is "".
#
# Deliberately stock. Starship's defaults are a considered design; two
# attempts at "improving" them on 2026-07-30 produced worse prompts than
# this one, so the settings below stop at a blank line between prompts.
# If a module ever genuinely needs changing, change that module — don't
# write a wholesale `format`.
{ ... }:

{
  programs.starship = {
    enable = true;
    settings = {
      # blank line between prompts — replaces the old `precmd() { echo }`
      add_newline = true;
    };
  };
}
