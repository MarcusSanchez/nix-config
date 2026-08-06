# Ghostty on the mac: shared settings from common/ghostty.nix, plus
# the macOS chrome. The app itself is a brew cask (homebrew.nix); with
# package = null HM only manages the config file
# (~/.config/ghostty/config). Shaders stay an imperative folder in
# ~/Library/Application Support/com.mitchellh.ghostty.
{ ... }:

{
  imports = [ ../common/ghostty.nix ];

  programs.ghostty = {
    package = null; # installed as a brew cask

    settings = {
      font-size = 17;

      macos-titlebar-style = "tabs";
      # effectively "open maximized"
      window-height = 20000;
      window-width = 20000;

      background-blur = 20;

      # custom-shader = "…/ghostty-shaders/starfield.glsl";
    };
  };
}
