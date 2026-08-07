# Ghostty settings shared by every machine that runs it — imported
# EXPLICITLY by home/marcus/desktop/ghostty.nix and
# home/marcus/darwin/ghostty.nix, and deliberately NOT aggregated by
# common/default.nix: enable = true installs the package, and the WSL
# boxes must not gain a GUI terminal (their ghostty is the Windows
# side). Platform chrome (titlebar style, font size, blur) stays in
# the importing files. The catppuccin module themes it automatically
# (autoEnable).
{ ... }:

{
  programs.ghostty = {
    enable = true;

    settings = {
      # Ghostty sets TERM=xterm-ghostty, which remote hosts generally don't
      # have — the line editor then redraws wrong and typing comes out
      # duplicated. ssh-terminfo makes Ghostty install its terminfo on the
      # remote on first connect (cached; `ghostty +ssh-cache` inspects it);
      # ssh-env falls back to a sane TERM where it can't.
      # modules/nixos/packages.nix ships ghostty.terminfo, fixing this from
      # the other side for the fleet's machines; this covers everything else.
      shell-integration-features = "ssh-env,ssh-terminfo";

      font-family = "JetBrainsMono Nerd Font Mono";
      window-title-font-family = "JetBrainsMono Nerd Font Mono";
      # disable ligatures
      font-feature = [
        "-calt"
        "-liga"
      ];

      window-padding-balance = true;
      window-save-state = "always";
      confirm-close-surface = false;

      background-opacity = 0.75;

      split-divider-color = "#f5c2e7";
      cursor-color = "#F5E0DC";

      quick-terminal-position = "bottom";
      # The global: bind goes through the XDG GlobalShortcuts portal on
      # Linux — best-effort; portal support for it varies by compositor.
      keybind = [
        "global:super+escape=toggle_quick_terminal"
        "shift+enter=text:\\n"
      ];
    };
  };
}
