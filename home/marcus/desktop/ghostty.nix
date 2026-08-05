# Ghostty terminal. The catppuccin module themes it automatically
# (autoEnable); the frosted-glass look is a joint effort with niri —
# opacity here, blur from the window-rule in niri.config.kdl.
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
      shell-integration-features = "ssh-env,ssh-terminfo";

      font-family = "JetBrainsMono Nerd Font Mono";
      window-title-font-family = "JetBrainsMono Nerd Font Mono";
      font-size = 12;
      # disable ligatures
      font-feature = [
        "-calt"
        "-liga"
      ];

      # One bar, macOS-style: tabs merged into the titlebar next to the
      # window controls instead of a separate tab bar below it. Caveat
      # from the docs: tab titles aren't drag areas — drag the window by
      # the bar's empty space or super+drag.
      gtk-titlebar-style = "tabs";
      # client-side decorations always: "auto" lets the compositor
      # stack a server-side bar on top of the tabs titlebar
      window-decoration = "client";
      # chrome colored from the terminal palette rather than GTK gray
      window-theme = "ghostty";

      window-padding-balance = true;
      window-save-state = "always";
      confirm-close-surface = false;

      # blur comes from niri's window-rule background-effect, not from
      # here: ghostty's own background-blur option speaks the KDE/macOS
      # protocols, not niri's ext-background-effect
      background-opacity = 0.75;

      split-divider-color = "#f5c2e7";
      cursor-color = "#F5E0DC";

      quick-terminal-position = "bottom";
      # The global: bind goes through the XDG GlobalShortcuts portal —
      # best-effort; portal support for it varies by compositor.
      #
      # The ctrl+* block below is Windows Terminal muscle memory.
      # Deliberate trade-offs, same ones WT made: performable: makes
      # ctrl+c copy only while a selection exists (SIGINT otherwise);
      # ctrl+w shadows zsh's backward-kill-word; ctrl+d shadows EOF
      # (type `exit` instead); ctrl+[ shadows vim-style ESC.
      keybind = [
        "global:super+escape=toggle_quick_terminal"
        "shift+enter=text:\\n"

        "ctrl+t=new_tab"
        "performable:ctrl+c=copy_to_clipboard"
        "ctrl+v=paste_from_clipboard"
        "ctrl+w=close_surface"
        "ctrl+d=new_split:right"
        "ctrl+shift+d=new_split:down"
        "alt+shift+d=new_split:auto"
        "ctrl+left_bracket=goto_split:left"
        "ctrl+right_bracket=goto_split:right"
      ];
    };
  };
}
