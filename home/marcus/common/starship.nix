# Prompt: starship's official tokyo-night preset, vendored as
# starship-tokyo-night.toml. Regenerate with:
#
#   starship preset tokyo-night
#
# then re-apply the three local edits, none of which the preset does:
#
#   * $username$hostname ride in the first block, right after the OS icon,
#     styled to match it — the preset has no identity segment at all
#   * the toolchain segments (nodejs/bun/rust/golang/php) and $time are
#     dropped, and the powerline colour chain re-stitched to close on
#     git_status's #394260 instead of leaving a dangling separator
#   * os.symbols gains NixOS. The preset omits it, so starship falls back
#     to its default ❄️ — an emoji-presentation glyph that renders in
#     colour and sits badly against text
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
