# Fonts. The zed and ghostty configs assume "JetBrainsMono Nerd Font
# (Mono)"; noto is the fallback base + emoji.
{ pkgs, ... }:

{
  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    noto-fonts
    noto-fonts-color-emoji
  ];
}
