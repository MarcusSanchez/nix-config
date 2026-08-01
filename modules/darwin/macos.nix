# macOS system behavior. Mostly a landing zone: as imperative tweaks get
# rediscovered, declare them here instead of clicking through System Settings.
{ config, lib, ... }:

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

  # Spotlight's ⌘Space hotkey off, so Raycast can claim it. Symbolic hotkey
  # 64 is "Show Spotlight search"; it's a *user* default, so this runs as
  # primaryUser, and -dict-add merges just that key into
  # com.apple.symbolichotkeys instead of replacing the whole dict (which is
  # what system.defaults.CustomUserPreferences would do, resetting every
  # other customized shortcut). activateSettings applies it without a
  # logout. Re-asserted on every rebuild — flipping Spotlight back on in
  # System Settings won't stick; delete this block to hand ⌘Space back.
  system.activationScripts.postActivation.text = lib.mkAfter ''
    sudo -u ${config.system.primaryUser} /usr/bin/defaults write \
      com.apple.symbolichotkeys AppleSymbolicHotKeys \
      -dict-add 64 '<dict><key>enabled</key><false/></dict>'
    sudo -u ${config.system.primaryUser} \
      /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
  '';

  # Examples for later, all under system.defaults:
  #   system.defaults.dock.autohide = true;
  #   system.defaults.finder.AppleShowAllExtensions = true;
  #   system.defaults.NSGlobalDomain.KeyRepeat = 2;
}
