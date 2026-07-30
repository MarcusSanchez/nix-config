# Prompt: starship's official tokyo-night preset, vendored as
# starship-tokyo-night.toml. Regenerate with:
#
#   starship preset tokyo-night
#
# then re-apply the three local edits, none of which the preset does:
#
#   * $username$hostname get their OWN segment after the icon, on the
#     preset's second colour — the preset has no identity segment at all,
#     so every later block shifts one step down the gradient:
#     os #a3aed2 -> user@host #769ff0 -> directory #394260 -> git #212736
#   * the toolchain segments (nodejs/bun/rust/golang/php) and $time are
#     dropped, and the bar uses rounded caps —  U+E0B6 opening,  U+E0B4
#     closing — instead of the preset's ░▒▓ gradient lead-in.  U+E0B0
#     separates. Emit these by codepoint when regenerating; typed straight
#     into a heredoc they vanish, which is how a version shipped today with
#     no separators at all
#   * os.symbols gains NixOS, mapped to the same generic Linux glyph the
#     preset already uses. Without an entry starship falls back to its
#     default ❄️, an emoji-presentation glyph that renders in colour and
#     sits badly against text
#
# The preset hardcodes hex rather than using a palette, so catppuccin.nix
# keeps its starship port opted out. That opt-out is load-bearing beyond
# aesthetics: the port reads its palette from a derivation built at EVAL
# time, so any evaluation that can't build it fails outright — CI runners,
# and evaluating the mac config from Linux.
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
    // builtins.fromTOML (builtins.readFile ./starship-tokyo-night.toml);
  };
}
