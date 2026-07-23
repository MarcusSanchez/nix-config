# macOS system behavior. Mostly a landing zone: as imperative tweaks get
# rediscovered, declare them here instead of clicking through System Settings.
{ ... }:

{
  # Touch ID for sudo (works in tmux/iTerm too via pam_reattach behavior
  # of sudo_local). The one deliberate addition over the pre-nix machine.
  security.pam.services.sudo_local.touchIdAuth = true;

  # Examples for later, all under system.defaults:
  #   system.defaults.dock.autohide = true;
  #   system.defaults.finder.AppleShowAllExtensions = true;
  #   system.defaults.NSGlobalDomain.KeyRepeat = 2;
}
