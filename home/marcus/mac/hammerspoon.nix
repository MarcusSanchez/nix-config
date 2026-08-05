# Hammerspoon — the mac's per-application key remapper, standing in for
# xremap on the laptop. The rules themselves live in
# common/dotfiles/hammerspoon.init.lua; this file only installs the
# config and keeps the app running.
#
# The app itself is a cask (modules/darwin/homebrew.nix): Hammerspoon is
# not in nixpkgs at all, and the nix-darwin karabiner module — the other
# route to this job — has been broken since Karabiner v15 moved its
# launch agents.
#
# Accessibility permission is required and cannot be granted from a
# config: System Settings > Privacy & Security > Accessibility. The
# config announces on load whether it has it.
{ config, ... }:

{
  # Out of the store, so edits apply on save without a rebuild — the
  # config's own path watcher reloads Hammerspoon. Same live-editing loop
  # as xremap's --watch=config, and the drift is committed by the hook in
  # mac/dotfiles.nix, whose pathspec already covers this directory.
  # (Hammerspoon reads ~/.hammerspoon/init.lua; it is not XDG-aware.)
  home.file.".hammerspoon/init.lua".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nix-config/home/marcus/common/dotfiles/hammerspoon.init.lua";

  # Start at login and stay up — a keyboard remapper that quietly dies
  # is worse than one that was never running, since the keys just go
  # back to their defaults with no signal. Program points at the binary
  # inside the cask's bundle rather than using `open`, which would exit
  # immediately and have KeepAlive respawn it in a loop.
  launchd.agents.hammerspoon = {
    enable = true;
    config = {
      Program = "/Applications/Hammerspoon.app/Contents/MacOS/Hammerspoon";
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "/tmp/hammerspoon.log";
      StandardErrorPath = "/tmp/hammerspoon.err.log";
    };
  };
}
