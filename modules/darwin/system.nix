# Machine-level system settings and services for the mac: fonts, Touch
# ID, Remote Login, and the settings otherwise clicked through System
# Settings — declared here instead.
{
  config,
  lib,
  pkgs,
  ...
}:

{
  # Fonts, installed to /Library/Fonts/Nix Fonts.
  fonts.packages = [ pkgs.nerd-fonts.jetbrains-mono ];

  # Touch ID for sudo.
  security.pam.services.sudo_local.touchIdAuth = true;

  # Passwordless sudo, matching the Linux boxes — what lets
  # non-interactive sessions (Claude, scripts over ssh) run
  # darwin-rebuild themselves instead of handing the command back to a
  # human. NOPASSWD skips authentication entirely, so it also works
  # where Touch ID can't reach (no tty, ssh, launchd Background
  # domain); Touch ID above stays for anything else PAM-gated. Scoped
  # to the one account, not %admin.
  security.sudo.extraConfig = ''
    ${config.identity.username} ALL=(ALL:ALL) NOPASSWD: ALL
  '';

  # Remote Login. NOT part of the keyless SSH story — Tailscale SSH is
  # served by tailscaled itself, which intercepts port 22 on the tailnet
  # before Apple's sshd ever sees it. This is the fallback for when
  # tailscaled is down (nix-darwin#1688): Apple's sshd answering on the
  # LAN, authenticating with the account password. No authorized_keys
  # exist anywhere in this config — password auth is the only door.
  services.openssh.enable = true;

  # Spotlight's ⌘Space hotkey off, so Raycast can claim it. Symbolic hotkey
  # 64 is "Show Spotlight search"; it's a *user* default, so this runs as
  # primaryUser, and -dict-add merges just that key into
  # com.apple.symbolichotkeys instead of replacing the whole dict (which is
  # what system.defaults.CustomUserPreferences would do, resetting every
  # other customized shortcut). activateSettings applies it without a
  # logout. Re-asserted on every rebuild — flipping Spotlight back on in
  # System Settings won't stick; delete this block to hand ⌘Space back.
  #
  # Siri and Apple Intelligence off, the same way: both are user defaults
  # (the Siri toggle in System Settings > Apple Intelligence & Siri, and
  # the auto-enrolment the Intelligence features perform on first sign-in),
  # so they ride the same primaryUser run. Plain keys, so a direct write
  # is safe — no dict to clobber.
  system = {
    activationScripts.postActivation.text = lib.mkAfter ''
      sudo -u ${config.system.primaryUser} /usr/bin/defaults write \
        com.apple.symbolichotkeys AppleSymbolicHotKeys \
        -dict-add 64 '<dict><key>enabled</key><false/></dict>'
      sudo -u ${config.system.primaryUser} /usr/bin/defaults write \
        com.apple.assistant.support "Assistant Enabled" -bool false
      sudo -u ${config.system.primaryUser} /usr/bin/defaults write \
        com.apple.CloudSubscriptionFeatures.optIn auto_opt_in -bool false
      sudo -u ${config.system.primaryUser} \
        /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
    '';

    # Keyboard repeat: fast rate + short initial delay (these are the
    # System Settings slider maximums; the macOS default leaves both
    # sluggish). Shared by both Macs. Takes effect on the next LOGIN — the
    # WindowServer reads these at session start, not on nix activation, so
    # log out/in (or reboot) after a first switch to feel it.
    defaults = {
      NSGlobalDomain = {
        KeyRepeat = 2;
        InitialKeyRepeat = 15;
      }
      # Traditional desktop-mouse scroll direction (natural OFF), mini
      # only. macOS has ONE global scroll-direction toggle — no
      # per-device split — so this is safe only because the mini has no
      # trackpad. If a Magic Trackpad is ever paired it flips too, and
      # wanting them opposite would then need an event-tap app (Scroll
      # Reverser). Also a next-LOGIN setting.
      // lib.optionalAttrs (config.networking.hostName == "mac-mini") {
        "com.apple.swipescrolldirection" = false;
      };

      # The dock stays out of the way until the cursor asks for it.
      # Applies live on activation (Dock restarts), no logout needed.
      dock.autohide = true;
    };
  };
}
