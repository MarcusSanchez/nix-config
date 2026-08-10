# Ghostty, one file for every machine that runs it: the package on the
# bare-metal desktops (the mac's app is a brew cask — homebrew.nix),
# and the config as out-of-store links like the rest of the UI-managed
# rice — live-editable (reload with ctrl/cmd+shift+,), drift riding the
# dotfiles auto-commit. Imported by the desktop and darwin entry
# points, deliberately NOT common/default.nix: the WSL boxes must not
# gain a GUI terminal (their ghostty is the Windows side).
#
# Two links, not one: ~/.config/ghostty/config points at the platform
# entry file (ghostty.linux.config / ghostty.darwin.config), and the
# shared ghostty.config base is linked BESIDE it because ghostty
# resolves the entry's `config-file` include against the entry's own
# directory — the same trap as niri's include.
{
  config,
  lib,
  pkgs,
  ...
}:

{
  home.packages = lib.optionals pkgs.stdenv.isLinux [ pkgs.ghostty ];

  xdg.configFile =
    let
      dotfiles = "${config.home.homeDirectory}/nix-config/home/marcus/common/dotfiles";
      link = f: config.lib.file.mkOutOfStoreSymlink "${dotfiles}/${f}";
      entry = if pkgs.stdenv.isDarwin then "ghostty.darwin.config" else "ghostty.linux.config";
    in
    {
      "ghostty/config".source = link entry;
      "ghostty/ghostty.config".source = link "ghostty.config";
    };
}
