# Ghostty on the desktop: shared settings from common/ghostty.nix,
# plus the GTK chrome and the Windows-Terminal keybind block. The
# frosted-glass look is a joint effort with niri — opacity in common,
# blur from the window-rule in niri.config.kdl.
{ ... }:

{
  imports = [ ../common/ghostty.nix ];

  programs.ghostty.settings = {
    font-size = 12;

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

    # blur comes from niri's window-rule background-effect, not from
    # here: ghostty's own background-blur option speaks the KDE/macOS
    # protocols, not niri's ext-background-effect

    # Windows Terminal muscle memory. Deliberate trade-offs, same ones
    # WT made: performable: makes ctrl+c copy only while a selection
    # exists (SIGINT otherwise); ctrl+w shadows zsh's
    # backward-kill-word; ctrl+d shadows EOF (type `exit` instead);
    # ctrl+[ shadows vim-style ESC.
    keybind = [
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
}
