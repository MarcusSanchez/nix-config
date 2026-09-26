# iNiR — a second shell installed BESIDE the session's default DMS,
# for trying a different desktop feel on the same niri: end-4's
# illogical-impulse lineage rebuilt niri-first (quickshell-based like
# DMS; three panel families — ii, waffle, iRiS — cycled with
# Super+Shift+W once it runs). Its own flake packages it; the HM
# module here installs the `inir` CLI, while its autostart service
# stays OFF on purpose — DMS remains what spawn-at-startup brings up,
# and a reboot always comes back to DMS.
#
# Swapping the LIVE session between the two is the shell:* pair
# below. Both shells are quickshell configs, so each command puts
# down both before starting its target. The lock guard exists because
# killing the active locker leaves niri's fail-secure red screen and
# a session that swallows input until a new lock surface appears —
# a locked session refuses to swap. (The guard queries DMS; with iNiR
# running the query fails open, so swap from an unlocked session.)
{
  inputs,
  pkgs,
  ...
}:

let
  mkShellSwitch =
    name: script:
    pkgs.runCommand "shell-${name}" { } ''
      mkdir -p $out/bin
      install -m755 ${pkgs.writeShellScript "shell-${name}" ''
        set -u
        if [ "$(dms ipc call lock isLocked 2>/dev/null)" = true ]; then
          echo "shell:${name}: session is locked — unlock first (killing the" >&2
          echo "active locker leaves niri's fail-secure screen)" >&2
          exit 1
        fi
        # the bracket keeps each pattern from matching a process that
        # merely QUOTES it (same trick as mpvpaper:toggle)
        pkill -f "[d]ms run" 2>/dev/null || true
        pkill -f "[i]nir run" 2>/dev/null || true
        pkill "[q]uickshell" 2>/dev/null || true
        sleep 1
        ${script}
      ''} "$out/bin/shell:${name}"
    '';
in
{
  imports = [ inputs.inir.homeManagerModules.default ];

  programs.inir = {
    enable = true;
    # no autostart: DMS owns the session's spawn-at-startup, and two
    # shells racing for the bar/notifications/StatusNotifierWatcher
    # would fight — iNiR runs only when shell:inir asks it to
    service.enable = false;
    # the launcher finds its shell payload ONLY at the traditional
    # paths (~/.config/quickshell/inir, /usr/...), never through its
    # own runtime-dir env vars — without this link every `inir run`
    # dies with "Could not find an iNiR shell payload". (The running
    # instance still registers under the RESOLVED store path, so
    # `qs -c inir` cannot address it — the niri binds go through
    # `inir ipc`, whose own discovery finds the instance.)
    configSymlink.enable = true;
    # upstream's launcher runs under `set -e`, and its niri-config
    # env-import loop ends on `[[ -n $value ]] && export ...` — a
    # config that doesn't set the loop's last variable
    # (ELECTRON_OZONE_PLATFORM_HINT; the project's own installer
    # always writes one) makes that test the function's failing last
    # statement and -e kills the launch with no output at all.
    # --replace-fail so an upstream fix retires this loudly.
    package = inputs.inir.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideAttrs (old: {
      postFixup = (old.postFixup or "") + ''
        substituteInPlace $out/share/quickshell/inir/scripts/inir \
          --replace-fail '[[ -n "$value" ]] && export "''${name}=''${value}"' \
                         'if [[ -n "$value" ]]; then export "''${name}=''${value}"; fi'
      '';
    });
  };

  home.packages = [
    (mkShellSwitch "inir" ''
      setsid inir run >/dev/null 2>&1 </dev/null &
      echo "shell: iNiR (Super+Shift+W cycles its panel families; shell:dms returns)"
    '')
    (mkShellSwitch "dms" ''
      setsid dms run >/dev/null 2>&1 </dev/null &
      echo "shell: DMS"
    '')
  ];
}
