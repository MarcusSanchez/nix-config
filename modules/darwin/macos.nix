# macOS system behavior. Mostly a landing zone: as imperative tweaks get
# rediscovered, declare them here instead of clicking through System Settings.
{ ... }:

{
  # Touch ID for sudo (works in tmux/iTerm too via pam_reattach behavior
  # of sudo_local). The one deliberate addition over the pre-nix machine.
  security.pam.services.sudo_local.touchIdAuth = true;

  # Remote Login. NOT part of the keyless SSH story — Tailscale SSH is
  # served by tailscaled itself, which intercepts port 22 on the tailnet
  # before Apple's sshd ever sees it. This is the fallback for when
  # tailscaled is down (nix-darwin#1688): Apple's sshd answering on the
  # LAN, authenticating with the account password. No authorized_keys
  # anywhere — the key that used to live here was deleted with ssh.nix.
  services.openssh.enable = true;

  # Examples for later, all under system.defaults:
  #   system.defaults.dock.autohide = true;
  #   system.defaults.finder.AppleShowAllExtensions = true;
  #   system.defaults.NSGlobalDomain.KeyRepeat = 2;
}
