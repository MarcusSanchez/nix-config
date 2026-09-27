# iNiR — the trial second shell beside the session's default DMS,
# round two, carrying every scar from round one and the noctalia
# interlude. end-4's illogical-impulse lineage rebuilt niri-first;
# three panel families (ii — Material 3, waffle — Win11, iRiS — the
# 2.31 flagship island), cycled with Mod+Shift+W or set directly:
# `inir ipc panelFamily set iris|ii|waffle`. Its own flake packages
# it (the wiki's NixOS page blesses this module shape); DMS keeps the
# session's spawn-at-startup and a reboot always comes back to DMS —
# the shell:* pair below swaps the LIVE session, lock-guarded because
# killing the active locker leaves niri's fail-secure screen.
#
# The scars, each load-bearing:
#   - configSymlink: the launcher finds its shell payload ONLY at the
#     traditional paths (~/.config/quickshell/inir, /usr/...), never
#     its own runtime-dir env vars — without the link every
#     `inir run` dies with "Could not find an iNiR shell payload".
#   - the postFixup: upstream's launcher runs under `set -e`, and its
#     niri-config env-import loop ends on `[[ -n $value ]] && export`
#     — a config that doesn't set the loop's last variable
#     (ELECTRON_OZONE_PLATFORM_HINT; the project's own installer
#     always writes one) makes that test the function's failing last
#     statement and -e kills the launch with no output at all.
#     --replace-fail so an upstream fix retires it loudly.
#   - the start retry: quickshell-family shells share a first-run
#     race — on virgin state the launched shell can die
#     mid-initialization, and the second start (config now seeded)
#     succeeds.
#   - IPC goes through `inir ipc <target> <fn>` (its own instance
#     discovery): the instance registers under the RESOLVED store
#     path, so `qs -c inir` cannot address it.
#   - never run `inir doctor`'s auto-fix: it plants a launcher
#     symlink at ~/.local/bin/inir pointing INTO the then-current
#     store path — ~/.local/bin wins PATH, so after any rebuild every
#     `inir` invocation silently runs the stale (and here unpatched)
#     copy. Round two lost an hour to the one round one left behind.
{
  inputs,
  pkgs,
  ...
}:

let
  # the Material You generator (scripts/colors/generate_colors_material
  # .py, run on every wallpaper set) expects the python venv upstream's
  # installer pip-builds; INIR_VENV is the script's own override, and a
  # nix python env quacks enough like one (bin/python3 present, the
  # activate source is `|| true`). Without it color generation dies
  # SILENTLY and the shell keeps its fallback palette — the
  # nothing-like-the-gallery look.
  inirPython = pkgs.python3.withPackages (ps: [
    ps.numpy
    ps.pillow
    ps.materialyoucolor
  ]);

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
    configSymlink.enable = true;
    package = inputs.inir.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideAttrs (old: {
      postFixup = (old.postFixup or "") + ''
        substituteInPlace $out/share/quickshell/inir/scripts/inir \
          --replace-fail '[[ -n "$value" ]] && export "''${name}=''${value}"' \
                         'if [[ -n "$value" ]]; then export "''${name}=''${value}"; fi'
      '';
    });
  };

  # iNiR's wallpaper pipeline writes GTK settings.ini on every set
  # (its apps-and-shell theming, which also feeds the shell's own
  # colors.json and must stay on) — force lets every switch stomp that
  # spray instead of dying on the backup collision. The trial's other
  # writer risks are handled elsewhere: terminal theming is OFF in the
  # machine-local config (it EDITS the repo-linked ghostty config —
  # caught once, reverted), and the zed/chrome/spicetify writers only
  # touch machine-local theme files.
  xdg.configFile = {
    "gtk-3.0/settings.ini".force = true;
    "gtk-4.0/settings.ini".force = true;
  };

  home.packages = [
    # iNiR's runtime expectations, named by its own --issues log: magick
    # processes wallpapers (its absence rendered the workspace previews
    # as placeholder blocks AND starved the Material color generation),
    # qalc is the launcher's calculator, ddcutil the external-monitor
    # brightness path, swayidle its idle/lock automation. Trial-scoped
    # on purpose — these retire with the file.
    pkgs.imagemagick
    pkgs.libqalculate
    pkgs.ddcutil
    pkgs.swayidle

    (mkShellSwitch "inir" ''
      # without an icon theme NAME, every QIcon lookup fails — the
      # image-missing fallback included (the placeholder-checker look).
      # The gtk3 platform theme would provide one, but iNiR's bundled
      # Qt lacks the plugin; QS_ICON_THEME is quickshell's own
      # override, and Adwaita chains to hicolor where the app icons
      # live. Verified: failures went from dozens to zero.
      export QS_ICON_THEME=Adwaita
      export QT_QPA_PLATFORMTHEME=gtk3
      export INIR_VENV=${inirPython}
      setsid inir run >/dev/null 2>&1 </dev/null &
      for _ in 1 2 3 4 5 6; do
        sleep 1
        pgrep "[q]uickshell" >/dev/null && break
      done
      if ! pgrep "[q]uickshell" >/dev/null; then
        echo "inir: first start died (first-run init) — retrying" >&2
        setsid inir run >/dev/null 2>&1 </dev/null &
      fi
      echo "shell: iNiR (Mod+Shift+W cycles panel families; inir ipc panelFamily set iris|ii|waffle picks one; shell:dms returns)"
    '')
    (mkShellSwitch "dms" ''
      setsid dms run >/dev/null 2>&1 </dev/null &
      echo "shell: DMS"
    '')
  ];
}
