# Ghostty terminal. The app itself is a brew cask (homebrew.nix); with
# package = null HM only manages the config file (~/.config/ghostty/config).
# The catppuccin module themes it automatically (autoEnable), replacing the
# hand-downloaded theme files of the pre-nix setup. Shaders stay an
# imperative folder in ~/Library/Application Support/com.mitchellh.ghostty.
{ ... }:

{
  programs.ghostty = {
    enable = true;
    package = null; # installed as a brew cask

    settings = {
      font-family = "JetBrainsMono Nerd Font Mono";
      window-title-font-family = "JetBrainsMono Nerd Font Mono";
      font-size = 17;
      # disable ligatures
      font-feature = [
        "-calt"
        "-liga"
      ];

      macos-titlebar-style = "tabs";
      window-padding-balance = true;
      window-save-state = "always";
      confirm-close-surface = false;
      # effectively "open maximized"
      window-height = 20000;
      window-width = 20000;

      background-opacity = 0.75;
      background-blur = 20;

      split-divider-color = "#f5c2e7";
      cursor-color = "#F5E0DC";

      quick-terminal-position = "bottom";
      keybind = [
        "global:super+escape=toggle_quick_terminal"
        "shift+enter=text:\\n"
      ];

      # custom-shader = "…/ghostty-shaders/starfield.glsl";
    };
  };
}
