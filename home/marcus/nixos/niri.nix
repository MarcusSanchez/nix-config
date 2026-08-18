# User-side of the niri session (the compositor itself and its
# portals come from programs.niri in modules/nixos/niri.nix): the
# config links the compositor reads, the fallback locker, and every
# tool its binds and spawns expect on PATH.
#
# niri hot-reloads its files on save; linked out-of-store so edits
# apply without a rebuild and land in the repo as ordinary git drift.
# niri.outputs.kdl must sit BESIDE config.kdl: its include is resolved
# relative to the symlink's directory, not the target's (verified on
# niri 26.04) — the same file also feeds the greeter's compositor via
# /etc/greetd/niri_overrides.kdl (modules/nixos/greeter.nix).
{
  config,
  pkgs,
  osConfig,
  ...
}:

{
  # Everything the session expects on PATH: what niri.config.kdl's
  # binds and spawn-at-startup lines call by name (removing one
  # silently breaks its bind rather than erroring), plus the xwayland
  # bridge niri spawns itself.
  home.packages = [
    # X11 apps (JetBrains IDEs...) under niri: niri auto-spawns
    # xwayland-satellite when it's on PATH
    pkgs.xwayland-satellite

    # instant wallpaper under quickshell's: covers the startup gap
    # before DMS's wallpaper layer maps (spawned in niri.config.kdl
    # with the path read from DMS's session state)
    pkgs.swaybg

    # video wallpapers (the live spaceman on the 4K): mpv on the
    # background layer, spawned per-output
    pkgs.mpvpaper

    # the snipping tool (Mod+Shift+S in niri.config.kdl): slurp picks a
    # region, grim captures it, satty annotates (arrows/text/blur) and
    # copies via wl-clipboard. niri's built-in Print overlay stays for
    # quick unannotated shots; flameshot fights niri's portal situation.
    pkgs.grim
    pkgs.slurp
    pkgs.satty
    pkgs.wl-clipboard
    # notify-send, for the screenshot binds' best-effort toast (DMS is
    # the notification daemon that renders it)
    pkgs.libnotify

    # clipboard history: wl-paste watchers (spawned in niri.config.kdl)
    # store every copy; DMS's clipboard view (Mod+V) reads it back via
    # `cliphist list`
    pkgs.cliphist

    # MPRIS media control — the XF86AudioPlay/Prev/Next binds in
    # niri.config.kdl call this; without it media keys are wired to
    # nothing (the Wooting's skip keys included)
    pkgs.playerctl
    # same story for XF86MonBrightness keys, where a panel has them
    pkgs.brightnessctl

    # synthetic keystrokes via the virtual-keyboard protocol; Mod+W in
    # niri.config.kdl forwards Ctrl+W to the focused app (close tab)
    pkgs.wtype

    # per-application key remapping (alt+hjkl -> arrows outside vim-y
    # apps); the niri variant tracks the focused window over niri IPC.
    # Config: dotfiles/xremap.yml, spawned in niri.config.kdl.
    (pkgs.xremap.override { withVariant = "niri"; })

    # TPM-backed virtual FIDO2 key (system plumbing in
    # modules/nixos/security.nix, spawned in niri.config.kdl). It
    # shells out to a bare `pinentry` for the touch-confirmation
    # prompt — the alias beside it points that name at the gnome3 flavor,
    # which prompts via gcr.
    pkgs.tpm-fido
    (pkgs.runCommand "pinentry-alias" { } ''
      mkdir -p $out/bin
      ln -s ${pkgs.pinentry-gnome3}/bin/pinentry-gnome3 $out/bin/pinentry
    '')

    # kill/revive the animated wallpaper on demand (games, benchmarks,
    # or just wanting the still), plus explicit on/off verbs so other
    # tools (wallpaper:group in dms.nix) can command a known state.
    # The spawn line mirrors the spawn-at-startup in
    # niri.host.naut-dt.kdl — with it off, the static layer beneath
    # (swaybg/DMS) shows. Harmless on a host without that connector:
    # mpvpaper just exits. Colon name = the reboot:windows
    # file-inside-a-derivation shape.
    (pkgs.runCommand "mpvpaper-toggle" { } ''
      mkdir -p $out/bin
      install -m755 ${pkgs.writeShellScript "mpvpaper-toggle" ''
        # [b] keeps the regex from matching any process merely QUOTING
        # the pattern (a shell command mentioning it, a pasted line) —
        # only a real mpvpaper cmdline matches
        running() { pgrep -f "mpvpaper -l [b]ottom" >/dev/null 2>&1; }
        stop() { pkill -f "mpvpaper -l [b]ottom"; }
        start() {
          nohup mpvpaper -l bottom -o "no-audio loop hwdec=auto" DP-3 \
            "$HOME/Pictures/Wallpapers/live/spaceman.mp4" >/dev/null 2>&1 &
        }
        case "''${1:-}" in
          on) running || start; echo "mpvpaper: on" ;;
          off) ! running || stop; echo "mpvpaper: off" ;;
          "") if running; then stop; echo "mpvpaper: off"; else start; echo "mpvpaper: on"; fi ;;
          *) echo "usage: mpvpaper:toggle [on|off]" >&2; exit 64 ;;
        esac
      ''} "$out/bin/mpvpaper:toggle"
    '')
  ];

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
    };

  # fallback lock (PAM entry in modules/nixos/niri.nix) in case the
  # DMS lock ever misbehaves — run `swaylock` from a terminal
  programs.swaylock.enable = true;
}
