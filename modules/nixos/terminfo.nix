# Terminfo for terminals that connect TO this machine but don't run on it.
#
# Ghostty sets TERM=xterm-ghostty. Without that entry in the local
# terminfo db, a shell here can't do cursor control for a session opened
# from the mac's Ghostty — the line editor redraws wrong and typing comes
# out duplicated ("pwd" showing as "ppwdpwwdpwd"). zsh-syntax-highlighting
# and autosuggestions make it worse, since both repaint the line.
#
# ghostty.terminfo is a terminfo-only output, so this costs a few KB
# rather than pulling in the whole terminal emulator.
{ pkgs, ... }:

{
  environment.systemPackages = [ pkgs.ghostty.terminfo ];
}
