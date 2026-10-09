# Settings macOS resets on its own, re-asserted on every switch. Each
# block reads the live state and acts only when it is wrong, so a
# switch is a no-op on a converged machine and a repair on one macOS
# has reset. User defaults run as primaryUser; the rest run as root.
{
  config,
  lib,
  ...
}:

let
  user = config.system.primaryUser;
  home = config.identity.home;
  asUser = "sudo -u ${user}";

  # Spotlight's ⌘Space hotkey off, so Raycast can claim it. Symbolic
  # hotkey 64 is "Show Spotlight search"; -dict-add merges just that key
  # into com.apple.symbolichotkeys instead of replacing the whole dict
  # (which is what system.defaults.CustomUserPreferences would do,
  # resetting every other customized shortcut). activateSettings applies
  # it without a logout. Flipping Spotlight back on in System Settings
  # won't stick; delete the line to hand ⌘Space back.
  #
  # Siri and Apple Intelligence off: the Siri toggle, its menu bar item,
  # "Hey Siri", and the auto-enrolment the Intelligence features perform
  # on first sign-in. Plain keys, so direct writes are safe. These keys
  # are the backing store but do not unload an already-running on-device
  # model: the toggle in System Settings > Apple Intelligence & Siri is
  # authoritative, and major macOS updates re-prompt for it — the writes
  # keep a rebuild from re-enabling it silently.
  userDefaults = ''
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
  '';

  # Spotlight Search Privacy: the Exclusions array in the data volume's
  # Spotlight config, edited with PlistBuddy. These trees hold code, SDK
  # headers and caches that are searched in the IDE, never in Spotlight;
  # indexing them costs hours of CPU after an OS upgrade and churns on
  # every build, and a macOS update can reset the volume config. Plain
  # paths only: Spotlight ignores the canonical /System/Volumes/Data/...
  # spelling and may rewrite entries to it, so match on the plain form
  # and never add the canonical one. `mdutil -E` does not reload the
  # config; only restarting mds does (killall — launchctl kickstart on
  # mds is blocked by SIP). The index is never erased, mds is restarted
  # only when something changed.
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
  spotlightPrivacy = ''
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
  '';

  # Zoom's background updater: its full installer recreates launchd
  # items and a root helper for silent installs. ZAutoUpdate (below)
  # turns the hourly check off; this removes the items it leaves behind.
  # Updates remain available in-app.
  zoomUpdater = ''
    for f in /Library/LaunchAgents/us.zoom.updater.plist \
             /Library/LaunchAgents/us.zoom.updater.login.check.plist \
             /Library/LaunchDaemons/us.zoom.ZoomDaemon.plist; do
      [ -e "$f" ] || continue
      launchctl bootout system "$f" 2>/dev/null || true
      rm -f "$f"
    done
    rm -f /Library/PrivilegedHelperTools/us.zoom.ZoomDaemon
  '';
in
{
  system = {
    activationScripts.postActivation.text = lib.mkAfter (userDefaults + spotlightPrivacy + zoomUpdater);

    # The domain is the plist's full path on purpose: activation runs as
    # root, and a bare domain name would land in root's own
    # ~/Library/Preferences instead of /Library/Preferences, where Zoom
    # reads it.
    defaults.CustomSystemPreferences."/Library/Preferences/us.zoom.config".ZAutoUpdate = false;
  };
}
