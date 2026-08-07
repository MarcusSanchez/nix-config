# Ghostty on the desktop: shared settings from common/ghostty.nix,
# plus the GTK chrome and the Windows-Terminal keybind block. The
# frosted-glass look is a joint effort with niri — opacity in common,
# blur from the window-rule in niri.config.kdl.
{ ... }:

{
  imports = [ ../common/ghostty.nix ];

  programs.ghostty.settings = {
    font-size = 12;

    # No titlebar at all: under niri, tabs/splits go unused (the
    # compositor tiles instead), so the header is pure chrome. The old
    # tabs-in-titlebar setup (gtk-titlebar-style "tabs" +
    # window-decoration "client" + window-theme "ghostty") is in git
    # history if terminal tabs ever come back into fashion.
    window-decoration = "none";

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
