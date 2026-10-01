# DankMaterialShell, the desktop shell. Theme and wallpaper CHOICE
# live in the settings UI (Mod+Comma) and land as git drift through
# the settings link below, the same UI-managed pattern as zed; what
# this file adds is the plumbing that makes the chosen palette
# PROPAGATE — matugen renders it into niri's focus ring, and DMS's own
# dankcolors ghostty theme (named in ghostty.linux.config) rides the
# same regeneration. The retired looks system — the wallpaper:<name>
# commands, per-look dms.theme jsons, the niri accent-sed — is whole
# in git history if ever wanted back. Spawned and bound in
# niri.config.kdl (spawn-at-startup "dms run", Alt/Mod+Space
# spotlight, Super+Alt+L lock). Session *state* — wallpaper path,
# avatar, per-app usage — stays outside in ~/.local/state,
# machine-local by design.
{
  config,
  pkgs,
  lib,
  ...
}:

{
  xdg.configFile = {
    # DMS caveat, same as the zed links: it may atomically replace
    # settings.json's link with a plain file on save; HM re-links and
    # hm-backups it on the next switch. The target is the accumulated
    # UI drift, and a few of its keys are LOAD-BEARING pairs with this
    # file (launcherLogoSizeOffset with the dms-shell source patch
    # below, terminalsAlwaysDark with ghostty.linux.config's dankcolors
    # theme) — a wipe back to {} costs those, not just cosmetics.
    "DankMaterialShell/settings.json".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nix-config/home/marcus/common/dotfiles/dms.settings.json";

    # niri's focus ring follows DMS's palette: whenever DMS runs matugen
    # (wallpaper changes and theme switches), it also runs the USER's
    # matugen config after its own, and this template renders the active
    # primary color into a tiny include that niri.config.kdl loads last —
    # niri hot-reloads when it changes. Three hard-won rules, each a
    # broken afternoon once: the toml stays comment-free plain ASCII (DMS
    # re-parses it when merging and choked on a nixfmt-escaped em-dash),
    # the empty [config] table is mandatory, and the paths must be
    # ABSOLUTE — DMS silently skips a template with ~-relative paths.
    "matugen/config.toml".text = ''
      [config]

      [templates.niri-accent]
      input_path = "${config.home.homeDirectory}/.config/matugen/templates/niri-accent.kdl"
      output_path = "${config.home.homeDirectory}/.config/niri/niri.accent.kdl"
    '';
    "matugen/templates/niri-accent.kdl".text = ''
      layout {
          focus-ring {
              active-color "{{colors.primary.default.hex}}"
          }
      }
    '';
  };

  home = {
    # niri hard-errors on a missing include, and matugen only writes the
    # accent file on its first run — seed it once (multiline on purpose:
    # KDL rejects an inline child block whose last node lacks a `;`).
    # Write-if-absent: matugen owns the file from then on, which is also
    # why it is NOT an xdg.configFile — HM would fight the rewrites.
    activation.seedNiriAccent = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      f="$HOME/.config/niri/niri.accent.kdl"
      [ -e "$f" ] || printf 'layout {\n    focus-ring {\n        active-color "#89b4fa"\n    }\n}\n' > "$f"
    '';

    packages = [
      # dms-shell with one source patch (same pre-embed technique as the
      # greeter's screen filter in modules/nixos/greeter.nix — the QML
      # is embedded in the Go binary, so patches must land on SOURCE):
      # the bar's launcher logo gets a 1px downward nudge, every mode.
      # The glyph itself is stock DMS: launcherLogoMode "os" in
      # dms.settings.json renders the distro's Nerd Font snowflake,
      # tinted by launcherLogoColorOverride "primary" so it follows the
      # wallpaper palette. Centering that glyph needs BOTH this patch
      # (vertical — the icon item consistently rounds high in its pill,
      # and no settings knob moves it) and launcherLogoSizeOffset 2 in
      # settings (horizontal — the size parity decides where the
      # rounding lands). Remeasure both if bar thickness or font scale
      # moves. The --replace-fail anchor means a DMS update that
      # reshapes the line breaks the BUILD, never the bar.
      (pkgs.dms-shell.overrideAttrs (old: {
        postPatch = (old.postPatch or "") + ''
          substituteInPlace ../quickshell/Modules/DankBar/Widgets/LauncherButton.qml \
            --replace-fail 'anchors.centerIn: parent' \
            'anchors.centerIn: parent
                anchors.verticalCenterOffset: 1'
        '';
      }))
      # dms spawns `qs` from PATH; its package doesn't bundle quickshell
      pkgs.quickshell
      # backs dms's system-monitor widgets (cpu/mem/process list)
      pkgs.dgop
      # backs dms's wallpaper-driven dynamic theming; without it on PATH,
      # theme generation silently does nothing
      pkgs.matugen

      # the AudioFX plugin's runtime (the plugin itself is imperative —
      # `dms plugins install audioFx` into ~/.config/DankMaterialShell/
      # plugins, restorable via `dms plugins lock`/`restore`): cava is
      # the spectrum analyser (the same engine Ryoku's desktop
      # visualiser used — PipeWire playback monitor in, bands out), and
      # the python env feeds its wallpaper beat-glow, which analyses
      # the wallpaper for bright spots to pulse. The plugin probes both
      # from PATH and quietly loses features when they're missing.
      # The local checkout carries TWO hand patches that an update or
      # reinstall will silently revert — reapply both or the visualizer
      # goes invisible again:
      #   - AudioFxDaemon.qml: WlrLayer.Background -> WlrLayer.Bottom
      #     on both surfaces. On the background layer the wallpaper
      #     races it for stacking order per output; Bottom sits above
      #     wallpaper, below windows, deterministically (the upstream
      #     README's place-within-backdrop niri rules assume a
      #     backdrop-wallpaper desktop and bury it here — the comment
      #     in niri.config.kdl has that story).
      #   - AudioFxCanvas.qml: autosens=0 -> autosens=1 in the cava
      #     conf template. Upstream's fixed gain (sensitivity 100,
      #     1% draw threshold, hide-after-silence) leaves quiet
      #     playback below threshold and the canvas fades out
      #     entirely; auto-gain is what made the Ryoku visualizer
      #     dance at any volume.
      # The modernClock plugin (desktop clock, both monitors) carries
      # one too: ModernClock.qml's useThemeColors branch retargeted
      # Theme.surfaceText -> Theme.primary, so the clock wears the
      # wallpaper accent like the launcher snowflake instead of
      # near-white. Its instance config (position sync, theme-colors
      # flag) rides dms.settings.json's desktopWidgetInstances.
      pkgs.cava
      (pkgs.python3.withPackages (ps: [
        ps.numpy
        ps.pillow
      ]))
    ];

  };
}
