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
  # non-interactive sessions (agents, scripts over ssh) run
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

  # Settings re-asserted on every rebuild: each block below reads the
  # live state and acts only when it is wrong, so a switch is a no-op
  # on a converged machine and a repair on one macOS has reset. Three
  # kinds of store are touched, which is why some lines run as
  # primaryUser and the rest as root.
  #
  # User defaults (as primaryUser):
  #
  #  - Spotlight's ⌘Space hotkey off, so Raycast can claim it. Symbolic
  #    hotkey 64 is "Show Spotlight search"; -dict-add merges just that
  #    key into com.apple.symbolichotkeys instead of replacing the whole
  #    dict (which is what system.defaults.CustomUserPreferences would
  #    do, resetting every other customized shortcut). activateSettings
  #    applies it without a logout. Flipping Spotlight back on in System
  #    Settings won't stick; delete the line to hand ⌘Space back.
  #
  #  - Siri and Apple Intelligence off: the Siri toggle, its menu bar
  #    item, "Hey Siri", and the auto-enrolment the Intelligence
  #    features perform on first sign-in. Plain keys, so direct writes
  #    are safe. Known limit: these keys are the backing store, but on
  #    their own they did not unload the on-device model — the toggle
  #    in System Settings > Apple Intelligence & Siri is authoritative
  #    and was flipped by hand. The writes keep a rebuild from silently
  #    re-enabling it; check that pane after every major macOS update,
  #    since upgrades re-prompt for Apple Intelligence. Why: six
  #    resident processes and ~500 MB for the model, unused here.
  #
  # Spotlight Search Privacy (as root): the Exclusions array in the
  # data volume's Spotlight config, edited with PlistBuddy. The trees
  # listed hold hundreds of thousands of files of code, SDK headers and
  # caches that are searched in the IDE, never in Spotlight — indexing
  # them costs hours of CPU after an OS upgrade and churns on every
  # build, and a macOS update can reset the volume config. Two rules:
  #  - plain paths only. Spotlight ignores the canonical
  #    /System/Volumes/Data/... spelling and may rewrite entries to it,
  #    so match on the plain form and never add the canonical one.
  #  - `mdutil -E` does NOT reload the config; only restarting mds does
  #    (killall — launchctl kickstart on mds is blocked by SIP). The
  #    guard never erases the index, it only restarts mds when it
  #    changed something.
  #
  # Zoom's background updater (as root): Zoom's full installer recreates
  # its launchd items and a root helper for silent installs; ZAutoUpdate
  # (system.defaults below) turns the hourly check off, and this
  # removes the items it leaves behind. Zoom still offers updates
  # in-app when opened. Why: biweekly use does not justify a 24/7
  # updater and a privileged helper.
  system = {
    activationScripts.postActivation.text =
      let
        user = config.system.primaryUser;
        home = config.identity.home;
        asUser = "sudo -u ${user}";
        spotlightExclusions = [
          "${home}/GolandProjects"
          "${home}/WebstormProjects"
          "${home}/projects"
          "${home}/go"
          "${home}/.rustup"
          "${home}/.cargo"
          "${home}/.cache"
          "${home}/.npm"
          "${home}/.gradle"
          "${home}/.expo"
          "${home}/.local"
          "${home}/.skiko"
          "${home}/.trae"
          "${home}/.claude"
          "${home}/.config"
          "${home}/Library/Caches"
          "/Library/Developer"
          "/private/var/folders"
          "/var/folders"
        ];
      in
      lib.mkAfter ''
        ${asUser} /usr/bin/defaults write \
          com.apple.symbolichotkeys AppleSymbolicHotKeys \
          -dict-add 64 '<dict><key>enabled</key><false/></dict>'
        ${asUser} /usr/bin/defaults write \
          com.apple.assistant.support "Assistant Enabled" -bool false
        ${asUser} /usr/bin/defaults write \
          com.apple.Siri StatusMenuVisible -bool false
        ${asUser} /usr/bin/defaults write \
          com.apple.Siri VoiceTriggerUserEnabled -bool false
        ${asUser} /usr/bin/defaults write \
          com.apple.CloudSubscriptionFeatures.optIn auto_opt_in -bool false
        ${asUser} \
          /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u

        spotlight=/System/Volumes/Data/.Spotlight-V100/VolumeConfiguration.plist
        changed=0
        if ! /usr/libexec/PlistBuddy -c 'Print :Exclusions' "$spotlight" >/dev/null 2>&1; then
          /usr/libexec/PlistBuddy -c 'Add :Exclusions array' "$spotlight"
          changed=1
        fi
        for d in ${lib.escapeShellArgs spotlightExclusions}; do
          if ! /usr/libexec/PlistBuddy -c 'Print :Exclusions' "$spotlight" | grep -qxF "    $d"; then
            /usr/libexec/PlistBuddy -c "Add :Exclusions: string $d" "$spotlight"
            changed=1
          fi
        done
        if [ "$changed" = 1 ]; then
          killall mds || true
        fi

        for f in /Library/LaunchAgents/us.zoom.updater.plist \
                 /Library/LaunchAgents/us.zoom.updater.login.check.plist \
                 /Library/LaunchDaemons/us.zoom.ZoomDaemon.plist; do
          [ -e "$f" ] || continue
          launchctl bootout system "$f" 2>/dev/null || true
          rm -f "$f"
        done
        rm -f /Library/PrivilegedHelperTools/us.zoom.ZoomDaemon
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

      # Zoom's hourly update agent off, system scope. The domain is the
      # plist's full path on purpose: activation runs as root, and a bare
      # domain name would land in root's own ~/Library/Preferences
      # instead of /Library/Preferences, where Zoom reads it. The launchd
      # cleanup that pairs with it is in postActivation above.
      CustomSystemPreferences."/Library/Preferences/us.zoom.config".ZAutoUpdate = false;
    };
  };
}
