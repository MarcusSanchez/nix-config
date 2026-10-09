# DankMaterialShell, the desktop shell. Theme/wallpaper choice lives
# in the settings UI and lands as git drift through the settings link
# below; this file carries the plumbing that propagates the chosen
# palette (matugen -> niri's focus ring; ghostty follows via its own
# dankcolors theme, named in ghostty.linux.config). Spawned and bound
# in niri.config.kdl. Session state (wallpaper path, avatar, per-app
# usage) stays in ~/.local/state, machine-local by design.
{
  config,
  pkgs,
  lib,
  ...
}:

let
  # from the same nixpkgs qt6 set quickshell is built against — a
  # mismatched Qt ABI crashes the shell
  qt5compatQml = "${pkgs.qt6.qt5compat}/lib/qt-6/qml";
in
{
  xdg.configFile = {
    # DMS may atomically replace the link with a plain file on save
    # (same caveat as the zed links); HM re-links on the next switch.
    # Some keys pair with config elsewhere — launcherLogoSizeOffset
    # with the dms-shell patch below, terminalsAlwaysDark with
    # ghostty.linux.config — so don't wipe the target casually.
    "DankMaterialShell/settings.json".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nix-config/home/marcus/common/dotfiles/dms.settings.json";
    # the clipboard daemon's own config (`dms clipboard config`), same
    # link shape. maxEntrySize is raised above the 5 MiB default because
    # the screenshot binds copy their files through this daemon and a 4K
    # full-screen PNG is larger than that; it refuses oversized files.
    "DankMaterialShell/clsettings.json".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nix-config/home/marcus/common/dotfiles/dms.clsettings.json";

    # niri's focus ring follows the palette: DMS runs this user matugen
    # config after its own on every wallpaper/theme change, rendering
    # the primary color into an include niri.config.kdl loads last.
    # Three constraints: the toml must stay comment-free plain ASCII
    # (DMS re-parses it when merging and rejects escaped non-ASCII),
    # the empty [config] table is mandatory, and the paths must be
    # absolute (templates with ~-relative paths are silently skipped).
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
    # plugins written against Qt5Compat.GraphicalEffects (the
    # materialPlayer desktop widget) need the module on the QML import
    # path; quickshell's closure doesn't ship it. Both names: Qt reads
    # QML_IMPORT_PATH, plugin startup checks grep QML2_IMPORT_PATH.
    # Session vars land at login.
    sessionVariables = {
      QML_IMPORT_PATH = qt5compatQml;
      QML2_IMPORT_PATH = qt5compatQml;
    };

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
      # dms-shell with source patches (QML is embedded in the Go
      # binary, so patches land pre-embed, as in
      # modules/nixos/greeter.nix); --replace-fail makes a DMS update
      # that reshapes an anchored line fail the build:
      #   - launcher logo: renders 1px high in its pill and no settings
      #     knob moves it vertically — nudged down;
      #     launcherLogoSizeOffset in dms.settings.json is the
      #     horizontal half of the same centering.
      #   - profile-image fallbacks: bare "person" resolves through the
      #     icon theme, which Adwaita lacks, leaving an empty circle;
      #     "material:person" renders the bundled font glyph (what the
      #     greeter already uses).
      (pkgs.dms-shell.overrideAttrs (old: {
        postPatch = (old.postPatch or "") + ''
          substituteInPlace ../quickshell/Modules/DankBar/Widgets/LauncherButton.qml \
            --replace-fail 'anchors.centerIn: parent' \
            'anchors.centerIn: parent
                anchors.verticalCenterOffset: 1'
          for f in \
            ../quickshell/Modules/ControlCenter/Components/HeaderPane.qml \
            ../quickshell/Modules/Lock/LockScreenContent.qml \
            ../quickshell/Modules/DankDash/Overview/UserInfoCard.qml \
            ../quickshell/Modals/Settings/ProfileSection.qml
          do
            substituteInPlace "$f" \
              --replace-fail 'fallbackIcon: "person"' 'fallbackIcon: "material:person"'
          done
        '';
      }))
      # Plugins are imperative checkouts under
      # ~/.config/DankMaterialShell/plugins (dms plugins
      # install/lock/restore); the audioFx and modernClock checkouts
      # carry local patches that a plugin update silently reverts and
      # which must be reapplied:
      #   - AudioFxDaemon.qml: both surfaces WlrLayer.Background ->
      #     Bottom, for deterministic stacking above the wallpaper
      #     (ignore the upstream README's place-within-backdrop niri
      #     rules — they assume a backdrop wallpaper and hide the
      #     surfaces here).
      #   - AudioFxCanvas.qml: autosens=0 -> autosens=1 in the cava
      #     conf, or quiet playback sits under the draw threshold and
      #     the visualizer fades out entirely.
      #   - ModernClock.qml: useThemeColors branch Theme.surfaceText ->
      #     Theme.primary, so the clock takes the palette accent.

      # dms spawns `qs` from PATH; its package doesn't bundle quickshell
      pkgs.quickshell
      # backs dms's system-monitor widgets (cpu/mem/process list)
      pkgs.dgop
      # backs dms's wallpaper-driven dynamic theming; without it on PATH,
      # theme generation silently does nothing
      pkgs.matugen

      # runtime for the audioFx plugin: cava (spectrum analyser) and
      # the python env (wallpaper glow analysis). The plugin probes
      # both from PATH and silently loses features when missing.
      pkgs.cava
      (pkgs.python3.withPackages (ps: [
        ps.numpy
        ps.pillow
      ]))
    ];
  };
}
