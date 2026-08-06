# User-side pieces of the niri session (the compositor itself and its
# portals come from programs.niri in modules/desktop/desktop.nix).
# The shell is DankMaterialShell (quickshell-based): bar, launcher,
# notifications, control center, lock screen and wallpaper-driven
# Material theming in one — spawned and bound in niri.config.kdl
# (spawn-at-startup "dms run", Mod+D / Alt+Space spotlight, Super+Alt+L
# lock). Its settings.json is linked into the repo below (same
# UI-managed-config pattern as zed/niri: edits made in the DMS settings
# UI land as git drift). Session *state* — wallpaper path, avatar,
# per-app usage — stays outside in ~/.local/state, machine-local by
# design. (noctalia was trialed in the same slot; DMS won.)
{
  config,
  lib,
  pkgs,
  osConfig,
  ...
}:

let
  # Live experiment on the desktop PC: the ghostty tab-bar icon
  # breakage under Papirus was diagnosed on the laptop, whose Plasma
  # history muddied the picture. bedroom-nixos (clean install, no DE
  # leftovers) runs the catppuccin/Papirus icons natively to see
  # whether it reproduces; the laptop keeps the Adwaita pin. Verdict
  # decides whether the pin is load-bearing everywhere or was a
  # laptop-only artifact.
  papirusIconTest = osConfig.networking.hostName == "bedroom-nixos";
in
{
  # GTK icon/cursor theme NAMES, owned declaratively: Plasma wrote
  # breeze-dark/breeze_cursors into settings.ini and dconf for
  # cross-toolkit consistency, and the DE teardown orphaned them — GTK
  # only scans the theme it's named, so every named icon rendered as a
  # broken-image placeholder and the cursor stayed a themeless default.
  # (Plasma's old files land in .hm-backup on first switch.)
  gtk = {
    enable = true;
    # on the test host, catppuccin's GTK port supplies iconTheme
    # (Papirus-Dark) instead
    iconTheme = lib.mkIf (!papirusIconTest) {
      name = "Adwaita";
      package = pkgs.adwaita-icon-theme;
    };
  };
  catppuccin.gtk.icon.enable = papirusIconTest;
  # libadwaita apps (ghostty) read gsettings/dconf, not settings.ini —
  # icon-theme follows whichever theme won gtk.iconTheme above
  dconf.settings."org/gnome/desktop/interface" = {
    icon-theme = config.gtk.iconTheme.name;
    cursor-theme = "Adwaita";
    cursor-size = 24;
  };

  home.packages = [
    pkgs.dms-shell
    # dms spawns `qs` from PATH; its package doesn't bundle quickshell
    pkgs.quickshell
    # backs dms's system-monitor widgets (cpu/mem/process list)
    pkgs.dgop
    # backs dms's wallpaper-driven dynamic theming; without it on PATH,
    # theme generation silently does nothing
    pkgs.matugen

    # X11 apps (JetBrains IDEs...) under niri: niri auto-spawns
    # xwayland-satellite when it's on PATH
    pkgs.xwayland-satellite

    # instant wallpaper under quickshell's: covers the startup gap
    # before DMS's wallpaper layer maps (spawned in niri.config.kdl
    # with the path read from DMS's session state)
    pkgs.swaybg

    # the snipping tool (Mod+Shift+S in niri.config.kdl): slurp picks a
    # region, grim captures it, satty annotates (arrows/text/blur) and
    # copies via wl-clipboard. niri's built-in Print overlay stays for
    # quick unannotated shots; flameshot was researched and skipped —
    # it fights niri's portal situation.
    pkgs.grim
    pkgs.slurp
    pkgs.satty
    pkgs.wl-clipboard

    # synthetic keystrokes via the virtual-keyboard protocol; Mod+W in
    # niri.config.kdl forwards Ctrl+W to the focused app (close tab)
    pkgs.wtype

    # per-application key remapping (alt+hjkl -> arrows outside vim-y
    # apps); the niri variant tracks the focused window over niri IPC.
    # Config: dotfiles/xremap.yml, spawned in niri.config.kdl.
    (pkgs.xremap.override { withVariant = "niri"; })

    # TPM-backed virtual FIDO2 key (system plumbing in
    # modules/desktop/tpm.nix, spawned in niri.config.kdl). It shells out
    # to a bare `pinentry` for the touch-confirmation prompt — the
    # alias points it at the gnome3 flavor, which prompts via gcr.
    pkgs.tpm-fido
    (pkgs.runCommand "pinentry-alias" { } ''
      mkdir -p $out/bin
      ln -s ${pkgs.pinentry-gnome3}/bin/pinentry-gnome3 $out/bin/pinentry
    '')
  ];

  # Cursor theme everywhere: HM covers GTK settings, ~/.icons and the
  # XCURSOR_* session vars; the niri config's cursor block covers the
  # compositor's own cursor and what it exports to spawned apps. The DE
  # teardown left NO cursor theme — apps fell back to one oversized
  # default with no hover/text/resize variants.
  home.pointerCursor = {
    enable = true;
    # plain Adwaita arrow — the catppuccin mauve set was tried and its
    # pointer reads as an odd purple triangle
    package = pkgs.adwaita-icon-theme;
    name = "Adwaita";
    size = 24;
    gtk.enable = true;
    x11.enable = true;
  };

  # niri hot-reloads its files on save; linked out-of-store so edits
  # apply without a rebuild and land in the repo as ordinary git drift.
  # niri.outputs.kdl must sit BESIDE config.kdl: its include is resolved
  # relative to the symlink's directory, not the target's (verified on
  # niri 26.04) — the same file also feeds the greeter's compositor via
  # /etc/greetd/niri_overrides.kdl (modules/desktop/desktop.nix).
  #
  # DMS caveat, same as the zed links: it may atomically replace
  # settings.json's link with a plain file on save; HM re-links and
  # hm-backups it on the next switch.
  xdg.configFile =
    let
      dotfiles = "${config.home.homeDirectory}/nix-config/home/marcus/common/dotfiles";
      link = f: config.lib.file.mkOutOfStoreSymlink "${dotfiles}/${f}";
    in
    {
      "niri/config.kdl".source = link "niri.config.kdl";
      "niri/niri.outputs.kdl".source = link "niri.outputs.kdl";
      # the per-host tail config.kdl includes: hostname picks the
      # target, so each desktop machine reads its own rules from the
      # one shared repo (a new host must commit its file first)
      "niri/niri.host.kdl".source = link "niri.host.${osConfig.networking.hostName}.kdl";
      "DankMaterialShell/settings.json".source = link "dms.settings.json";
    };

  # fallback lock (PAM entry in modules/desktop/desktop.nix) in case the
  # DMS lock ever misbehaves — run `swaylock` from a terminal
  programs.swaylock.enable = true;
}
