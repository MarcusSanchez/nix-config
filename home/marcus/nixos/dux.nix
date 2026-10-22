# Dux Shell, the desktop shell, through its own Home Manager module
# (flake input dux-shell): the shell and its runtime (quickshell,
# dux-gop, matugen, cava), and dms.service — the shell as a
# session-bound systemd user unit (`journalctl --user -u dms` for its
# log, `systemctl --user restart dms` to respawn it). Theme, wallpaper
# and every other choice live in its settings UI; the two config
# files below are linked out of the repo so those choices land as git
# drift. Session state (wallpaper path, per-app usage) stays in
# ~/.local/state/dms, machine-local by design. Bound in
# niri.config.kdl, which also loads the shell's generated niri colors.
{
  config,
  inputs,
  options,
  osConfig,
  pkgs,
  ...
}:

let
  link = f: config.lib.file.mkOutOfStoreSymlink "${osConfig.identity.dotfiles}/${f}";

  # from the same nixpkgs qt6 set quickshell is built against — a
  # mismatched Qt ABI crashes the shell
  qt5compatQml = "${pkgs.qt6.qt5compat}/lib/qt-6/qml";
in
{
  imports = [ inputs.dux-shell.homeModules.default ];

  programs.dank-material-shell = {
    enable = true;
    systemd.enable = true;
    # calendar events need khal, which no calendar here feeds
    enableCalendarEvents = false;
    # The module's own build, patched in its INSTALLED QML tree (the
    # package copies the QML at install time, so postPatch would miss
    # it); a hunk that no longer applies fails the build, never the
    # bar:
    #   - ./patches/dux-bar.patch: the launcher logo, which renders 1px
    #     high in its pill with no settings knob to move it vertically,
    #     nudged down (launcherLogoSizeOffset in dux.settings.json is the
    #     horizontal half of that centering); on a vertical bar, CPU
    #     as "20%" and RAM (with the widget's built-in show-in-GB
    #     option) over a small "GiB" line, both at 0.8x to fit the
    #     bar's width; and the stacked clock without its AM/PM line.
    #   - ./patches/dux-dock.patch: an "outline" color choice for the
    #     dock border beside primary/secondary/surfaceText, so the dock's
    #     1px border in dux.settings.json can take the muted tone of
    #     the popups' border (blurBorderEnabled).
    package = options.programs.dank-material-shell.package.default.overrideAttrs (old: {
      postInstall = old.postInstall + ''
        patch -p1 -d $out/share/quickshell/dms < ${./patches/dux-bar.patch}
        patch -p1 -d $out/share/quickshell/dms < ${./patches/dux-dock.patch}
      '';
    });
  };

  # A user unit doesn't read the login shell's session variables, so
  # the plugins' QML import path (below) is restated here.
  # QS_ICON_THEME makes the shell skip its own icon-file index and
  # resolve app icons through Qt's icon engine, which loads them at
  # the output's scale; the index's file paths render raster icons
  # soft on the fractional-scale outputs. The theme is the one
  # theme.nix pins.
  systemd.user.services.dms.Service.Environment = [
    "QML_IMPORT_PATH=${qt5compatQml}"
    "QML2_IMPORT_PATH=${qt5compatQml}"
    "QS_ICON_THEME=${config.gtk.iconTheme.name}"
  ];

  # Plugins are imperative checkouts under ~/.config/dms/plugins
  # (dms plugins install/lock/restore). Their runtime is here; the
  # audioFx and modernClock checkouts also carry local patches that a
  # plugin update silently reverts and which must be reapplied:
  #   - AudioFxDaemon.qml: both surfaces WlrLayer.Background -> Bottom,
  #     for deterministic stacking above the wallpaper (ignore the
  #     upstream README's place-within-backdrop niri rules — they
  #     assume a backdrop wallpaper and hide the surfaces here).
  #   - AudioFxCanvas.qml: autosens=0 -> autosens=1 in the cava conf,
  #     or quiet playback sits under the draw threshold and the
  #     visualizer fades out entirely.
  #   - audioFx/DankAlbumArt.qml: a vendored copy of the album-art
  #     widget AudioFxDiscDesktop.qml names, which the shell doesn't
  #     ship; its animated-art Loader takes
  #     `sourceComponent: DAnimatedAlbumArt {}` instead of a relative
  #     file source.
  #   - ModernClock.qml: useThemeColors branch Theme.surfaceText ->
  #     Theme.primary, so the clock takes the palette accent.
  home = {
    # plugins written against Qt5Compat.GraphicalEffects (the
    # materialPlayer desktop widget) need the module on the QML import
    # path; quickshell's closure doesn't ship it. Both names: Qt reads
    # QML_IMPORT_PATH, plugin startup checks grep QML2_IMPORT_PATH.
    sessionVariables = {
      QML_IMPORT_PATH = qt5compatQml;
      QML2_IMPORT_PATH = qt5compatQml;
    };

    # the audioFx plugin's wallpaper glow analysis (cava, its other
    # runtime, comes with the module); it probes python from PATH and
    # silently loses the feature when missing
    packages = [
      (pkgs.python3.withPackages (ps: [
        ps.numpy
        ps.pillow
      ]))
    ];
  };

  xdg.configFile = {
    # The shell may atomically replace a link with a plain file on
    # save; HM re-links on the next switch. The module's `settings`
    # option stays unset: set, it writes a read-only file and the UI's
    # changes stop sticking. Some keys pair with config elsewhere —
    # launcherLogoSizeOffset with ./patches/dux-bar.patch, terminalsAlwaysDark
    # with ghostty.linux.config, the dock border with
    # ./patches/dux-dock.patch — so don't wipe the target casually.
    "dms/settings.json".source = link "dux.settings.json";
    # the clipboard daemon's config (`dms clipboard config`).
    # maxEntrySize is raised above the 5 MiB default: screenshots are
    # copied as files through this daemon, a 4K full-screen PNG is
    # larger than that, and it refuses oversized entries.
    "dms/clsettings.json".source = link "dux.clsettings.json";
  };
}
