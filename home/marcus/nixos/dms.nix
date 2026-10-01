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

{
  xdg.configFile = {
    # DMS may atomically replace the link with a plain file on save
    # (same caveat as the zed links); HM re-links on the next switch.
    # Some keys pair with config elsewhere — launcherLogoSizeOffset
    # with the dms-shell patch below, terminalsAlwaysDark with
    # ghostty.linux.config — so don't wipe the target casually.
    "DankMaterialShell/settings.json".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nix-config/home/marcus/common/dotfiles/dms.settings.json";

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
      # dms-shell with one source patch (QML is embedded in the Go
      # binary, so patches land pre-embed, as in
      # modules/nixos/greeter.nix): the launcher logo renders 1px high
      # in its pill and no settings knob moves it vertically — this
      # nudges it down; launcherLogoSizeOffset in dms.settings.json is
      # the horizontal half of the same centering. --replace-fail makes
      # a DMS update that reshapes the anchored line fail the build.
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

      # runtime for the audioFx plugin: cava (spectrum analyser) and
      # the python env (wallpaper glow analysis). The plugin probes
      # both from PATH and silently loses features when missing.
      # Plugins themselves are imperative checkouts under
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
      pkgs.cava
      (pkgs.python3.withPackages (ps: [
        ps.numpy
        ps.pillow
      ]))
    ];

  };
}
